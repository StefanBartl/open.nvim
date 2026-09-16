-- TESTS/config_spec.lua — config/init.lua's setup() merge semantics.
--
-- features_spec.lua already exercises config.get() through several
-- setup({...}) round trips (filemanager.reveal, debug); this spec is about
-- the merge machinery itself: the builtin/user keyword split that cannot go
-- through tbl_deep_extend (function values), and that DEFAULTS survives
-- being merged into over and over without drifting.

return function(H)
  local config = require("open.config")

  -- setup({}) yields exactly config/DEFAULTS.lua's shape --------------------
  do
    config.setup({})
    local cfg = config.get()
    H.eq(cfg.command, "Open", "command defaults to 'Open'")
    H.eq(cfg.default_filemanager, "filemanager", "default_filemanager default")
    H.eq(cfg.default_browser, "browser", "default_browser default")
    H.ok(vim.tbl_contains(cfg.handlers, "browser"), "default handlers list includes browser")
    H.eq(cfg.builtin_keywords, true, "builtin_keywords defaults to true")
    H.falsy(config.is_debug(), "debug defaults to false")
  end

  -- builtin_keywords = true (default): built-ins are present ---------------
  do
    config.setup({})
    local kw = config.get().keywords
    H.eq(type(kw.zshrc), "string", "a built-in keyword is present by default")
  end

  -- builtin_keywords = false: no built-ins survive --------------------------
  do
    config.setup({ builtin_keywords = false })
    local kw = config.get().keywords
    H.falsy(kw.zshrc, "builtin_keywords=false drops the built-in table entirely")
    H.eq(config.get().builtin_keywords, false, "builtin_keywords itself is reported back")

    config.setup({})
    H.eq(config.get().builtin_keywords, true, "a later setup({}) restores builtin_keywords")
  end

  -- user keywords override built-ins of the same name -----------------------
  do
    config.setup({ keywords = { zshrc = "/custom/zshrc" } })
    H.eq(
      config.get().keywords.zshrc,
      "/custom/zshrc",
      "user keyword wins over the built-in default"
    )
    -- Every other built-in is still there — this is an override, not a reset.
    H.eq(
      type(config.get().keywords.vimrc),
      "string",
      "unrelated built-ins survive a partial override"
    )
    config.setup({})
  end

  -- a function-valued keyword survives the merge untouched ------------------
  -- (tbl_deep_extend cannot merge functions; the keyword table is built by
  -- hand in setup() precisely so a resolver function is never mangled.)
  do
    local sentinel = function()
      return "sentinel"
    end
    config.setup({ keywords = { my_kw = sentinel } })
    H.eq(config.get().keywords.my_kw, sentinel, "function-valued keyword kept as the same function")
    H.eq(config.get().keywords.my_kw(), "sentinel", "the kept function is still callable")
    config.setup({})
  end

  -- builtin_keywords = false + a user keyword: only the user's survives -----
  do
    config.setup({ builtin_keywords = false, keywords = { only_mine = "/x" } })
    local kw = config.get().keywords
    H.eq(kw.only_mine, "/x", "user keyword present")
    H.falsy(kw.zshrc, "built-ins absent")
    local count = 0
    for _ in pairs(kw) do
      count = count + 1
    end
    H.eq(count, 1, "no built-in leaked in alongside the user's own keyword")
    config.setup({})
  end

  -- custom_handlers and other plain fields deep-merge normally --------------
  do
    config.setup({ custom_handlers = { { key = "x", desc = "d", run = function() end } } })
    H.eq(#config.get().custom_handlers, 1, "custom_handlers passed through")
    config.setup({})
    H.eq(
      #config.get().custom_handlers,
      0,
      "a later setup({}) resets custom_handlers to the default empty list"
    )
  end

  -- nested config tables merge rather than replace wholesale ----------------
  do
    config.setup({ viewer = { sort = "alpha" } })
    local viewer = config.get().viewer
    H.eq(viewer.sort, "alpha", "the overridden field changed")
    H.eq(viewer.output, "picker", "an unrelated sibling field keeps its default")
    config.setup({})
  end

  -- repeated setup() calls do not corrupt config/DEFAULTS.lua ---------------
  do
    config.setup({ command = "Elsewhere", filemanager = { reveal = false } })
    config.setup({})
    H.eq(config.get().command, "Open", "command back to default after a bare setup({})")
    H.eq(
      config.get().filemanager.reveal,
      true,
      "nested default (filemanager.reveal) not corrupted by an earlier override"
    )
  end
end
