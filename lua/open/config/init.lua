---@module 'open.config'
---@brief Setup options and defaults for open.nvim.

local M = {}

---@type OpenNvim.Config.Resolved
local defaults = require("open.config.DEFAULTS")

---@type OpenNvim.Config.Resolved
local current = vim.deepcopy(defaults)

-- ---------------------------------------------------------------------------
-- Validation (ERR-22 / ERR-50)
-- ---------------------------------------------------------------------------

---Whether `t` is array-shaped (an empty table counts).
---@internal
---@param t table
---@return boolean
local function is_list(t)
  if vim.islist then return vim.islist(t) end
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n == #t
end

---Top-level keys `setup()` recognizes, and how their value is validated:
---  * `"string"`/`"boolean"` — exact Lua type; a mismatch degrades to the
---    default (ERR-22) instead of aborting the rest of `setup()`.
---  * `"list"` — must be array-shaped (see `is_list`); a mismatch degrades
---    the same way. This is what `open.init`'s handler-loading loop
---    `ipairs`s and what `office_open.extensions` builds an autocmd pattern
---    from — both used to throw straight out of `setup()` on a wrong-typed
---    value.
---  * a nested table — one more level of `{ subkey = type }`, checked the
---    same way; an unrecognized sub-key is flagged (did-you-mean) but its
---    valid sibling values are still merged.
---  * `true` — accepted unchecked: `keywords` (`string|fun(): string|nil`
---    values) and `keymaps`/`viewer.commands` (dynamic, handler-derived
---    keys that this schema has no closed list for).
---@type table<string, "string"|"boolean"|"list"|true|table<string, "string"|"boolean"|"list"|true>>
local KNOWN = {
  command = "string",
  default_filemanager = "string",
  default_browser = "string",
  handlers = "list",
  builtin_keywords = "boolean",
  keywords = true,
  custom_handlers = "list",
  keymaps = true,
  filemanager = { reveal = "boolean", command = true },
  office_open = { enabled = "boolean", extensions = "list" },
  debug = "boolean",
  picker = { enabled = "boolean" },
  viewer = {
    commands = true,
    sort = "string",
    output = "string",
    mdlinks_output = "string",
    open_file = "string",
  },
  menu = { enable = "boolean" },
}

---What the last `setup()` had to reject or flag, for `:checkhealth`. Reset on
---every call so issues from an earlier setup() never linger.
---@type string[]
local issues = {}

---`key` with the nearest known one as a hint when there is a plausible one
---(edit distance <= 3).
---@internal
---@param key any
---@param known table<string, any>
---@param prefix string
---@return string
local function describe_unknown(key, known, prefix)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local name = tostring(key)
  local best, best_distance = nil, nil
  for candidate in pairs(known) do
    local d = levenshtein(name, candidate)
    if d <= 3 and (best_distance == nil or d < best_distance) then
      best, best_distance = candidate, d
    end
  end
  if best then
    return ("unknown option '%s%s' (did you mean '%s%s'?)"):format(prefix, name, prefix, best)
  end
  return ("unknown option '%s%s'"):format(prefix, name)
end

---Check `value` against a `"string"`/`"boolean"`/`"list"` expected shape.
---@internal
---@param expected "string"|"boolean"|"list"
---@param value any
---@return boolean
local function fits(expected, value)
  if expected == "list" then return type(value) == "table" and is_list(value) end
  return type(value) == expected
end

