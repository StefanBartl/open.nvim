---@module 'open.bindings.keymaps'
---@brief Optional keymaps for common :Open invocations, configured via setup().
---@description
--- open.nvim ships with no default keymaps. Setting `cfg.keymaps.<name>` to
--- an lhs string registers a normal-mode keymap for that fixed invocation:
---
---   open_default  = "<leader>oo"  -- :Open
---   open_browser  = "<leader>ob"  -- :Open browser
---   open_manager  = "<leader>of"  -- :Open filemanager
---   open_split    = "<leader>os"  -- :Open split
---   open_terminal = "<leader>ot"  -- :Open terminal
---
--- **The accepted names come from the handler registry, not from a list kept
--- here.** They used to be a hardcoded three, which is why `split`, `vsplit`,
--- `tab`, `terminal`, `image` and `notepad` had no keymap option despite being
--- perfectly ordinary `:Open <target>` values -- the list simply had not grown
--- with the handlers. Now every registered handler `key` is available as
--- `open_<key>`, and adding a handler (including a `custom_handlers` one)
--- brings its keymap option along for free.
---
--- Because the source is the *live* registry rather than a static list, a
--- target the user switched off via `cfg.handlers` is correctly rejected here
--- too, instead of mapping a key to a command that would fail at press time.

local map = require("lib.nvim.map")
local notify = require("lib.nvim.notify").create("[open.keymaps]")
local registry = require("open.registry")

local M = {}

---The bare `:Open`, with no target argument.
---
---This name collides with the registry's own `default` handler, which
---`open_<key>` would otherwise claim. The collision is harmless -- `:Open`
---and `:Open default` both end up at the context-aware default handler -- and
---resolving it in favor of the bare command keeps the historical meaning of
---this key exactly as it was.
local DEFAULT_NAME = "open_default"

---Historical name that does not follow `open_<handler key>`: it predates the
---registry-driven scheme and maps to the `filemanager` handler. Kept because
---renaming it would silently break every existing config that sets it.
---@type table<string, string>
local ALIASES = { open_manager = "filemanager" }

---Resolve `keymaps.<name>` to the `:Open` target it stands for.
---@internal
---@param name string
---@return string|nil target  # nil for the bare command, or when unknown
---@return boolean ok
local function resolve_target(name)
  if name == DEFAULT_NAME then return nil, true end

  local aliased = ALIASES[name]
  if aliased then return aliased, registry.get(aliased) ~= nil end

  local key = name:match("^open_(.+)$")
  if key and registry.get(key) then return key, true end

  return nil, false
end

---Every `keymaps.<name>` this setup would accept, for an error message that
---names the alternatives instead of only rejecting.
---@internal
---@return string
local function accepted_names()
  local seen = { [DEFAULT_NAME] = true }
  local names = { DEFAULT_NAME }

  local function add(name)
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end

  -- `open_default` is already in, so the registry's own `default` handler
  -- does not produce a second copy of it.
  for _, key in ipairs(registry.list_keys()) do
    add("open_" .. key)
  end
  for alias in pairs(ALIASES) do
    add(alias)
  end

  table.sort(names)
  return table.concat(names, ", ")
end

---Register keymaps declared in `cfg.keymaps`.
---
--- Runs after handler registration in `setup()`, which is what lets it read
--- the registry rather than duplicate it.
---@param cfg OpenNvim.Config
function M.register(cfg)
  local keymaps = cfg.keymaps
  if type(keymaps) ~= "table" then return end

  for name, lhs in pairs(keymaps) do
    if lhs and lhs ~= "" then
      local target, ok = resolve_target(name)
      if not ok then
        notify.warn(
          ("Unknown keymaps.%s — ignoring. Accepted: %s"):format(tostring(name), accepted_names())
        )
      else
        local cmd = target and (cfg.command .. " " .. target) or cfg.command
        map("n", lhs, ("<Cmd>%s<CR>"):format(cmd), {}, "open.nvim: :" .. cmd)
      end
    end
  end
end

return M
