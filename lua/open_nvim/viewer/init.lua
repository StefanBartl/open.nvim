---@module 'open_nvim.viewer'
---@brief `:Open viewer` / `:UrlView` / `:MDLinksView` — list links in a scope,
---       then open, export, or copy them.
---@description
--- Replaces the axieax/urlview.nvim dependency with a native implementation
--- built on lib.nvim's harvest primitives:
---
---   scope  (lib.nvim.harvest.scope) → which lines to look at
---   scan   (open_nvim.viewer.scan)  → what counts as a link
---   filter (here)                   → which kinds to keep
---   sort   (here)                   → ordering
---   sink   (lib.nvim.harvest.sink)  → picker / table / clipboard / file
---
--- The picker is lib.nvim's `ui.kit.chooser` (reached via
--- `harvest.sink.select`), which already provides the interaction model this
--- needs: the whole current line is highlighted through
--- `CursorLine:KitSelection`, horizontal motions are mapped to <Nop> so the
--- cursor only ever moves between rows, and <CR> submits.
---
--- Opening is kind-aware: a URL goes to the browser handler, while a local
--- file goes to a Neovim split rather than the system file manager — chasing
--- a markdown link should land you in a buffer you can read and edit.
---@see open_nvim.viewer.scan
---@see lib.nvim.harvest

local notify = require("lib.nvim.notify").create("[open_nvim.viewer]")

local M = {}

-- `OpenNvim.Viewer.Link` is declared in `open_nvim.@types`.

local SORTS = { none = true, file = true, kind = true, alpha = true, line = true }

