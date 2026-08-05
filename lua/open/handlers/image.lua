---@module 'open.handlers.image'
---@brief Handler that renders an image inside the terminal instead of handing
---       it to an external application.
---@description
--- `:Open image [scope]` draws the target with
--- [images.nvim](https://github.com/StefanBartl/images.nvim) — the image
--- appears in the Neovim window, no external viewer opens.
---
--- Why a dedicated handler rather than routing through "default": the default
--- handler asks the OS to pick an application, which for an image means a
--- separate window stealing focus. This one keeps you in the editor.
---
--- images.nvim is a soft dependency. Without it the handler falls back to the
--- system default application, so `:Open image` never dead-ends.

local notify = require("lib.nvim.notify").create("[open.image]")

local M = {}

---Shared run() body for the "image" handler key.
---@internal
---@param ctx OpenNvim.Context
---@return boolean
local function run(ctx)
  local ok, images = pcall(require, "images")
  if ok and type(images.show) == "function" then
    local called, shown = pcall(images.show, ctx.text)
    if called and shown then
      return true
    end
    -- images.nvim reports its own reason (file missing, terminal incapable);
    -- a second message here would only duplicate it.
    return false
  end

  notify.info("images.nvim not installed — opening in the system application")
  local opened, err = require("lib.nvim.cross.open_default")(ctx.text)
  if not opened then
    notify.error(err or ("Cannot determine how to open: " .. ctx.text))
  end
  return opened
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key = "image",
    desc = "Render an image inside the terminal (via images.nvim)",
    run = run,
  })
end

return M
