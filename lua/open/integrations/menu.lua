---@module 'open.integrations.menu'
---@brief Context-aware menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- open.nvim does not depend on a menu plugin. It *provides* a list of
--- entries in the shape nvzone/menu expects, built with
--- `ui.contextmenu`'s helpers, and a host — typically the user's own
--- RightMouse dispatcher — composes them into its own menu for the current
--- buffer, e.g.:
--- >
---   local items = require("open.integrations.menu").items()
---   -- prepend/append `items` to your own menu table, then menu.open(composed)
--- <
--- open.nvim is meant to be useful from *any* buffer — including a Neo-tree /
--- nvim-tree / netrw tree buffer, which `open.context` already resolves the
--- node under the cursor for — so entries self-gate against that same
--- resolution instead of always showing all of them regardless of what is
--- under the cursor: "Open in Browser" only appears when the resolved target
--- is actually a URL, "Reveal in File Manager" / "Open in Terminal" only
--- when it resolves to an existing path. Opt out entirely via
--- `config.menu.enable = false`.
---
--- The entry builders are ui.nvim's `ui.contextmenu` (`group`/`entry`/
--- `submenu`). ui.nvim degrades to nothing when absent, same as every other
--- optional dependency in docs/installation.md: `M.items()` returns an empty
--- list and `M.submenu()` returns nil, exactly as when the integration is
--- disabled or nothing in the context resolves to anything.

local M = {}

---@internal
---Lazily load ui.contextmenu. This module is itself opt-in (never required
---by `open.setup()`); without ui.nvim there is nothing to build entries
---with, not a hard error.
---@return table|nil
local function contextmenu()
  local ok, mod = pcall(require, "ui.contextmenu")
  return ok and mod or nil
end

--- Build the open.nvim menu entries for the current cursor/buffer context.
--- Returns an empty list when ui.nvim is not installed, the integration is
--- disabled, or nothing in the current context resolves to anything, so a
--- host can safely `vim.list_extend` it unconditionally.
---@param _opts? table  reserved for future use
---@return table[]  nvzone/menu entry list (possibly empty)
function M.items(_opts)
  local cm = contextmenu()
  if not cm then return {} end

  local cfg = require("open.config").get()
  local mcfg = cfg.menu or {}
  if mcfg.enable == false then return {} end

  local context = require("open.context")
  local keymaps = cfg.keymaps or {}
  local out = {}

  context.with_cache(function()
    local signals = context.gather()

    local default_target = context.default_target(signals)
    local default_ctx = context.resolve(nil, default_target, signals)
    local browser_ctx = context.resolve(nil, cfg.default_browser, signals)
    local fm_ctx = context.resolve(nil, cfg.default_filemanager, signals)
    local term_ctx = context.resolve(nil, "terminal", signals)

    cm.group(
      out,
      cm.entry(default_ctx ~= nil, "  Open", function()
        require("open").open(default_target)
      end, keymaps.open_default)
    )

    cm.group(
      out,
      cm.entry(browser_ctx ~= nil and browser_ctx.is_url, "  Open in Browser", function()
        require("open").open(cfg.default_browser)
      end, keymaps.open_browser),
      cm.entry(fm_ctx ~= nil and fm_ctx.is_path, "  Reveal in File Manager", function()
        require("open").open(cfg.default_filemanager)
      end, keymaps.open_manager),
      cm.entry(term_ctx ~= nil and term_ctx.is_path, "  Open in Terminal", function()
        require("open").open("terminal")
      end)
    )

    -- Always available: scans the current buffer for links regardless of
    -- what is under the cursor, so it does not need context.resolve at all.
    cm.group(
      out,
      cm.entry(true, "  List Links Here", function()
        require("open.viewer").run({ scope = "%" })
      end)
    )
  end)

  return out
end

--- Convenience: the open.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer an "Open ▸" fly-out instead of inline
--- entries. Returns nil when there is nothing to show (including when
--- ui.nvim is not installed).
---@param label? string  submenu label (default "  Open")
---@return table|nil
function M.submenu(label)
  local cm = contextmenu()
  if not cm then return nil end
  return cm.submenu(label or "  Open", M.items())
end

return M
