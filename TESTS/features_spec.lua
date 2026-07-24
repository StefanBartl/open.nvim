-- TESTS/features_spec.lua — roadmap features added after the initial
-- usrcmds/viewer suite: custom_handlers, git scope, filemanager reveal,
-- context cache.

return function(H)
  -- custom_handlers -----------------------------------------------------
  do
    local registry = require("open.registry")
    local seen = false

    require("open").setup({
      custom_handlers = {
        {
          key  = "test_custom_handler",
          desc = "test handler",
          run  = function() seen = true return true end,
        },
      },
    })

    local h = registry.get("test_custom_handler")
    H.ok(h, "custom_handlers entry registered in the registry")
    H.eq(h.desc, "test handler", "custom handler desc preserved")

    registry.dispatch("test_custom_handler", { text = "x", is_url = false, is_path = false })
    H.ok(seen, "custom handler's run() was invoked via dispatch")
  end

  -- terminal handler --------------------------------------------------------
  do
    H.tmpdir(function(dir)
      local terminal = require("open.handlers.terminal")
      local registered
      terminal.register_all(function(h) registered = h return true end)
      H.eq(registered.key, "terminal", "terminal handler registers under key 'terminal'")

      local win_count_before = #vim.api.nvim_list_wins()

      local ok = registered.run({ text = dir, is_url = false, is_path = true })
      H.ok(ok, "terminal handler run() succeeds for an existing directory")
      H.eq(vim.bo.buftype, "terminal", "terminal handler opens a :terminal buffer")

      local ok_url = registered.run({ text = "https://example.com", is_url = true, is_path = false })
      H.falsy(ok_url, "terminal handler rejects a URL context")

      vim.cmd("bwipeout!")
      if #vim.api.nvim_list_wins() > win_count_before then
        vim.cmd("close")
      end
    end)
  end
end
