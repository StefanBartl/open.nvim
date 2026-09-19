---@module 'open.picker'
---@brief Opt-in handler-choice picker for ambiguous no-target invocations.
---@description
--- Used by both `open.open()` and `:Open` when `cfg.picker.enabled == true`
--- and `open.context.candidate_targets()` returns more than one candidate
--- for the current context. When ui.nvim is installed, routes through
--- `ui.kit.select` with `respect_override = true`: any `vim.ui.select`
--- override (telescope-ui-select, fzf-lua, dressing.nvim) is still picked up
--- automatically, but kit's own themed chooser is used when nothing has
--- overridden it, instead of the built-in `vim.ui.select`. Without ui.nvim,
--- falls back directly to `vim.ui.select` (still honoring any override) —
--- ui.nvim degrades to nothing when absent, same as every other optional
--- dependency in docs/installation.md.

local M = {}

---Prompt the user to choose a handler among `candidates`, then dispatch it.
---@param candidates string[]        Handler keys to choose from.
---@param scope      string|nil      Scope token to resolve against the choice.
---@param signals    OpenNvim.Signals  Pre-gathered signals (not re-read).
function M.select(candidates, scope, signals)
  local context = require("open.context")
  local registry = require("open.registry")

  local function format_item(key)
    local h = registry.get(key)
    return h and string.format("%-14s  %s", h.key, h.desc) or key
  end

  local function on_select(choice)
    if not choice then return end

    local ctx = context.resolve(scope, choice, signals)
    if not ctx then
      require("lib.nvim.notify").create("[open]").warn("Nothing to open")
      return
    end

    registry.dispatch(choice, ctx)
  end

  local ok_kit, kit = pcall(require, "ui.kit")
  if ok_kit then
    kit.select({
      items = candidates,
      title = "Open with:",
      respect_override = true,
      format_item = format_item,
      on_select = on_select,
    })
  else
    vim.ui.select(candidates, { prompt = "Open with:", format_item = format_item }, on_select)
  end
end

return M
