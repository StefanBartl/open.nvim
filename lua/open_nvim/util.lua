---@module 'open_nvim.util'
---@brief Shared low-level utilities for open.nvim.
---@description
--- Provides:
---   run_detached  — spawn a detached process (vim.system or jobstart fallback)
---   url_encode    — percent-encode a string for URL usage
---   find_exec     — return the first executable found from a candidate list

local notify = require("lib.nvim.notify").create("[open_nvim.util]")

local M = {}

-- ---------------------------------------------------------------------------
-- Process spawning
-- ---------------------------------------------------------------------------

---Spawn a detached process. The parent Neovim session does not wait for it.
---@param cmd   string[]  Argument vector; first element is the executable.
---@param label string    Human-readable name used in error messages.
---@return boolean success
function M.run_detached(cmd, label)
  if type(cmd) ~= "table" or #cmd == 0 then
    notify.error("run_detached: invalid cmd for '" .. label .. "'")
    return false
  end

  -- On Windows/WSL, use jobstart(detach) — vim.system detach is unreliable
  -- for GUI processes (explorer.exe, notepad, …) because the handle may
  -- keep the process tethered to Neovim's job infrastructure.
  if vim.fn.has("win32") == 1 or vim.fn.has("wsl") == 1 then
    local ok, job_id = pcall(vim.fn.jobstart, cmd, { detach = true, on_exit = nil })
    if not ok or type(job_id) ~= "number" or job_id <= 0 then
      notify.error("Failed to launch '" .. label .. "' via jobstart")
      return false
    end
    return true
  end

  -- Non-Windows: vim.system with detach (Neovim ≥ 0.10)
  if vim.system then
    local ok, err = pcall(vim.system, cmd, { detach = true }, nil)
    if not ok then
      notify.error("Failed to launch '" .. label .. "': " .. tostring(err))
      return false
    end
    return true
  end

  -- Fallback: vim.fn.jobstart (Neovim < 0.10)
  local ok, job_id = pcall(vim.fn.jobstart, cmd, { detach = true })
  if not ok or type(job_id) ~= "number" or job_id <= 0 then
    notify.error("Failed to launch '" .. label .. "' via jobstart")
    return false
  end
  return true
end

-- ---------------------------------------------------------------------------
-- URL encoding
-- ---------------------------------------------------------------------------

---Percent-encode a string so it is safe for use in a URL query.
---@param s string  Raw text
---@return string   URL-encoded text
function M.url_encode(s)
  s = tostring(s)
  s = s:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  local encoded = s:gsub(" ", "+")
  return encoded
end

-- ---------------------------------------------------------------------------
-- Executable resolution
-- ---------------------------------------------------------------------------

---Return the first executable name from the candidate list, or nil.
---@param candidates string[]
---@return string|nil
function M.find_exec(candidates)
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then
      return name
    end
  end
  return nil
end

return M
