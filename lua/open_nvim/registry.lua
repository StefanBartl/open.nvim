---@module 'open_nvim.registry'
---@brief Central handler registry for :Open.
---@description
--- Handlers are registered once during setup() and looked up by key at
--- command invocation time. Duplicate keys produce a warning to allow
--- user overrides without hard errors.

local notify = require("lib.nvim.notify").create("[open_nvim.registry]")

local M = {}

---@type table<string, OpenNvim.Handler>
local _handlers = {}

-- ---------------------------------------------------------------------------
-- Write API
-- ---------------------------------------------------------------------------

---Register a handler. Overwrites an existing registration with a warning.
---@param handler OpenNvim.Handler
---@return boolean success
function M.register(handler)
  if type(handler) ~= "table" then
    notify.error("handler must be a table")
    return false
  end
  if type(handler.key) ~= "string" or handler.key == "" then
    notify.error("handler.key must be a non-empty string")
    return false
  end
  if type(handler.run) ~= "function" then
    notify.error("handler '" .. handler.key .. "': run must be a function")
    return false
  end
  if type(handler.desc) ~= "string" then
    handler.desc = "(no description)"
  end
  if _handlers[handler.key] then
    notify.warn("'" .. handler.key .. "' already registered — overwriting")
  end
  _handlers[handler.key] = handler
  return true
end

-- ---------------------------------------------------------------------------
-- Read API
-- ---------------------------------------------------------------------------

---Look up a handler by key.
---@param key string
---@return OpenNvim.Handler|nil
function M.get(key)
  if type(key) ~= "string" then return nil end
  return _handlers[key]
end

---Return a sorted list of all registered handler keys.
---@return string[]
function M.list_keys()
  local keys = {}
  for k in pairs(_handlers) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

---Return all registered handlers sorted by key.
---@return OpenNvim.Handler[]
function M.list()
  local result = {}
  for _, h in pairs(_handlers) do result[#result + 1] = h end
  table.sort(result, function(a, b) return a.key < b.key end)
  return result
end

return M
