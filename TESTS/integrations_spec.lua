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

  -- open.integrations.urlview: default_picker only reads package.loaded,
  -- never require()s telescope/fzf-lua just to probe for them (LUA-92) ------
  do
    local urlview_integration = require("open.integrations.urlview")
    package.loaded["urlview.actions"] = {}
    local captured_opts
    local orig_urlview = package.loaded["urlview"]
    package.loaded["urlview"] = {
      setup = function(o)
        captured_opts = o
      end,
    }

    local orig_telescope = package.loaded["telescope"]
    local orig_fzf = package.loaded["fzf-lua"]
    package.loaded["telescope"] = nil
    package.loaded["fzf-lua"] = nil
    -- A preload stub that errors proves setup() never require()s telescope:
    -- if it did, this test would blow up instead of merely asserting.
    package.preload["telescope"] = function()
      error("setup() must not require() telescope just to probe for it")
    end

    urlview_integration.setup({})
    package.preload["telescope"] = nil
    H.falsy(captured_opts.default_picker, "neither picker loaded -> default_picker left unset")

    package.loaded["telescope"] = { some = "module" }
    urlview_integration.setup({})
    H.eq(captured_opts.default_picker, "telescope", "an already-loaded telescope is picked up")

    package.loaded["telescope"] = orig_telescope
    package.loaded["fzf-lua"] = orig_fzf
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

    -- enabled(): what ui.nvim's ui.menu asks first ------------------------------
    require("open").setup({})
    H.eq(menu_integration.enabled(), true, "enabled() is true by default")
    require("open").setup({ integrations = { ui_menu = false } })
    H.eq(menu_integration.enabled(), false, "integrations.ui_menu=false -> enabled() false")
    H.ok(#menu_integration.items() > 0, "ui_menu=false leaves items() to other hosts")
    require("open").setup({ menu = { enable = false } })
    H.eq(menu_integration.enabled(), false, "menu.enable=false -> enabled() false")

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

    -- Without ui.nvim (ui.contextmenu), items()/submenu() degrade to no
    -- entries instead of throwing (LUA-01) -------------------------------
    local orig_loaded = package.loaded["ui.contextmenu"]
    local orig_preload = package.preload["ui.contextmenu"]
    package.loaded["ui.contextmenu"] = nil
    package.preload["ui.contextmenu"] = function()
      error("simulated: ui.nvim not installed")
    end

    local ok_items, items_or_err = pcall(menu_integration.items)
    local ok_submenu, submenu_or_err = pcall(menu_integration.submenu)

    package.preload["ui.contextmenu"] = orig_preload
    package.loaded["ui.contextmenu"] = orig_loaded

    H.ok(ok_items, "items() does not throw when ui.nvim is unavailable: " .. tostring(items_or_err))
    H.eq(#items_or_err, 0, "items() returns no entries when ui.nvim is unavailable")
    H.ok(
      ok_submenu,
      "submenu() does not throw when ui.nvim is unavailable: " .. tostring(submenu_or_err)
    )
    H.falsy(submenu_or_err, "submenu() returns nil when ui.nvim is unavailable")

    require("open").setup({})
  end
end
