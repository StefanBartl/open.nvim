---@module 'open.handlers.filemanager'
---@brief Handler that opens a path in the system file manager.
---@description
--- Platform dispatch (`filemanager.reveal = true`, the default):
---   Windows  → explorer.exe /select,<path>  (reveals file in Explorer)
---   WSL      → explorer.exe via wslpath conversion
---   macOS    → open -R <file>  /  open <dir>  (Finder)
---   Linux    → xdg-open, then common managers as fallback
---
--- With `filemanager.reveal = false`, a file target navigates to its parent
--- directory instead of being selected there. Directory targets are always
--- navigated into, regardless of `reveal`.
---
--- The dispatch itself lives in `lib.nvim.cross.reveal_in_fm`, shared with
--- filetree.nvim's `<leader>fm`; this handler only resolves the path out of
--- the :Open context and reports the outcome. `filemanager.command` overrides
--- the launcher (string or argv list) for users whose manager isn't one of
--- the ones probed on Linux.

local notify = require("lib.nvim.notify").create("[open.filemanager]")
local reveal_in_fm = require("lib.nvim.cross.reveal_in_fm")

local M = {}

---Expand `text` to a filesystem path.
---@internal
---@param text string
---@return string|nil
local function resolve_path(text)
  local expanded = vim.fn.expand(text)
  return (expanded ~= "" and expanded) or nil
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key = "filemanager",
    desc = "Open path in the system file manager",
    run = function(ctx)
      if ctx.is_url then
        notify.warn("Text looks like a URL, not a path")
        return false
      end

      local path = resolve_path(ctx.text)
      if not path then
        notify.error("Cannot resolve path: " .. ctx.text)
        return false
      end

      local fm = require("open.config").get().filemanager or {}

      local ok, err = reveal_in_fm(path, {
        reveal = fm.reveal ~= false,
        command = fm.command,
      })
      if ok then
        notify.info(path)
      else
        notify.error("Failed to open in file manager: " .. tostring(err))
      end
      return ok
    end,
  })
end

return M
