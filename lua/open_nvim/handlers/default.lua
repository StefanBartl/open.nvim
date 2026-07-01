---@module 'open_nvim.handlers.default'
---@brief Handler that opens a path or URL in the system default application.
---@description
--- Equivalent to a double-click on the file: the OS chooses the application
--- based on the file extension / URL scheme (e.g. PDF → PDF viewer,
--- .docx → Word, https:// → default browser).
---
--- Platform dispatch:
---   Windows        → cmd.exe /C start "" <target>
---   WSL            → converts path to Win path via wslpath, then same as Win;
---                    falls back to xdg-open for pure URL targets
---   macOS          → open <target>
---   Linux          → xdg-open <target>

local notify   = require("lib.nvim.notify").create("[open_nvim.default]")
local platform = require("open_nvim.platform")
local util     = require("open_nvim.util")

local M = {}

---@param text string
---@return boolean
local function looks_like_url(text)
  return text:match("^https?://") ~= nil
    or text:match("^ftp://") ~= nil
    or text:match("^www%.") ~= nil
end

---@param unix_path string
---@return string|nil
local function wsl_to_win_path(unix_path)
  local out = vim.fn.system({ "wslpath", "-w", unix_path }):gsub("\n", "")
  return (out ~= "" and out) or nil
end

---@param ctx OpenNvim.Context
---@return boolean
local function run(ctx)
  local text = ctx.text
  local plat = platform.get()
  local cmd

  if plat.is_win then
    cmd = { "cmd.exe", "/C", "start", '""', text }

  elseif plat.is_wsl then
    if looks_like_url(text) then
      -- URLs go straight to cmd.exe start (opens default Windows browser)
      cmd = { "cmd.exe", "/C", "start", '""', text }
    else
      local win_path = wsl_to_win_path(vim.fn.expand(text))
      if win_path then
        cmd = { "cmd.exe", "/C", "start", '""', win_path }
      elseif vim.fn.executable("xdg-open") == 1 then
        -- Fallback for Linux-side files with no Windows equivalent
        cmd = { "xdg-open", text }
      else
        notify.error("Cannot determine how to open: " .. text)
        return false
      end
    end

  elseif plat.is_mac then
    cmd = { "open", vim.fn.expand(text) }

  else
    if vim.fn.executable("xdg-open") ~= 1 then
      notify.error("xdg-open not found — install xdg-utils")
      return false
    end
    cmd = { "xdg-open", vim.fn.expand(text) }
  end

  local ok = util.run_detached(cmd, "default")
  if ok then notify.info(text) end
  return ok
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key  = "default",
    desc = "Open in the system default application (like a double-click)",
    run  = run,
  })
end

return M
