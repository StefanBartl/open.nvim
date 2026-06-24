---@module 'open_nvim.config'
---@brief Setup options and defaults for open.nvim.

local M = {}

---@type OpenNvim.Config
local defaults = {
  command             = "Open",
  default_filemanager = "filemanager",
  default_browser     = "browser",
  -- Handler module keys to load during setup().
  -- Valid values: "filemanager" | "browser" | "notepad" | "nvim_internal" | "default"
  handlers = { "filemanager", "browser", "notepad", "nvim_internal", "default" },
  keymaps  = {},
}

---@type OpenNvim.Config
local current = vim.deepcopy(defaults)

---Merge user options into the defaults.
---@param opts OpenNvim.Config|nil
function M.setup(opts)
  current = vim.tbl_deep_extend("force", defaults, opts or {})
end

---Return the active config.
---@return OpenNvim.Config
function M.get()
  return current
end

return M
