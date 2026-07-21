---@module 'open.viewer.scan'
---@brief Extract link-like targets (URLs, markdown links, file paths) from lines.
---@description
--- The extraction half of `:Open viewer`. Given `Lib.Harvest.Source` records
--- it produces `OpenNvim.Viewer.Link` entries with enough provenance to jump
--- back to (file, line, column) or hand the target to `registry.dispatch`.
---
--- Recognizes three syntactic kinds:
---   - `mdlink` — `[text](target)`, reported with its target, not its label
---   - `url`    — a bare `scheme://…` or `www.…` run
---   - `path`   — a filesystem-looking token that actually exists on disk
---
--- and one semantic flag, `is_url`, which is what callers filter on: a
--- markdown link to `https://…` is a `mdlink` *and* a URL, while one to
--- `../notes.md` is a `mdlink` that is not. Keeping the two separate is what
--- lets `:UrlView` mean "everything openable in a browser" without also
--- meaning "everything written with brackets".
---
--- A URL already covered by a markdown link is not reported twice: the
--- markdown pass records the byte spans it consumed and the bare-URL pass
--- skips anything inside one. Without that, every `[docs](https://…)` would
--- produce two entries pointing at the same place.
---
--- Relative markdown targets are resolved against the directory of the file
--- they were found in, not the cwd — `[x](../../lua/init.lua)` inside
--- `docs/notes/startup.md` has to become an absolute path, or opening it from
--- a results list gathered elsewhere would fail.

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

--- Does `target` name something openable in a browser?
---@param target string|nil
---@return boolean
function M.is_url(target)
  if not target or target == "" then
    return false
  end
  return target:match("^%a[%w+.-]*://") ~= nil or target:match("^www%.") ~= nil
end

--- Is `target` a bare in-document anchor (`#heading`)?
---
--- These are table-of-contents entries. A repo-wide scan turns up hundreds of
--- them and none is openable as a file or a URL, so they are dropped unless
--- explicitly asked for.
---@param target string|nil
---@return boolean
function M.is_anchor(target)
  return target ~= nil and target:match("^#") ~= nil
end

---@param tok string
---@return boolean
local function is_absolute(tok)
  return tok:match("^[/\\]") ~= nil or tok:match("^%a:[/\\]") ~= nil or tok:match("^~") ~= nil
end

--- Resolve a relative link target against the directory of its source file.
--- URLs, anchors, and absolute paths pass through unchanged.
---@param target string
---@param base_dir string|nil
---@return string
function M.resolve(target, base_dir)
  if target == "" or M.is_url(target) or M.is_anchor(target) then
    return target
  end
  -- Split a trailing "#anchor" off before touching the filesystem: the
  -- fragment is not part of the filename, and leaving it on would make every
  -- "file.md#section" link resolve to a path that does not exist.
  local path, frag = target:match("^([^#]*)(#.*)$")
  path = path or target
  frag = frag or ""
  if path == "" then
    return target
  end
  if is_absolute(path) then
    return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p")) .. frag
  end
  if not base_dir or base_dir == "" then
    return target
  end
  return vim.fs.normalize(vim.fn.fnamemodify(base_dir .. "/" .. path, ":p")) .. frag
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
  -- Must contain a separator or start with ~ — a bare word is not a path.
  if not (tok:find("[/\\]") or tok:match("^~")) then
    return nil
  end
  local candidates = {}
  local expanded = vim.fn.expand(tok)
  if is_absolute(expanded) then
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
---@return OpenNvim.Viewer.Link[]
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
      local raw = strip_angle_brackets(trim(target))
      out[#out + 1] = {
        display = ("[%s](%s)"):format(text, raw),
        raw_target = raw,
        target = M.resolve(raw, opts.base_dir),
        text = text,
        kind = "mdlink",
        is_url = M.is_url(raw),
        is_anchor = M.is_anchor(raw),
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
            raw_target = url,
            target = url,
            kind = "url",
            is_url = true,
            is_anchor = false,
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
            raw_target = tok,
            target = abs,
            kind = "path",
            is_url = false,
            is_anchor = false,
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
---@param opts { paths?: boolean, code_fences?: boolean, anchors?: boolean }|nil
---@return OpenNvim.Viewer.Link[]
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
        if opts.anchors == true or not lk.is_anchor then
          lk.file = src.file
          lk.bufnr = src.bufnr
          out[#out + 1] = lk
        end
      end
    end
  end

  return out
end

--- Extract links from many sources.
---@param sources Lib.Harvest.Source[]
---@param opts { paths?: boolean, code_fences?: boolean, unique?: boolean, anchors?: boolean }|nil
---@return OpenNvim.Viewer.Link[]
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
