---@module 'open.handlers.nvim_internal'
---@brief Handlers that open files inside the current Neovim session.
---@description
--- Registered handlers: split, vsplit, tab.
--- Each validates the context path and opens it via the appropriate
--- Neovim ex-command. URL contexts are rejected.

local notify = require("lib.nvim.notify").create("[open.nvim_internal]")

local M = {}

---Resolve and validate a filesystem path from the context.
---@param ctx OpenNvim.Context
---@return string|nil, string|nil
local function resolve_file_path(ctx)
  if ctx.is_url then return nil, "Text looks like a URL, not a local path" end

  local expanded = vim.fn.expand(ctx.text)
  if expanded == "" then return nil, "Cannot expand path: " .. ctx.text end

  if not vim.uv.fs_stat(expanded) then
    return nil, "Path does not exist: " .. expanded
  end

  return expanded, nil
end

---@param cmd_name string  Ex command to use (e.g. "split", "vsplit", "tabedit").
---@param label    string  Handler label for messages.
---@return fun(ctx: OpenNvim.Context): boolean
local function make_nvim_open_fn(cmd_name, label)
  return function(ctx)
    local path, err = resolve_file_path(ctx)
    if not path then
      notify.error("[" .. label .. "] " .. (err or "unknown error"))
      return false
    end
    local ok, run_err = pcall(vim.cmd, cmd_name .. " " .. vim.fn.fnameescape(path))
    if not ok then
      notify.error("[" .. label .. "] Failed: " .. tostring(run_err))
      return false
    end
    notify.info("[" .. label .. "] " .. path)
    return true
  end
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key  = "split",
    desc = "Open file in a new horizontal split inside Neovim",
    run  = make_nvim_open_fn("split", "split"),
  })
  register_fn({
    key  = "vsplit",
    desc = "Open file in a new vertical split inside Neovim",
    run  = make_nvim_open_fn("vsplit", "vsplit"),
  })
  register_fn({
    key  = "tab",
    desc = "Open file in a new Neovim tab",
    run  = make_nvim_open_fn("tabedit", "tab"),
  })
end

return M
