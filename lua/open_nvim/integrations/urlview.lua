---@module 'open_nvim.integrations.urlview'
---@brief Integration with urlview.nvim (axieax/urlview.nvim).
---@description
--- Registers a custom urlview action "open_in_browser" that routes the
--- selected URL through open.nvim's own registry/handler dispatch instead
--- of re-implementing cross-platform browser-launch logic. Whichever
--- handler `default_browser` points to (default: "browser", but also
--- "chrome"/"firefox"/… if the user configured it) is used.
---
--- This module is opt-in: it is not loaded by open_nvim.setup(). Call
--- require("open_nvim.integrations.urlview").setup() from urlview.nvim's
--- own plugin config.

local notify = require("lib.nvim.notify").create("[open_nvim.integrations.urlview]")

local M = {}

---Normalise a raw urlview match into a URL string with a scheme.
---@param raw_url string
---@return string|nil
local function sanitize_url(raw_url)
  local url = vim.trim(raw_url or "")
  if url == "" then return nil end
  if not url:match("^%a[%w+.-]*:") then
    url = "http://" .. url
  end
  return url
end

---Open `raw_url` through the configured open.nvim browser handler.
---@param raw_url string
local function open_in_browser(raw_url)
  local url = sanitize_url(raw_url)
  if not url then
    notify.warn("Invalid or empty URL")
    return
  end

  local cfg      = require("open_nvim.config").get()
  local registry = require("open_nvim.registry")

  ---@type OpenNvim.Context
  local ctx = { text = url, is_url = true, is_path = false }
  registry.dispatch(cfg.default_browser, ctx)
end

---Register the "open_in_browser" action with urlview.actions.
---@return boolean success
function M.register_action()
  local ok, actions = pcall(require, "urlview.actions")
  if not ok then
    notify.error("Could not load urlview.actions — is urlview.nvim installed?")
    return false
  end
  actions["open_in_browser"] = open_in_browser
  return true
end

---Register the action, then (unless `opts == false`) call urlview.setup()
---with it wired as the default action/picker.
---@param opts table|false|nil  Merged into urlview.setup(); pass false to skip calling setup.
function M.setup(opts)
  if not M.register_action() then return end
  if opts == false then return end

  local ok, urlview = pcall(require, "urlview")
  if not ok then
    notify.error("urlview.nvim is not installed/loaded")
    return
  end

  opts = opts or {}
  if opts.default_action == nil then
    opts.default_action = "open_in_browser"
  end
  if opts.default_picker == nil and pcall(require, "telescope") then
    opts.default_picker = "telescope"
  end
  if opts.default_picker == nil and pcall(require, "fzf-lua") then
    opts.default_picker = "fzf-lua"
  end

  urlview.setup(opts)
end

return M
