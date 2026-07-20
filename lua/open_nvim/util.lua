---@module 'open_nvim.util'
---@brief Shared low-level utilities for open.nvim.
---@description
--- Provides:
---   run_detached  — spawn a detached process (vim.system or jobstart fallback)
---   url_encode    — percent-encode a string for URL usage
---   find_exec     — return the first executable found from a candidate list

local M = {}

-- ---------------------------------------------------------------------------
-- Process spawning
-- ---------------------------------------------------------------------------

---Spawn a detached process. The parent Neovim session does not wait for it.
---Low-level: reports failure via the second return value instead of
---notifying directly — callers decide whether/how to surface it to the user.
---@param cmd   string[]  Argument vector; first element is the executable.
---@param label string    Human-readable name used in error messages.
---@return boolean success
---@return string|nil err
function M.run_detached(cmd, label)
  if type(cmd) ~= "table" or #cmd == 0 then
    return false, "run_detached: invalid cmd for '" .. label .. "'"
  end

  -- Delegates the Windows/WSL-jobstart vs vim.system(detach) vs
  -- Neovim<0.10-jobstart fallback chain to lib.nvim.cross.run.run_detached
  -- (this module's own version was upstreamed into it).
  local ok, err = require("lib.nvim.cross.run").run_detached(cmd)
  if not ok then
    return false, "Failed to launch '" .. label .. "': " .. tostring(err)
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
