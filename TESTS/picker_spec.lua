-- Test code: when something here comes back nil this file must crash and
-- name it, not silently pass.
---@diagnostic disable: need-check-nil, duplicate-set-field
-- TESTS/picker_spec.lua — open.picker.select()'s own guard branches.
-- features_spec.lua already drives this end to end through
-- require("open").open(nil, nil) with picker.enabled=true; this spec calls
-- M.select() directly to cover its cancel and nothing-to-open paths, which
-- that end-to-end case never takes.

return function(H)
  require("open").setup({})
  local picker = require("open.picker")
  local registry = require("open.registry")

  local function with_stubs(fn)
    local orig_select = vim.ui.select
    local orig_dispatch = registry.dispatch
    local ok, err = pcall(fn)
    vim.ui.select = orig_select
    registry.dispatch = orig_dispatch
    if not ok then error(err, 0) end
  end

  -- select(): a cancelled prompt (choice == nil) never dispatches -----------
  with_stubs(function()
    local dispatched = false
    registry.dispatch = function()
      dispatched = true
    end
    vim.ui.select = function(items, _opts, on_choice)
      on_choice(nil)
    end

    picker.select({ "filemanager", "browser" }, nil, {})
    H.falsy(dispatched, "a cancelled selection does not dispatch anything")
  end)

  -- select(): a choice that resolves to nothing warns instead of dispatching -
  with_stubs(function()
    local dispatched = false
    registry.dispatch = function()
      dispatched = true
    end
    vim.ui.select = function(items, _opts, on_choice)
      on_choice(items[1])
    end
    local warned
    local orig_notify = vim.notify
    vim.notify = function(msg)
      warned = msg
    end

    -- Empty signals + no scope + a non-path-oriented target resolves to nil.
    picker.select({ "browser" }, nil, {})

    vim.notify = orig_notify
    H.falsy(dispatched, "nothing-to-open is not dispatched")
    H.contains(warned, "Nothing to open", "the picker warns when the choice resolves to nothing")
  end)

  -- select(): a real choice resolves and dispatches --------------------------
  with_stubs(function()
    local seen_target, seen_ctx
    registry.dispatch = function(target, ctx)
      seen_target, seen_ctx = target, ctx
    end
    vim.ui.select = function(items, _opts, on_choice)
      on_choice(items[1])
    end

    picker.select({ "browser" }, nil, { cword = "https://example.com" })

    H.eq(seen_target, "browser", "the chosen candidate is dispatched")
    H.eq(
      seen_ctx.text,
      "https://example.com",
      "the dispatched context resolves from the given signals"
    )
  end)

  -- select(): format_item falls back to the raw key for an unknown handler --
  with_stubs(function()
    local captured_opts
    vim.ui.select = function(items, opts, on_choice)
      captured_opts = opts
      on_choice(nil)
    end
    picker.select({ "zzpicker_unregistered" }, nil, {})
    H.eq(
      captured_opts.format_item("zzpicker_unregistered"),
      "zzpicker_unregistered",
      "format_item falls back to the bare key when the handler is not registered"
    )
  end)

  -- select(): falls back to vim.ui.select directly when ui.nvim (ui.kit) is
  -- not installed, instead of throwing (LUA-01) ------------------------------
  with_stubs(function()
    local orig_loaded = package.loaded["ui.kit"]
    local orig_preload = package.preload["ui.kit"]
    package.loaded["ui.kit"] = nil
    package.preload["ui.kit"] = function()
      error("simulated: ui.nvim not installed")
    end

    local used_vim_ui_select = false
    vim.ui.select = function(items, _opts, on_choice)
      used_vim_ui_select = true
      on_choice(items[1])
    end
    local dispatched_target
    registry.dispatch = function(target)
      dispatched_target = target
    end

    local ok, err = pcall(picker.select, { "browser" }, nil, { cword = "https://example.com" })

    package.preload["ui.kit"] = orig_preload
    package.loaded["ui.kit"] = orig_loaded

    H.ok(ok, "select() does not throw when ui.kit is unavailable: " .. tostring(err))
    H.ok(used_vim_ui_select, "falls back to vim.ui.select directly")
    H.eq(dispatched_target, "browser", "the fallback path still dispatches the chosen handler")
  end)
end
