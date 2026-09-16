-- Test code: when something here comes back nil this file must crash and
-- name it, not silently pass.
---@diagnostic disable: need-check-nil, duplicate-set-field
-- TESTS/bindings_keymaps_spec.lua — open.bindings.keymaps: the registry-
-- driven `open_<key>` name space, the `open_manager` alias, and the
-- unknown-name warning. features_spec.lua already asserts the end result of
-- a few concrete lhs bindings through setup(); this spec is about the
-- generation logic that produces the accepted name set in the first place.

return function(H)
  require("open").setup({})
  local keymaps = require("open.bindings.keymaps")
  local registry = require("open.registry")

  local function capture_notify(fn)
    local orig = vim.notify
    local messages = {}
    vim.notify = function(msg)
      messages[#messages + 1] = msg
    end
    local ok, err = pcall(fn)
    vim.notify = orig
    if not ok then error(err, 0) end
    return messages
  end

  -- register(): cfg.keymaps not a table is a no-op, not an error -------------
  do
    local ok, ret = pcall(keymaps.register, { command = "Open" })
    H.ok(ok, "register() with no keymaps table does not error")
    H.falsy(ret, "register() returns nothing when cfg.keymaps is absent")
  end

  -- register(): every registered handler is reachable as open_<key> ---------
  do
    registry.register({ key = "zzkm_custom", desc = "custom", run = function() end })
    require("open").setup({ keymaps = { open_zzkm_custom = "zzkmlhs" } })

    local function mapped_rhs(lhs)
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == lhs then return m.rhs end
      end
      return nil
    end

    H.eq(
      mapped_rhs("zzkmlhs"),
      "<Cmd>Open zzkm_custom<CR>",
      "a freshly registered handler is reachable via open_<key> without any hardcoded list"
    )
    vim.keymap.del("n", "zzkmlhs")
    require("open").setup({})
  end

  -- register(): the bare :Open key is not shadowed by the "default" handler -
  do
    require("open").setup({ keymaps = { open_default = "zzkmdefault" } })
    local function mapped_rhs(lhs)
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == lhs then return m.rhs end
      end
      return nil
    end
    H.eq(mapped_rhs("zzkmdefault"), "<Cmd>Open<CR>", "open_default always means the bare :Open")
    vim.keymap.del("n", "zzkmdefault")
    require("open").setup({})
  end

  -- register(): an unrecognized keymaps name warns and names alternatives ---
  do
    local msgs = capture_notify(function()
      require("open").setup({ keymaps = { totally_bogus = "zzkmbogus" } })
    end)
    local found
    for _, m in ipairs(msgs) do
      if m:find("Unknown keymaps.totally_bogus", 1, true) then found = m end
    end
    H.ok(found, "an unknown keymaps.* name is reported")
    H.contains(found, "open_default", "the report names at least one accepted alternative")
    require("open").setup({})
  end

  -- register(): open_manager is the historical alias for filemanager --------
  do
    require("open").setup({ keymaps = { open_manager = "zzkmmgr" } })
    local function mapped_rhs(lhs)
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == lhs then return m.rhs end
      end
      return nil
    end
    H.eq(mapped_rhs("zzkmmgr"), "<Cmd>Open filemanager<CR>", "open_manager aliases filemanager")
    vim.keymap.del("n", "zzkmmgr")
    require("open").setup({})
  end
end
