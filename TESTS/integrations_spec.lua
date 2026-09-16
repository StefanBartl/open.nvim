-- Test code: when something here comes back nil this file must crash and
-- name it, not silently pass.
---@diagnostic disable: need-check-nil, duplicate-set-field
-- TESTS/integrations_spec.lua — the opt-in integrations: telescope (extension
-- shape only; features_spec.lua already covers the picker()-without-
-- telescope guard), urlview, and menu. None of these are loaded by
-- open.setup() itself.

return function(H)
  require("open").setup({})

  -- open.integrations.urlview -----------------------------------------------
  do
    local urlview_integration = require("open.integrations.urlview")

    -- register_action(): fails cleanly when urlview.nvim is not installed ----
    local orig_urlview_actions = package.loaded["urlview.actions"]
    package.loaded["urlview.actions"] = nil
    H.falsy(urlview_integration.register_action(), "register_action() fails without urlview.nvim")

    -- register_action(): wires "open_in_browser" into urlview.actions --------
    local actions = {}
    package.loaded["urlview.actions"] = actions
    H.ok(
      urlview_integration.register_action(),
      "register_action() succeeds once urlview.actions exists"
    )
    H.eq(type(actions.open_in_browser), "function", "open_in_browser action installed")

    -- The installed action dispatches through the registry, sanitizing the URL.
    local registry = require("open.registry")
    local orig_dispatch = registry.dispatch
    local seen_target, seen_ctx
    registry.dispatch = function(target, ctx)
      seen_target, seen_ctx = target, ctx
    end

    actions.open_in_browser("example.com/path")
    H.eq(seen_target, "browser", "urlview action dispatches to the configured default_browser")
    H.eq(seen_ctx.text, "http://example.com/path", "a scheme-less match gains http://")
    H.ok(seen_ctx.is_url, "the dispatched context is flagged is_url")

    actions.open_in_browser("https://already-scheme.dev")
    H.eq(seen_ctx.text, "https://already-scheme.dev", "an existing scheme is left untouched")

    -- An empty/blank match warns instead of dispatching a bogus URL.
    seen_target = nil
    local orig_notify = vim.notify
    local warned = false
    vim.notify = function()
      warned = true
    end
    actions.open_in_browser("   ")
    vim.notify = orig_notify
    H.falsy(seen_target, "a blank match is never dispatched")
    H.ok(warned, "a blank match warns")

    registry.dispatch = orig_dispatch
    package.loaded["urlview.actions"] = orig_urlview_actions
  end

  -- open.integrations.urlview: setup() gating --------------------------------
  do
    local urlview_integration = require("open.integrations.urlview")

    -- setup(false) never even looks for urlview.nvim's own setup().
    local orig_urlview = package.loaded["urlview"]
    package.loaded["urlview.actions"] = {}
    local called = false
    package.loaded["urlview"] = {
      setup = function()
        called = true
      end,
    }
    urlview_integration.setup(false)
    H.falsy(called, "setup(false) registers the action but never calls urlview.setup()")

    urlview_integration.setup({})
    H.ok(called, "setup({}) (or setup()) does call urlview.setup()")

    package.loaded["urlview"] = orig_urlview
    package.loaded["urlview.actions"] = nil
  end

  -- open.integrations.menu ----------------------------------------------------
  do
    local menu_integration = require("open.integrations.menu")

    -- menu.enable = false → always empty, regardless of context ---------------
    require("open").setup({ menu = { enable = false } })
    H.eq(#menu_integration.items(), 0, "menu.enable=false yields no entries")
    H.falsy(menu_integration.submenu(), "submenu() is nil when items() is empty")

    -- Enabled: the "List Links Here" entry is always present -------------------
    require("open").setup({ menu = { enable = true } })
    local items = menu_integration.items()
    H.ok(#items > 0, "menu.enable=true yields at least the always-on entry")

    local found_list_links = false
    for _, item in ipairs(items) do
      if item.name and item.name:find("List Links Here", 1, true) then found_list_links = true end
    end
    H.ok(found_list_links, "the 'List Links Here' entry is always offered")

    -- Browser entry only appears for a URL-shaped context ----------------------
    H.scratch({ "https://example.com" })
    vim.fn.setpos(".", { 0, 1, 1, 0 })
    local url_items = menu_integration.items()
    local browser_names = {}
    for _, item in ipairs(url_items) do
      if item.name then browser_names[item.name] = true end
    end
    local has_browser_entry = false
    for name in pairs(browser_names) do
      if name:find("Open in Browser", 1, true) then has_browser_entry = true end
    end
    H.ok(has_browser_entry, "a URL under the cursor surfaces the 'Open in Browser' entry")

    -- submenu(): wraps items() as one nested entry -----------------------------
    local sub = menu_integration.submenu()
    H.ok(sub, "submenu() returns a wrapper when there are items")
    H.eq(type(sub.items), "table", "submenu()'s wrapper carries the item list")

    require("open").setup({})
  end
end