--- Kind filters. Deliberately allowed to overlap: `urls` is about the
--- *target* (a markdown link to https:// counts), `mdlinks` is about the
--- *syntax* (a markdown link to a local file counts). Filtering on target
--- semantics is what makes `:UrlView` mean "things a browser can open"
--- instead of "things written without brackets".
---@type table<string, fun(lk: OpenNvim.Viewer.Link): boolean>
local FILTERS = {
  all = function() return true end,
  urls = function(lk) return lk.is_url == true end,
  mdlinks = function(lk) return lk.kind == "mdlink" end,
  files = function(lk) return lk.is_url ~= true and not lk.is_anchor end,
  paths = function(lk) return lk.kind == "path" end,
}

--- The kind tokens `run` accepts, for completion.
---@return string[]
function M.kinds()
  local out = {}
  for k in pairs(FILTERS) do
    out[#out + 1] = k
  end
  table.sort(out)
  return out
end

---@return table
local function cfg()
  local ok, c = pcall(require, "open_nvim.config")
  return (ok and c.get().viewer) or {}
end

-- ---------------------------------------------------------------------------
-- Collect
-- ---------------------------------------------------------------------------

--- Gather links for a scope.
---@param scope_token string|nil
---@param opts table|nil
---@return OpenNvim.Viewer.Link[] links, string|nil err
function M.collect(scope_token, opts)
  opts = opts or {}
  local harvest = require("lib.nvim.harvest")
  local scan = require("open_nvim.viewer.scan")

  local sources, err
  if opts.range then
    sources, err = harvest.scope.resolve("range", { line1 = opts.line1, line2 = opts.line2 })
  else
    sources, err = harvest.scope.resolve_token(scope_token, {
      recursive = opts.recursive,
      match = opts.match,
    })
  end
  if err then
    return {}, err
  end

  local links = scan.from_sources(sources, {
    paths = opts.paths,
    unique = opts.unique,
    anchors = opts.anchors,
  })

  return M.filter(links, opts.kind), nil
end

--- Keep only links matching `kind`.
---@param links OpenNvim.Viewer.Link[]
---@param kind string|nil
---@return OpenNvim.Viewer.Link[]
function M.filter(links, kind)
  kind = kind or "all"
  local pred = FILTERS[kind]
  if not pred or kind == "all" then
    return links
  end
  local out = {}
  for _, lk in ipairs(links) do
    if pred(lk) then
      out[#out + 1] = lk
    end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Sort
-- ---------------------------------------------------------------------------

--- Sort `links` in place.
---
--- Every comparator falls through to (file, line, col) as a tiebreaker so the
--- result is a total order — `table.sort` on a comparator that reports two
--- distinct elements as mutually non-less is free to order them arbitrarily
--- between runs, which would make the same command produce different output.
---@param links OpenNvim.Viewer.Link[]
---@param how string|nil
---@return OpenNvim.Viewer.Link[]
function M.sort(links, how)
  how = how or "none"
  if how == "none" or not SORTS[how] then
    return links
  end

  local function by_pos(a, b)
    local af, bf = a.file or "", b.file or ""
    if af ~= bf then
      return af < bf
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return (a.col or 0) < (b.col or 0)
  end

  table.sort(links, function(a, b)
    if how == "file" or how == "line" then
      return by_pos(a, b)
    end
    if how == "kind" then
      if a.kind ~= b.kind then
        return a.kind < b.kind
      end
      return by_pos(a, b)
    end
    local at, bt = (a.target or ""):lower(), (b.target or ""):lower()
    if at ~= bt then
      return at < bt
    end
    return by_pos(a, b)
  end)

  return links
end

-- ---------------------------------------------------------------------------
-- Formatting
-- ---------------------------------------------------------------------------

--- Shorten `s` to at most `max` display cells, eliding the middle of a path.
---@param s string
---@param max integer
---@return string
local function shorten(s, max)
  if max < 4 or vim.fn.strdisplaywidth(s) <= max then
    return s
  end
  local ok, mod = pcall(require, "lib.nvim.fs.path_shorten")
  if ok then
    local fn = type(mod) == "function" and mod or (type(mod) == "table" and mod.shorten)
    if type(fn) == "function" then
      local ok2, short = pcall(fn, s, { max_len = max, style = "fit" })
      if ok2 and type(short) == "string" and short ~= "" and vim.fn.strdisplaywidth(short) <= max then
        return short
      end
    end
  end
  -- Fallback: keep the tail, which is the part that identifies the target.
  return "…" .. s:sub(-(max - 1))
end

--- Right-pad `s` to `w` display cells.
---
--- Not `("%-" .. w .. "s")`: Lua's `%s` width counts *bytes*, and a shortened
--- cell contains a "…" that is 3 bytes but 1 display cell. Byte-padding such a
--- row stops short, and the target column then starts two cells left of every
--- other row.
---@param s string
---@param w integer
---@return string
local function pad(s, w)
  local gap = w - vim.fn.strdisplaywidth(s)
  return gap > 0 and (s .. string.rep(" ", gap)) or s
end

--- Short, human-facing location label for a link.
---@param lk OpenNvim.Viewer.Link
---@return string
function M.where(lk)
  if lk.file then
    return ("%s:%d"):format(vim.fn.fnamemodify(lk.file, ":t"), lk.lnum)
  end
  return ("buf:%d"):format(lk.lnum)
end

--- Display form of a target: a local path under the cwd is shown relative to
--- it, because an absolute path repeats the same 40-character prefix on every
--- row and pushes the part that actually differs off the right edge.
---@param lk OpenNvim.Viewer.Link
---@return string
function M.display_target(lk)
  if lk.is_url then
    return lk.target
  end
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  local t = vim.fs.normalize(lk.target)
  if t:sub(1, #cwd + 1) == cwd .. "/" then
    return t:sub(#cwd + 2)
  end
  return t
end

--- Build aligned, width-aware picker labels for `links`.
---
--- Column widths are measured across the whole result set rather than
--- hardcoded: a fixed `%-24s` overflows the moment one filename is 25 cells
--- wide, and every following row then loses its alignment.
---@param links OpenNvim.Viewer.Link[]
---@param width integer|nil  Total budget in display cells.
---@return string[]
function M.labels(links, width)
  width = width or math.max(40, math.min((vim.o.columns or 80) - 8, 160))

  local kind_w, where_w = 0, 0
  local wheres, targets = {}, {}
  for i, lk in ipairs(links) do
    wheres[i] = M.where(lk)
    targets[i] = M.display_target(lk)
    kind_w = math.max(kind_w, vim.fn.strdisplaywidth(lk.kind))
    where_w = math.max(where_w, vim.fn.strdisplaywidth(wheres[i]))
  end

  -- Cap the location column so one pathological filename cannot squeeze out
  -- the target column — the target is what the user is choosing between.
  where_w = math.min(where_w, math.max(12, math.floor(width * 0.35)))

  local target_w = math.max(12, width - kind_w - where_w - 2)

  local out = {}
  for i, lk in ipairs(links) do
    out[i] = table.concat({
      pad(lk.kind, kind_w),
      pad(shorten(wheres[i], where_w), where_w),
      shorten(targets[i], target_w),
    }, " ")
  end
  return out
end

--- Rows for the table/CSV renderers.
---@param links OpenNvim.Viewer.Link[]
---@return string[] headers, string[][] rows
function M.rows(links)
  local rows = {}
  for i, lk in ipairs(links) do
    rows[i] = { lk.kind, M.where(lk), lk.text or "", lk.target }
  end
  return { "Kind", "Location", "Text", "Target" }, rows
end

--- Render links as markdown links, one per line. A link that already had a
--- label keeps it; a bare URL or path gets its host/basename as the label,
--- because `[](url)` renders as an invisible link.
---@param links OpenNvim.Viewer.Link[]
---@return string
function M.as_markdown(links)
  local out = {}
  for i, lk in ipairs(links) do
    local label = lk.text
    if not label or label == "" then
      if lk.is_url then
        label = lk.target:match("^%a[%w+.-]*://([^/]+)") or lk.target
      else
        label = vim.fn.fnamemodify(lk.target, ":t")
      end
    end
    out[i] = ("[%s](%s)"):format(label, lk.target)
  end
  return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- Open
-- ---------------------------------------------------------------------------

--- Open one link through the appropriate handler.
---
--- URLs go to the browser. Anything else is a local file and follows into a
--- Neovim buffer rather than the system file manager: chasing a markdown link
--- should land you somewhere you can read and edit, not in Explorer.
---@param lk OpenNvim.Viewer.Link
function M.open(lk)
  local registry = require("open_nvim.registry")
  local scan = require("open_nvim.viewer.scan")
  local c = require("open_nvim.config").get()
  local conf = cfg()

  if lk.is_url or scan.is_url(lk.target) then
    local target = lk.target
    -- A bare "www.x" has no scheme; the browser handler needs one.
    if not target:match("^%a[%w+.-]*:") then
      target = "https://" .. target
    end
    registry.dispatch(c.default_browser, { text = target, is_url = true, is_path = false })
    return
  end

  -- Split a trailing "#anchor" back off: it is not part of the filename, but
  -- the heading it names is worth jumping to once the file is open.
  local path, frag = lk.target:match("^([^#]*)(#.+)$")
  path = path or lk.target

  if vim.fn.isdirectory(path) == 1 then
    registry.dispatch(c.default_filemanager, { text = path, is_url = false, is_path = true })
    return
  end

  if vim.fn.filereadable(path) ~= 1 then
    notify.warn("Target does not exist: " .. path)
    return
  end

  registry.dispatch(conf.open_file or "split", { text = path, is_url = false, is_path = true })

  if frag then
    -- Best-effort heading jump; a missing anchor just leaves the cursor put.
    local slug = frag:sub(2):gsub("%-", "[- ]")
    pcall(vim.fn.search, "\\c^#\\+\\s*.*" .. slug, "w")
  end
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

--- Entry point for the user commands.
---@param opts table
function M.run(opts)
  opts = opts or {}
  local conf = cfg()

  local kind = opts.kind or "all"
  if not FILTERS[kind] then
    notify.warn(("unknown kind '%s' (expected: %s)"):format(kind, table.concat(M.kinds(), ", ")))
    return
  end

  local links, err = M.collect(opts.scope, {
    kind = kind,
    paths = opts.paths,
    unique = opts.unique ~= false,
    recursive = opts.recursive,
    match = opts.match,
    anchors = opts.anchors,
    range = opts.range,
    line1 = opts.line1,
    line2 = opts.line2,
  })
  if err then
    notify.warn(err)
    return
  end
  if #links == 0 then
    notify.info(("No %s links found in scope: %s"):format(kind, opts.scope or "%"))
    return
  end

  M.sort(links, opts.sort or conf.sort or "none")

  local out = opts.out or conf.output or "picker"
  local harvest = require("lib.nvim.harvest")

  if out == "picker" then
    -- Labels are precomputed as a set so column widths can be measured across
    -- every row; the per-item `format` callback just looks its row up.
    local labels = M.labels(links)
    local index = {}
    for i, lk in ipairs(links) do
      index[lk] = labels[i]
    end

    harvest.sink.select(links, {
      prompt = ("%s (%d)"):format(kind == "all" and "Links" or kind, #links),
      format = function(lk)
        return index[lk] or lk.target
      end,
    }, function(lk)
      M.open(lk)
    end)
    return
  end

  local text
  if out == "mdlinks" then
    text = M.as_markdown(links)
    out = conf.mdlinks_output or "clipboard"
  elseif out == "csv" then
    local headers, rows = M.rows(links)
    text = harvest.render.csv(headers, rows)
    out = "buffer"
  else
    local headers, rows = M.rows(links)
    text = harvest.render.markdown_table(headers, rows)
  end

  local ok, emit_err = harvest.emit(text, out, {
    title = "viewer://links",
    filetype = "markdown",
  })
  if not ok then
    notify.warn(emit_err or "output failed")
    return
  end
  if out == "clipboard" then
    notify.info(("Copied %d link(s) to clipboard"):format(#links))
  elseif out:match("^file") then
    notify.info(("Wrote %d link(s)"):format(#links))
  end
end

return M