---Validate `opts` against `KNOWN` before the merge (ERR-50): a value whose
---shape does not fit its option is dropped so the built-in default is what
---actually takes effect (ERR-22), instead of a raw Lua error two or three
---calls downstream — e.g. `handlers = "browser"` used to throw "table
---expected, got string" out of `open.init`'s `ipairs(cfg.handlers)`.
---
---An unrecognized key is dropped (open.nvim's schema is closed, unlike a
---plugin with a genuine open-ended extension point) but still reported with
---a did-you-mean hint, so a typo like `hanlders` is visible instead of
---silently leaving the real option at its default forever.
---
---Does not mutate `opts`.
---@internal
---@param opts table
---@return table clean        shallow copy of opts, minus rejected entries
---@return string[] found_issues
local function validate(opts)
  local clean, found_issues = {}, {}

  for key, value in pairs(opts) do
    local known = KNOWN[key]

    if known == nil then
      found_issues[#found_issues + 1] = describe_unknown(key, KNOWN, "")
    elseif known == true then
      clean[key] = value
    elseif known == "string" or known == "boolean" or known == "list" then
      if fits(known, value) then
        clean[key] = value
      else
        found_issues[#found_issues + 1] = ("option '%s' must be a %s, got %s -- using the default"):format(
          key,
          known,
          type(value)
        )
      end
    elseif type(known) == "table" then
      if type(value) ~= "table" then
        found_issues[#found_issues + 1] = ("option '%s' must be a table, got %s -- using the default"):format(
          key,
          type(value)
        )
      else
        local sub_clean = {}
        for sub_key, sub_value in pairs(value) do
          local sub_known = known[sub_key]
          if sub_known == nil then
            found_issues[#found_issues + 1] = describe_unknown(sub_key, known, key .. ".")
          elseif sub_known == true or fits(sub_known, sub_value) then
            sub_clean[sub_key] = sub_value
          else
            found_issues[#found_issues + 1] = ("option '%s.%s' must be a %s, got %s -- using the default"):format(
              key,
              sub_key,
              sub_known,
              type(sub_value)
            )
          end
        end
        clean[key] = sub_clean
      end
    end
  end

  table.sort(found_issues)
  return clean, found_issues
end

---Merge user options into the defaults.
---
---`opts` is validated first (ERR-50/ERR-22): a value whose shape does not
---fit its option is dropped so the built-in default is what actually takes
---effect, and every issue is both warned here and kept for `:checkhealth`
---(see `M.issues()`).
---@param opts OpenNvim.Config|nil
function M.setup(opts)
  opts = opts or {}

  local clean, found_issues = validate(opts)
  issues = found_issues
  if #issues > 0 then
    local notify = require("lib.nvim.notify").create("[open]")
    for _, msg in ipairs(issues) do
      notify.warn(msg)
    end
  end

  -- Build keyword map separately: built-ins (unless disabled) + user overrides.
  -- We cannot use tbl_deep_extend for this because values may be functions.
  local merged_keywords = {}

  if clean.builtin_keywords ~= false then
    local ok, kw_mod = pcall(require, "open.keywords")
    if ok then
      for k, v in pairs(kw_mod.builtin()) do
        merged_keywords[k] = v
      end
    end
  end

  for k, v in pairs(clean.keywords or {}) do
    merged_keywords[k] = v -- user overrides built-ins
  end

  -- Deep-extend everything else, then attach the pre-built keyword map.
  local opts_rest = vim.tbl_deep_extend("force", {}, clean)
  opts_rest.keywords = nil
  opts_rest.builtin_keywords = nil

  -- `vim.deepcopy(defaults)`, not `defaults` itself: `tbl_deep_extend` only
  -- recurses where both sides have a table and otherwise assigns by
  -- reference, so passing the shared `defaults` table here would leak its
  -- own sub-tables into `current` whenever `opts_rest` has no override for
  -- that key -- a later write through `M.get()` would then permanently
  -- mutate `defaults` for the rest of the session.
  current = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts_rest)
  current.keywords = merged_keywords
  current.builtin_keywords = clean.builtin_keywords ~= false
end

---Return a defensive copy of the active config.
---
---A copy, not the live `current` table: a consumer that sorts a nested list
---in place for display, or otherwise mutates a field it was only supposed to
---read, would otherwise silently rewrite the plugin's own state for the rest
---of the session -- and every other consumer's next `M.get()` -- instead of
---touching a value it owns.
---@return OpenNvim.Config.Resolved
function M.get()
  return vim.deepcopy(current)
end

---Whether verbose/debug logging is enabled (`setup({ debug = true })`).
---@return boolean
function M.is_debug()
  return current.debug == true
end

---What the last `setup()` had to reject or flag: unrecognized keys (with a
---did-you-mean hint) and values whose shape did not fit their option, one
---human-readable line each. Empty when everything validated cleanly.
---@return string[]
function M.issues()
  return vim.list_extend({}, issues)
end

return M
