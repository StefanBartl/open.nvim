---@module 'open.context'
---@brief Resolves the target text (path or URL) for the :Open command.
---@description
--- Two-stage resolution:
---   1. M.gather()  — collects raw, target-agnostic signals from the current
---      editor state: tree-buffer node, <cfile>, <cWORD>, visual selection,
---      current buffer path.
---   2. M.resolve(arg, target, signals) — turns those signals (plus an optional
---      explicit user override) into the final OpenNvim.Context consumed by
---      every handler.
---
--- Explicit override tokens for `arg`:
---   "%"           → current buffer path
---   "cfile"       → <cfile> text under the cursor
---   "git"         → nearest Git root (`git rev-parse --show-toplevel`)
---   "path=<path>" → literal path given after "path="
---   anything else → used verbatim as the resolved text
---
--- Default heuristic (no explicit `arg`):
---   1. Tree-buffer node (neo-tree / nvim-tree / netrw) — wins if current
---      buffer is a recognised tree buffer.
---   2. Path-oriented targets (filemanager, split, vsplit, tab):
---      <cfile> if it resolves to an existing path on disk, else buffer path (%).
---   3. All other targets (browser, notepad, …):
---      visual selection, else <cWORD>, else buffer path (%).
---@see open.@types

local M = {}

-- ---------------------------------------------------------------------------
-- Per-invocation cache
-- ---------------------------------------------------------------------------

---@type OpenNvim.Signals|nil
local _cached_signals = nil
local _cache_active = false

---Run `fn()` with `M.gather()` memoized for its duration, so any nested
---`M.resolve()` call that gathers its own signals (i.e. is not given a
---pre-gathered `signals` table) reuses the same read of editor state
---instead of re-reading it.
---@param fn fun()
function M.with_cache(fn)
  local was_active = _cache_active
  _cache_active = true
  local ok, err = pcall(fn)
  if not was_active then
    _cache_active = false
    _cached_signals = nil
  end
  if not ok then error(err, 0) end
end

-- ---------------------------------------------------------------------------
-- Debug logging
-- ---------------------------------------------------------------------------

---Log `msg` to :messages when `setup({ debug = true })` is active.
---@param msg string
local function debug_log(msg)
  local ok, cfg = pcall(require, "open.config")
  if ok and cfg.is_debug() then
    require("lib.nvim.notify").create("[open.context]").info(msg)
  end
end

-- ---------------------------------------------------------------------------
-- URL heuristic
-- ---------------------------------------------------------------------------

---@param text string
---@return boolean
local function looks_like_url(text)
  return text:match("^https?://") ~= nil
    or text:match("^ftp://") ~= nil
    or text:match("^www%.") ~= nil
end

-- ---------------------------------------------------------------------------
-- Existing-path check
-- ---------------------------------------------------------------------------

---Try to resolve `candidate` to an existing path: verbatim first, then
---relative to the current buffer's directory.
---@param candidate string|nil
---@return string|nil
local function resolve_existing_path(candidate)
  if type(candidate) ~= "string" or candidate == "" then return nil end

  local expanded = vim.fn.expand(candidate)
  if expanded ~= "" and vim.uv.fs_stat(expanded) then
    return expanded
  end

  local bufdir = vim.fn.expand("%:p:h")
  if bufdir ~= "" then
    local sep    = package.config:sub(1, 1)
    local joined = bufdir:gsub("[/\\]$", "") .. sep .. candidate
    if vim.uv.fs_stat(joined) then return joined end
  end

  return nil
end

-- ---------------------------------------------------------------------------
-- Git root resolution
-- ---------------------------------------------------------------------------

---Resolve the nearest Git root directory (relative to the cwd), if any.
---@return string|nil
local function resolve_git_root()
  local out = vim.fn.system({ "git", "rev-parse", "--show-toplevel" })
  if vim.v.shell_error ~= 0 then return nil end
  out = out:gsub("[\r\n]+$", "")
  return out ~= "" and out or nil
end

-- ---------------------------------------------------------------------------
-- Tree-buffer node resolution
-- ---------------------------------------------------------------------------

---@return string|nil
local function resolve_neotree_path()
  local ok_m, manager = pcall(require, "neo-tree.sources.manager")
  if not ok_m then return nil end

  local buf    = vim.api.nvim_get_current_buf()
  local source = (vim.b[buf] and vim.b[buf].neo_tree_source) or "filesystem"

  local ok_s, state = pcall(manager.get_state, source)
  if not ok_s or not state then return nil end

  -- Try config-specific node utility first (pcall-guarded: config-specific dep)
  local ok_nu, node_utils = pcall(require, "config.neotree.utils.node")
  if ok_nu then
    local node = node_utils.get_current(state)
    if node then
      local path = node:get_id()
      if type(path) == "string" and path ~= "" then return path end
    end
  end

  if state.tree then
    local ok_n, node = pcall(state.tree.get_node, state.tree)
    if ok_n and node then
      local path = node:get_id()
      if type(path) == "string" and path ~= "" then return path end
    end
  end

  return nil
end

---@return string|nil
local function resolve_nvimtree_path()
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then return nil end
  local ok_n, node = pcall(function() return api.tree.get_node_under_cursor() end)
  if ok_n and node and node.absolute_path and node.absolute_path ~= "" then
    return node.absolute_path
  end
  return nil
