-- Test code: when something here comes back nil this file must crash and
-- name it, not silently pass.
---@diagnostic disable: need-check-nil, duplicate-set-field
-- TESTS/registry_spec.lua — open.registry: validation, lookup, dispatch.
--
-- Stubs the global vim.notify for the length of a case to assert on the
-- message registry.lua's own notify instance produces — the instance is
-- created once at module load, but every one of its methods resolves
-- vim.notify freshly on each call, so overriding the global still reaches it.

return function(H)
  local registry = require("open.registry")

  local function capture_notify(fn)
    local orig = vim.notify
    local messages = {}
    vim.notify = function(msg, level)
      messages[#messages + 1] = { msg = msg, level = level }
    end
    local ok, err = pcall(fn)
    vim.notify = orig
    if not ok then error(err, 0) end
    return messages
  end

  -- register(): validation ---------------------------------------------------
  do
    local msgs = capture_notify(function()
      H.falsy(registry.register("not a table"), "a non-table handler is rejected")
    end)
    H.contains(msgs[1].msg, "must be a table", "rejection reports why")
  end

  do
    local msgs = capture_notify(function()
      H.falsy(registry.register({ run = function() end }), "a handler without a key is rejected")
    end)
    H.contains(msgs[1].msg, "key", "rejection names the missing field")
  end

  do
    H.falsy(registry.register({ key = "", run = function() end }), "an empty key is rejected")
  end

  do
    local msgs = capture_notify(function()
      H.falsy(registry.register({ key = "zzreg_norun" }), "a handler without run() is rejected")
    end)
    H.contains(msgs[1].msg, "run", "rejection names the missing run field")
  end

  -- register(): a minimal valid handler gets a default description ----------
  do
    H.ok(
      registry.register({ key = "zzreg_minimal", run = function() end }),
      "minimal handler accepted"
    )
    H.eq(registry.get("zzreg_minimal").desc, "(no description)", "a missing desc gets a fallback")
  end

  -- register(): overwriting an existing key warns but still succeeds --------
  do
    local second_ran = false
    local msgs = capture_notify(function()
      H.ok(
        registry.register({
          key = "zzreg_minimal",
          desc = "second",
          run = function()
            second_ran = true
          end,
        }),
        "re-registering the same key still succeeds"
      )
    end)
    H.contains(msgs[1].msg, "overwriting", "a duplicate key warns")
    H.eq(registry.get("zzreg_minimal").desc, "second", "the later registration wins")
    registry.dispatch("zzreg_minimal", {})
    H.ok(second_ran, "dispatch reaches the surviving (second) registration")
  end

  -- get() ----------------------------------------------------------------------
  do
    H.falsy(registry.get(123), "get() with a non-string key returns nil instead of erroring")
    H.falsy(registry.get("zzreg_does_not_exist"), "get() on an unknown key returns nil")
  end

  -- list_keys() / list(): sorted, and reflect real registrations -------------
  do
    registry.register({ key = "zzreg_b", run = function() end })
    registry.register({ key = "zzreg_a", run = function() end })

    local keys = registry.list_keys()
    local ia, ib
    for i, k in ipairs(keys) do
      if k == "zzreg_a" then ia = i end
      if k == "zzreg_b" then ib = i end
    end
    H.ok(ia and ib and ia < ib, "list_keys() is sorted")

    local list = registry.list()
    local found = false
    for _, h in ipairs(list) do
      if h.key == "zzreg_a" then found = true end
    end
    H.ok(found, "list() includes a freshly registered handler")

    -- list() is sorted by key the same way list_keys() is.
    local prev
    local sorted = true
    for _, h in ipairs(list) do
      if prev and h.key < prev then sorted = false end
      prev = h.key
    end
    H.ok(sorted, "list() is sorted by key")
  end

  -- dispatch(): unknown target reports the available keys --------------------
  do
    local msgs = capture_notify(function()
      registry.dispatch("zzreg_totally_unknown", { text = "x" })
    end)
    H.contains(msgs[1].msg, "Unknown target", "dispatching an unknown key warns")
    H.contains(msgs[1].msg, "zzreg_a", "the message lists an available key")
  end

  -- dispatch(): a handler that errors is caught, not propagated --------------
  do
    registry.register({
      key = "zzreg_throws",
      run = function()
        error("kaboom")
      end,
    })
    local msgs = capture_notify(function()
      -- Must not raise past dispatch() — a broken handler must not take
      -- down the caller (a user command, a keymap, another handler).
      registry.dispatch("zzreg_throws", { text = "x" })
    end)
    H.contains(msgs[1].msg, "kaboom", "the caught error is reported")
    H.contains(msgs[1].msg, "zzreg_throws", "the report names the failing handler")
  end

  -- dispatch(): debug=true logs the dispatch parameters -----------------------
  do
    require("open").setup({ debug = true })
    registry.register({
      key = "zzreg_debug",
      run = function()
        return true
      end,
    })
    local msgs = capture_notify(function()
      registry.dispatch("zzreg_debug", { text = "hello", is_url = false, is_path = true })
    end)
    local found = false
    for _, m in ipairs(msgs) do
      if m.msg:find("zzreg_debug", 1, true) and m.msg:find("hello", 1, true) then found = true end
    end
    H.ok(found, "debug=true logs target and context text before dispatching")
    require("open").setup({ debug = false })
  end
end
