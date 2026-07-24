---@module 'open.handlers.terminal'
---@brief Handler that opens a terminal split in a target's directory.
---@description
--- Registered handler: terminal.
---   :Open terminal          → terminal in the current buffer's directory
---   :Open terminal cfile    → terminal in <cfile>'s parent directory
--- URL contexts are rejected. A path context that is a file resolves to its
--- parent directory; a directory context is used as-is.

local notify = require("lib.nvim.notify").create("[open.terminal]")

local M = {}

---Resolve and validate a directory from the context.
---@param ctx OpenNvim.Context
---@return string|nil, string|nil
local function resolve_dir(ctx)
  if ctx.is_url then return nil, "Text looks like a URL, not a local path" end

  local expanded = vim.fn.expand(ctx.text)
  if expanded == "" then return nil, "Cannot expand path: " .. ctx.text end

  local stat = vim.uv.fs_stat(expanded)
  if not stat then return nil, "Path does not exist: " .. expanded end

  if stat.type == "directory" then return expanded end
  return vim.fn.fnamemodify(expanded, ":h")
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key  = "terminal",
    desc = "Open a terminal split in the target's directory",
    run  = function(ctx)
      local dir, err = resolve_dir(ctx)
      if not dir then
        notify.error(err or "unknown error")
        return false
      end

      local ok, run_err = pcall(function()
        vim.cmd("botright split")
        vim.cmd("lcd " .. vim.fn.fnameescape(dir))
        vim.cmd("terminal")
        vim.cmd("startinsert")
      end)
      if not ok then
        notify.error("Failed: " .. tostring(run_err))
        return false
      end

      notify.info(dir)
      return true
    end,
  })
end

return M
