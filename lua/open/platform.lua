---@module 'open.platform'
---@brief Platform detection for open.nvim.
---@description
--- Determines the host OS once and caches the result for the session.
--- All sub-modules consume this instead of calling vim.fn.has() repeatedly.
---
--- Detection itself is delegated to lib.nvim.cross.platform (uname + env-var
--- + /proc fallback chain, more robust than this module's previous single
--- /proc/version check for WSL) — lib.nvim caches each detector internally
--- too, so this module's own _cache exists to keep returning the same
--- OpenNvim.Platform table shape, not to avoid repeated syscalls.

local is_windows = require("lib.nvim.cross.platform.is_windows")
local is_macos   = require("lib.nvim.cross.platform.is_macos")
local is_wsl     = require("lib.nvim.cross.platform.is_wsl")
local is_linux   = require("lib.nvim.cross.platform.is_linux")

local M = {}

---@type OpenNvim.Platform|nil
local _cache = nil

---Detect and cache the current platform (called at most once per session).
---@return OpenNvim.Platform
function M.get()
  if _cache then return _cache end

  _cache = {
    is_win   = is_windows(),
    is_mac   = is_macos(),
    is_wsl   = is_wsl(),
    is_linux = is_linux(),
  }

  return _cache
end

return M
