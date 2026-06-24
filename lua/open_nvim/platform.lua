---@module 'open_nvim.platform'
---@brief Platform detection for open.nvim.
---@description
--- Determines the host OS once and caches the result for the session.
--- All sub-modules consume this instead of calling vim.fn.has() repeatedly.

local M = {}

---@type OpenNvim.Platform|nil
local _cache = nil

---Read /proc/version to detect a Microsoft/WSL kernel.
---@return boolean
local function detect_wsl()
  local handle = io.open("/proc/version", "r")
  if not handle then return false end
  local content = handle:read("*l") or ""
  handle:close()
  return content:lower():find("microsoft") ~= nil
end

---Detect and cache the current platform (called at most once per session).
---@return OpenNvim.Platform
function M.get()
  if _cache then return _cache end

  local is_win = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
  local is_mac = vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1

  local is_wsl = false
  if not is_win then
    local ok, result = pcall(detect_wsl)
    is_wsl = ok and result or false
  end

  _cache = {
    is_win   = is_win,
    is_mac   = is_mac,
    is_wsl   = is_wsl,
    is_linux = not is_win and not is_mac,
  }

  return _cache
end

return M
