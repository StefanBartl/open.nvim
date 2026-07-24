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
end
