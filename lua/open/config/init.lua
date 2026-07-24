---@module 'open.config'
---@brief Setup options and defaults for open.nvim.

local M = {}

---@type OpenNvim.Config
local defaults = require("open.config.DEFAULTS")

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
    local ok, kw_mod = pcall(require, "open.keywords")
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

---Whether verbose/debug logging is enabled (`setup({ debug = true })`).
---@return boolean
function M.is_debug()
  return current.debug == true
end

return M
