---@module 'open.handlers.notepad'
---@brief Handler that opens text in the system default GUI text editor.
---@description
--- Writes the context text to a temporary file, then launches the
--- platform's GUI text editor.
---   Windows / WSL  → notepad.exe
---   macOS          → open -e (TextEdit)
---   Linux          → xdg-open, then: gedit, kate, mousepad, leafpad, pluma, xed
---
--- "editor" is registered as an alias for "notepad".

local notify   = require("lib.nvim.notify").create("[open.notepad]")
local platform = require("open.platform")
local util     = require("open.util")

local M = {}

---Write text to a temp file. Returns (path, nil) or (nil, errmsg).
---@param text string
---@return string|nil, string|nil
local function write_temp(text)
  local tmpfile = vim.fn.tempname() .. ".txt"
  local ok, err = pcall(function()
    local f = assert(io.open(tmpfile, "w"))
    f:write(text)
    f:close()
  end)
  return ok and tmpfile or nil, ok and nil or tostring(err)
end

---@return string|nil
local function linux_editor()
  return util.find_exec({
    "xdg-open", "gedit", "kate",
    "mousepad", "leafpad", "pluma", "xed",
  })
end

---@param ctx OpenNvim.Context
---@return boolean
local function run(ctx)
  local tmpfile, err = write_temp(ctx.text)
  if not tmpfile then
    notify.error("Failed to create temp file: " .. tostring(err))
    return false
  end

  local plat = platform.get()
  local cmd

  if plat.is_win or plat.is_wsl then
    cmd = { "notepad.exe", tmpfile }
  elseif plat.is_mac then
    cmd = { "open", "-e", tmpfile }
  else
    local ed = linux_editor()
    if not ed then
      notify.error("No suitable GUI text editor found on PATH")
      return false
    end
    cmd = { ed, tmpfile }
  end

  local ok, err = util.run_detached(cmd, "notepad")
  if ok then
    notify.info("Opened temp file: " .. tmpfile)
  else
    notify.error(err)
  end
  return ok
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key  = "notepad",
    desc = "Open text in the system default GUI text editor (via temp file)",
    run  = run,
  })
  register_fn({
    key  = "editor",
    desc = "Alias for notepad: open text in system default GUI text editor",
    run  = run,
  })
end

return M
