---@module 'open.bindings.keymaps'
---@brief Optional keymaps for common :Open invocations, configured via setup().
---@description
--- open.nvim ships with no default keymaps. Setting `cfg.keymaps.<name>` to
--- an lhs string registers a normal-mode keymap for that fixed invocation:
---
---   open_default = "<leader>oo"  -- :Open
---   open_browser = "<leader>ob"  -- :Open browser
---   open_manager = "<leader>of"  -- :Open filemanager

local notify = require("lib.nvim.notify").create("[open.keymaps]")

local M = {}

---Valid `keymaps.<name>` keys.
---@type table<string, boolean>
local VALID = { open_default = true, open_browser = true, open_manager = true }

---Maps a keymaps.<name> key to the target argument of the `:Open [target]`
---it triggers. Absent here (open_default) means the bare command.
---@type table<string, string>
local TARGET_ARG = { open_browser = "browser", open_manager = "filemanager" }

---Register keymaps declared in `cfg.keymaps`.
---@param cfg OpenNvim.Config
function M.register(cfg)
  local keymaps = cfg.keymaps
  if type(keymaps) ~= "table" then return end

  for name, lhs in pairs(keymaps) do
    if lhs and lhs ~= "" then
      if not VALID[name] then
        notify.warn("Unknown keymaps." .. tostring(name) .. " — ignoring")
      else
        local target = TARGET_ARG[name]
        local rhs = target and ("<Cmd>" .. cfg.command .. " " .. target .. "<CR>")
          or ("<Cmd>" .. cfg.command .. "<CR>")
        vim.keymap.set("n", lhs, rhs, {
          desc    = "open.nvim: " .. name,
          silent  = true,
          noremap = true,
        })
      end
    end
  end
end

return M
