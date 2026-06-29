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
  handlers         = { "filemanager", "browser", "notepad", "nvim_internal", "default" },
  keymaps          = {},
  builtin_keywords = true,   -- set false to disable all built-in scope keywords
  keywords         = {},     -- user-defined keyword → path overrides / additions
}

---@type OpenNvim.Config
local current = vim.deepcopy(defaults)

---Merge user options into the defaults.
---@param opts OpenNvim.Config|nil
function M.setup(opts)
  opts = opts or {}

  -- Build keyword map separately: built-ins (unless disabled) + user overrides.
  -- We cannot use tbl_deep_extend for this because values may be functions.
  local merged_keywords = {}

  if opts.builtin_keywords ~= false then
    local ok, kw_mod = pcall(require, "open_nvim.keywords")
    if ok then
      for k, v in pairs(kw_mod.builtin()) do
        merged_keywords[k] = v
      end
    end
  end

  for k, v in pairs(opts.keywords or {}) do
    merged_keywords[k] = v  -- user overrides built-ins
  end

  -- Deep-extend everything else, then attach the pre-built keyword map.
  local opts_rest = vim.tbl_deep_extend("force", {}, opts)
  opts_rest.keywords         = nil
  opts_rest.builtin_keywords = nil

  current                  = vim.tbl_deep_extend("force", defaults, opts_rest)
  current.keywords         = merged_keywords
  current.builtin_keywords = opts.builtin_keywords ~= false
end

---Return the active config.
---@return OpenNvim.Config
function M.get()
  return current
end

return M
