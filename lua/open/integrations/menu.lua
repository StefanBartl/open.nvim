---@module 'open.integrations.menu'
---@brief Context-aware menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- open.nvim does not depend on a menu plugin. It *provides* a list of
--- entries in the shape nvzone/menu expects, built with
--- `lib.nvim.contextmenu`'s helpers, and a host — typically the user's own
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

local contextmenu = require("lib.nvim.contextmenu")

local M = {}

--- Build the open.nvim menu entries for the current cursor/buffer context.
--- Returns an empty list when the integration is disabled, or nothing in the
--- current context resolves to anything, so a host can safely
--- `vim.list_extend` it unconditionally.
---@param _opts? table  reserved for future use
---@return table[]  nvzone/menu entry list (possibly empty)
function M.items(_opts)
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

    contextmenu.group(
      out,
      contextmenu.entry(default_ctx ~= nil, "  Open", function()
        require("open").open(default_target)
      end, keymaps.open_default)
    )

    contextmenu.group(
      out,
      contextmenu.entry(browser_ctx ~= nil and browser_ctx.is_url, "  Open in Browser", function()
        require("open").open(cfg.default_browser)
      end, keymaps.open_browser),
      contextmenu.entry(fm_ctx ~= nil and fm_ctx.is_path, "  Reveal in File Manager", function()
        require("open").open(cfg.default_filemanager)
      end, keymaps.open_manager),
      contextmenu.entry(term_ctx ~= nil and term_ctx.is_path, "  Open in Terminal", function()
        require("open").open("terminal")
      end)
    )

    -- Always available: scans the current buffer for links regardless of
    -- what is under the cursor, so it does not need context.resolve at all.
    contextmenu.group(
      out,
      contextmenu.entry(true, "  List Links Here", function()
        require("open.viewer").run({ scope = "%" })
      end)
    )
  end)

  return out
end

--- Convenience: the open.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer an "Open ▸" fly-out instead of inline
--- entries. Returns nil when there is nothing to show.
---@param label? string  submenu label (default "  Open")
---@return table|nil
function M.submenu(label)
  return contextmenu.submenu(label or "  Open", M.items())
end

return M
