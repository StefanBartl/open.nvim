---@module 'open.picker'
---@brief Opt-in handler-choice picker for ambiguous no-target invocations.
---@description
--- Used by both `open.open()` and `:Open` when `cfg.picker.enabled == true`
--- and `open.context.candidate_targets()` returns more than one candidate
--- for the current context. Uses `vim.ui.select`, so any `vim.ui.select`
--- override (telescope-ui-select, fzf-lua, dressing.nvim) is picked up
--- automatically; the built-in `vim.ui.select` is used otherwise.

local M = {}

---Prompt the user to choose a handler among `candidates`, then dispatch it.
---@param candidates string[]        Handler keys to choose from.
---@param scope      string|nil      Scope token to resolve against the choice.
---@param signals    OpenNvim.Signals  Pre-gathered signals (not re-read).
function M.select(candidates, scope, signals)
  local context  = require("open.context")
  local registry = require("open.registry")

  vim.ui.select(candidates, {
    prompt = "Open with:",
    format_item = function(key)
      local h = registry.get(key)
      return h and string.format("%-14s  %s", h.key, h.desc) or key
    end,
  }, function(choice)
    if not choice then return end

    local ctx = context.resolve(scope, choice, signals)
    if not ctx then
      require("lib.nvim.notify").create("[open]").warn("Nothing to open")
      return
    end

    registry.dispatch(choice, ctx)
  end)
end

return M
