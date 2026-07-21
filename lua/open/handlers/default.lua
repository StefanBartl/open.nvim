---@module 'open.handlers.default'
---@brief Handler that opens a path or URL in the system default application.
---@description
--- Equivalent to a double-click on the file: the OS chooses the application
--- based on the file extension / URL scheme (e.g. PDF → PDF viewer,
--- .docx → Word, https:// → default browser).
---
--- Delegates the actual cross-platform dispatch to
--- `lib.nvim.cross.open_default`, which this module's own implementation was
--- upstreamed into (identical platform logic: Windows/WSL/macOS/Linux, incl.
--- WSL→Windows path translation via wslpath).

local notify = require("lib.nvim.notify").create("[open.default]")

local M = {}

---@param ctx OpenNvim.Context
---@return boolean
local function run(ctx)
  local ok, err = require("lib.nvim.cross.open_default")(ctx.text)
  if ok then
    notify.info(ctx.text)
  else
    notify.error(err or ("Cannot determine how to open: " .. ctx.text))
  end
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