end

---@return string|nil
local function resolve_netrw_path()
  local buf    = vim.api.nvim_get_current_buf()
  local curdir = vim.b[buf] and vim.b[buf].netrw_curdir
  if not curdir or curdir == "" then return nil end

  local line  = vim.api.nvim_get_current_line()
  local entry = line and line:match("^%s*(.-)%s*$")
  if not entry or entry == "" then return curdir end

  local sep = package.config:sub(1, 1)
  return curdir:gsub("[/\\]$", "") .. sep .. entry
end

---Return the node path if the current buffer is a recognised tree buffer.
---@return string|nil
local function resolve_tree_node_path()
  local buf = vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) then return nil end
  local ft = vim.bo[buf].filetype
  if ft == "neo-tree"  then return resolve_neotree_path() end
  if ft == "NvimTree"  then return resolve_nvimtree_path() end
  if ft == "netrw"     then return resolve_netrw_path() end
  return nil
end

-- ---------------------------------------------------------------------------
-- Target classification
-- ---------------------------------------------------------------------------

---Targets for which a validated <cfile> path is preferred over cWORD/visual.
---@type table<string, boolean>
local PATH_TARGETS = {
  filemanager = true,
  split       = true,
  vsplit      = true,
  tab         = true,
  terminal    = true,
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Gather raw context signals without making any target-specific decision.
---Memoized for the duration of an enclosing `M.with_cache()` call.
---@return OpenNvim.Signals
function M.gather()
  if _cache_active and _cached_signals then
    return _cached_signals
  end

  ---@type OpenNvim.Signals
  local signals = {}

  signals.tree_path = resolve_tree_node_path()

  local cfile = vim.fn.expand("<cfile>")
  signals.cfile      = (cfile ~= "" and cfile) or nil
  signals.cfile_path = resolve_existing_path(signals.cfile)

  local cword = vim.fn.expand("<cWORD>")
  signals.cword = (cword ~= "" and cword) or nil

  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local ok, sel = pcall(function()
      local s     = vim.fn.getpos("'<")
      local e     = vim.fn.getpos("'>")
      local lines = vim.api.nvim_buf_get_text(0, s[2] - 1, s[3] - 1, e[2] - 1, e[3], {})
      return table.concat(lines, "")
    end)
    if ok and sel and sel ~= "" then signals.visual = sel end
  end

  local bufname = vim.api.nvim_buf_get_name(0)
  signals.buffer_path = (bufname ~= "" and bufname) or nil

  debug_log(string.format(
    "gather: tree_path=%s cfile=%s cword=%s visual=%s buffer_path=%s",
    tostring(signals.tree_path), tostring(signals.cfile),
    tostring(signals.cword), tostring(signals.visual), tostring(signals.buffer_path)))

  if _cache_active then
    _cached_signals = signals
  end

  return signals
end

---Choose a handler key when the user gives no explicit target.
---@param signals OpenNvim.Signals
---@return string
function M.default_target(signals)
  local cfg = require("open.config").get()

  if signals.tree_path then
    return cfg.default_filemanager
  end

  local probe = signals.cfile or signals.cword or signals.buffer_path or ""
  if probe:match("^https?://") or probe:match("^ftp://") or probe:match("^www%.") then
    return cfg.default_browser
  end

  return cfg.default_filemanager
end

---Resolve what should be opened for `target`.
---@param arg     string|nil             Explicit scope: "%", "cfile", "path=…", or literal.
---@param target  string|nil             Handler key the context is being built for.
---@param signals OpenNvim.Signals|nil   Pre-gathered signals; gathered if omitted.
---@return OpenNvim.Context|nil
function M.resolve(arg, target, signals)
  signals = signals or M.gather()

  local text

  if arg and arg ~= "" then
    if arg == "%" then
      text = signals.buffer_path
    elseif arg == "cfile" then
      text = signals.cfile
    elseif arg == "git" then
      text = resolve_git_root()
    elseif arg:sub(1, 5) == "path=" then
      text = require("lib.nvim.cross.fs.expand_path")(arg:sub(6))
    else
      -- Check named scope keywords before falling back to verbatim text.
      local ok_cfg, cfg = pcall(require, "open.config")
      local kw = ok_cfg and cfg.get().keywords and cfg.get().keywords[arg]
      if kw then
        text = type(kw) == "function" and kw() or require("lib.nvim.cross.fs.expand_path")(tostring(kw))
      else
        text = arg
      end
    end
  elseif signals.tree_path then
    text = signals.tree_path
  elseif PATH_TARGETS[target] then
    text = signals.cfile_path or signals.buffer_path
  else
    text = signals.visual or signals.cword or signals.buffer_path
  end

  if not text or text == "" then
    debug_log(string.format("resolve: arg=%s target=%s → nothing to open", tostring(arg), tostring(target)))
    return nil
  end

  local ctx = {
    text    = text,
    is_url  = looks_like_url(text),
    is_path = resolve_existing_path(text) ~= nil,
  }

  debug_log(string.format(
    "resolve: arg=%s target=%s → text=%q is_url=%s is_path=%s",
    tostring(arg), tostring(target), ctx.text, tostring(ctx.is_url), tostring(ctx.is_path)))

  return ctx
end

return M
