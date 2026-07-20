---@module 'open_nvim.urlview'
---@brief `:Open urlview` / `:UrlView` — list every link in a scope, then open,
---       export, or copy it.
---@description
--- Replaces the axieax/urlview.nvim dependency with a native implementation
--- built on lib.nvim's harvest primitives:
---
---   scope  (lib.nvim.harvest.scope)  → which lines to look at
---   scan   (open_nvim.urlview.scan)  → what counts as a link
---   sort   (here)                    → ordering
---   sink   (lib.nvim.harvest.sink)   → picker / table / clipboard / file
---
--- The picker action routes through `registry.dispatch`, so a chosen link is
--- opened by whichever handler the user configured — the same dispatch path
--- `:Open` itself uses, rather than a second copy of browser-launch logic.
---@see open_nvim.urlview.scan
---@see lib.nvim.harvest

local notify = require("lib.nvim.notify").create("[open_nvim.urlview]")

local M = {}

-- `OpenNvim.UrlView.Link` is declared in `open_nvim.@types`.

local SORTS = { none = true, file = true, kind = true, alpha = true, line = true }

---@return table
local function cfg()
  local ok, c = pcall(require, "open_nvim.config")
  local urlview = ok and c.get().urlview or nil
  return urlview or {}
end

-- ---------------------------------------------------------------------------
-- Collect
-- ---------------------------------------------------------------------------

--- Gather links for a scope.
---@param scope_token string|nil
---@param opts { paths?: boolean, unique?: boolean, recursive?: boolean, match?: string, line1?: integer, line2?: integer, range?: boolean }|nil
---@return OpenNvim.UrlView.Link[] links, string|nil err
function M.collect(scope_token, opts)
  opts = opts or {}
  local harvest = require("lib.nvim.harvest")
  local scan = require("open_nvim.urlview.scan")

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

  return scan.from_sources(sources, {
    paths = opts.paths,
    unique = opts.unique,
  }), nil
end

-- ---------------------------------------------------------------------------
-- Sort
-- ---------------------------------------------------------------------------

--- Sort `links` in place.
---
--- Every comparator falls through to (file, line) as a tiebreaker so the
--- result is a total order — `table.sort` on a comparator that reports two
--- distinct elements as mutually non-less is free to order them arbitrarily
--- between runs, which would make the same command produce different tables.
---@param links OpenNvim.UrlView.Link[]
---@param how string|nil
---@return OpenNvim.UrlView.Link[]
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
    -- alpha
    local at, bt = (a.target or ""):lower(), (b.target or ""):lower()
    if at ~= bt then
      return at < bt
    end
    return by_pos(a, b)
  end)

  return links
end

-- ---------------------------------------------------------------------------
-- Render
-- ---------------------------------------------------------------------------

--- Short, human-facing location label for a link.
---@param lk OpenNvim.UrlView.Link
---@return string
local function where(lk)
  if lk.file then
    return ("%s:%d"):format(vim.fn.fnamemodify(lk.file, ":t"), lk.lnum)
  end
  return ("[buffer]:%d"):format(lk.lnum)
end

--- Rows for the table/CSV renderers.
---@param links OpenNvim.UrlView.Link[]
---@return string[] headers, string[][] rows
function M.rows(links)
  local rows = {}
  for i, lk in ipairs(links) do
    rows[i] = { lk.kind, where(lk), lk.text or "", lk.target }
  end
  return { "Kind", "Location", "Text", "Target" }, rows
end

--- Render links as markdown links, one per line — the "turn this into a
--- document" output. A link that already had a label keeps it; a bare URL or
--- path gets its basename/host as the label, because `[](url)` renders empty.
---@param links OpenNvim.UrlView.Link[]
---@return string
function M.as_markdown(links)
  local out = {}
  for i, lk in ipairs(links) do
    local label = lk.text
    if not label or label == "" then
      if lk.kind == "path" then
        label = vim.fn.fnamemodify(lk.target, ":t")
      else
        label = lk.target:match("^%a[%w+.-]*://([^/]+)") or lk.target
      end
    end
    out[i] = ("[%s](%s)"):format(label, lk.target)
  end
  return table.concat(out, "\n")
end

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

--- Open one link through the configured handler.
---@param lk OpenNvim.UrlView.Link
function M.open(lk)
  local registry = require("open_nvim.registry")
  local c = require("open_nvim.config").get()

  local is_url = lk.kind == "url" or lk.target:match("^%a[%w+.-]*://") ~= nil
  local target = lk.target

  -- A bare "www.x" has no scheme; the browser handler needs one.
  if lk.kind == "url" and not target:match("^%a[%w+.-]*:") then
    target = "https://" .. target
  end

  local handler = is_url and c.default_browser or c.default_filemanager
  registry.dispatch(handler, {
    text = target,
    is_url = is_url,
    is_path = not is_url,
  })
end

--- Entry point for the user command.
---@param opts { scope?: string, sort?: string, out?: string, paths?: boolean, unique?: boolean, recursive?: boolean, match?: string, range?: boolean, line1?: integer, line2?: integer }
function M.run(opts)
  opts = opts or {}
  local conf = cfg()

  local links, err = M.collect(opts.scope, {
    paths = opts.paths,
    unique = opts.unique ~= false,
    recursive = opts.recursive,
    match = opts.match,
    range = opts.range,
    line1 = opts.line1,
    line2 = opts.line2,
  })
  if err then
    notify.warn(err)
    return
  end
  if #links == 0 then
    notify.info("No links found in scope: " .. (opts.scope or "%"))
    return
  end

  M.sort(links, opts.sort or conf.sort or "none")

  local out = opts.out or conf.output or "picker"
  local harvest = require("lib.nvim.harvest")

  if out == "picker" then
    harvest.sink.select(links, {
      prompt = ("Links (%d)"):format(#links),
      format = function(lk)
        return ("%-6s %-24s %s"):format(lk.kind, where(lk), lk.target)
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
    title = "urlview://links",
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
