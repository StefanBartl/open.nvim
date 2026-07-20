---@module 'open_nvim.urlview.scan'
---@brief Extract link-like targets (URLs, markdown links, file paths) from lines.
---@description
--- The extraction half of `:Open urlview`. Given `Lib.Harvest.Source` records
--- it produces `OpenNvim.UrlView.Link` entries with enough provenance to jump
--- back to (file, line, column) or hand the target to `registry.dispatch`.
---
--- Recognizes three kinds:
---   - `mdlink` — `[text](target)`, reported with its target, not its label
---   - `url`    — a bare `scheme://…` or `www.…` run
---   - `path`   — a filesystem-looking token that actually exists on disk
---
--- A URL already covered by a markdown link is not reported twice: the
--- markdown pass records the byte spans it consumed and the bare-URL pass
--- skips anything inside one. Without that, every `[docs](https://…)` would
--- produce two entries pointing at the same place.

local M = {}

-- Conservative bare-URL run. Trailing sentence punctuation is stripped
-- afterwards rather than excluded here, so "see https://x.dev." still yields
-- the full host while dropping the period.
local URL_PATTERN = "%a[%w+.-]*://[%w%-%_%.%/%?%%=&~#@:+,;!$'*]+"
local WWW_PATTERN = "www%.[%w%-%_%.%/%?%%=&~#@:+,;!$'*]+"

local FENCE = "^%s*[`~][`~][`~]"

---@param s string
---@return string
local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

---@param s string
---@return string
local function strip_angle_brackets(s)
  if s:match("^<.+>$") then
    return s:sub(2, -2)
  end
  return s
end

--- Drop trailing punctuation that is almost certainly prose, not part of the
--- URL. Closing brackets are included because a URL inside `(see https://x)`
--- is far more common than one genuinely ending in `)`.
---@param s string
---@return string
local function strip_trailing_punct(s)
  return (s:gsub("[%.,;:%)%]%}>!%?]+$", ""))
end

--- Does `tok` look like a filesystem path, and does it exist?
--- Existence is required on purpose: without it, every `a/b` in prose and
--- every `foo.bar` method call would be reported as a path.
---@param tok string
---@param base_dir string|nil
---@return string|nil abs
local function resolve_path(tok, base_dir)
  if tok == "" or #tok < 3 then
    return nil
  end
  -- Must contain a separator or start with ./ ~ / — a bare word is not a path.
  if not (tok:find("[/\\]") or tok:match("^~")) then
    return nil
  end
  local candidates = {}
  local expanded = vim.fn.expand(tok)
  if expanded:match("^~") or expanded:match("^[/\\]") or expanded:match("^%a:[/\\]") then
    candidates[#candidates + 1] = expanded
  elseif base_dir then
    candidates[#candidates + 1] = base_dir .. "/" .. expanded
  end
  candidates[#candidates + 1] = expanded

  for _, c in ipairs(candidates) do
    local p = vim.fn.fnamemodify(c, ":p")
    if vim.fn.filereadable(p) == 1 or vim.fn.isdirectory(p) == 1 then
      return vim.fs.normalize(p)
    end
  end
  return nil
end

--- Extract links from a single line.
---@param line string
---@param lnum integer
---@param opts { paths?: boolean, base_dir?: string }|nil
---@return OpenNvim.UrlView.Link[]
function M.from_line(line, lnum, opts)
  opts = opts or {}
  local out = {}
  if not line or line == "" then
    return out
  end

  -- 1) Markdown inline links, recording the spans they consume.
  local covered = {}
  local from = 1
  while true do
    local s, e, text, target = line:find("%[(.-)%]%((.-)%)", from)
    if not s then
      break
    end
    if target and target ~= "" then
      local t = strip_angle_brackets(trim(target))
      out[#out + 1] = {
        display = ("[%s](%s)"):format(text, t),
        target = t,
        text = text,
        kind = "mdlink",
        lnum = lnum,
        col = s - 1,
      }
    end
    covered[#covered + 1] = { s, e }
    from = e + 1
  end

  ---@param s integer
  ---@return boolean
  local function is_covered(s)
    for _, r in ipairs(covered) do
      if s >= r[1] and s <= r[2] then
        return true
      end
    end
    return false
  end

  -- 2) Bare URLs outside those spans.
  for _, pat in ipairs({ URL_PATTERN, WWW_PATTERN }) do
    local us = 1
    while true do
      local s, e = line:find(pat, us)
      if not s then
        break
      end
      if not is_covered(s) then
        local url = strip_trailing_punct(line:sub(s, e))
        if url ~= "" then
          out[#out + 1] = {
            display = url,
            target = url,
            kind = "url",
            lnum = lnum,
            col = s - 1,
          }
          covered[#covered + 1] = { s, e }
        end
      end
      us = e + 1
    end
  end

  -- 3) Filesystem paths (opt-in — it stats the disk for every candidate).
  if opts.paths then
    local pos = 1
    while true do
      local s, e, tok = line:find("([%w%._%-~/\\:]+)", pos)
      if not s then
        break
      end
      if not is_covered(s) then
        local abs = resolve_path(strip_trailing_punct(tok), opts.base_dir)
        if abs then
          out[#out + 1] = {
            display = tok,
            target = abs,
            kind = "path",
            lnum = lnum,
            col = s - 1,
          }
          covered[#covered + 1] = { s, e }
        end
      end
      pos = e + 1
    end
  end

  return out
end

--- Extract links from one harvest source, skipping fenced code blocks.
---@param src Lib.Harvest.Source
---@param opts { paths?: boolean, code_fences?: boolean }|nil
---@return OpenNvim.UrlView.Link[]
function M.from_source(src, opts)
  opts = opts or {}
  local out = {}
  local base_dir = src.file and vim.fn.fnamemodify(src.file, ":h") or vim.fn.getcwd()
  local in_fence = false

  for i, line in ipairs(src.lines) do
    if opts.code_fences ~= false and line:match(FENCE) then
      in_fence = not in_fence
    elseif not in_fence then
      local found = M.from_line(line, src.first + i - 1, {
        paths = opts.paths,
        base_dir = base_dir,
      })
      for _, lk in ipairs(found) do
        lk.file = src.file
        lk.bufnr = src.bufnr
        out[#out + 1] = lk
      end
    end
  end

  return out
end

--- Extract links from many sources.
---@param sources Lib.Harvest.Source[]
---@param opts { paths?: boolean, code_fences?: boolean, unique?: boolean }|nil
---@return OpenNvim.UrlView.Link[]
function M.from_sources(sources, opts)
  opts = opts or {}
  local out = {}
  local seen = {}

  for _, src in ipairs(sources or {}) do
    for _, lk in ipairs(M.from_source(src, opts)) do
      if opts.unique then
        if not seen[lk.target] then
          seen[lk.target] = true
          out[#out + 1] = lk
        end
      else
        out[#out + 1] = lk
      end
    end
  end

  return out
end

return M
