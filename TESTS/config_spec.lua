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

  -- ERR-51 / ERR-54: mutating what config.get() returns must not poison a
  -- later read, or the module-level DEFAULTS table, for the rest of the
  -- session (config.get() used to hand out DEFAULTS' own sub-tables by
  -- reference after a bare setup({})) --------------------------------------
  do
    local DEFAULTS = require("open.config.DEFAULTS")
    config.setup({})
    local got = config.get()
    got.viewer.sort = "mutated"
    got.filemanager.reveal = "mutated"

    H.eq(
      config.get().viewer.sort,
      "none",
      "a later config.get() is unaffected by an earlier mutation"
    )
    H.eq(DEFAULTS.viewer.sort, "none", "DEFAULTS itself was never touched")
    H.eq(DEFAULTS.filemanager.reveal, true, "DEFAULTS itself was never touched (nested boolean)")

    config.setup({})
    H.eq(config.get().viewer.sort, "none", "setup({}) still restores the real default afterwards")
  end

  -- ERR-22: a wrong-typed value degrades to its default instead of aborting
  -- setup() -------------------------------------------------------------
  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ handlers = "browser" })
    H.ok(
      vim.tbl_contains(config.get().handlers, "browser"),
      "handlers fell back to its default list"
    )
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'handlers' must be a list of strings, got string"
    )
    config.setup({})
  end

  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ command = 42 })
    H.eq(config.get().command, "Open", "command fell back to its default")
    H.contains(table.concat(config.issues(), "\n"), "option 'command' must be a string, got number")
    config.setup({})
  end

  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ custom_handlers = "not-a-list" })
    H.eq(#config.get().custom_handlers, 0, "custom_handlers fell back to its default empty list")
    config.setup({})
  end

  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ office_open = { extensions = "docx" } })
    H.eq(
      #config.get().office_open.extensions,
      6,
      "office_open.extensions fell back to its default list"
    )
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'office_open.extensions' must be a list of strings, got string"
    )
    config.setup({})
  end

  -- ERR-22: a list-shaped value with a wrong-typed ELEMENT also degrades,
  -- not just a wrong-shaped whole value. `handlers` used to reach
  -- `open.init`'s `"Unknown handler module key: '" .. key .. "'"` and
  -- `office_open.extensions` used to reach `office_open`'s
  -- `"*." .. ext` pattern-builder with the offending element still in
  -- place, and Lua's `..` throws on a non-string/non-number operand --
  -- crashing straight out of setup() instead of degrading. -----------------
  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ handlers = { true, "browser" } })
    H.ok(
      vim.tbl_contains(config.get().handlers, "browser"),
      "handlers fell back to its default list on a non-string element"
    )
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'handlers' must be a list of strings, got table"
    )
    config.setup({})
  end

  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ office_open = { extensions = { 42, "docx" } } })
    H.eq(
      #config.get().office_open.extensions,
      6,
      "office_open.extensions fell back to its default list on a non-string element"
    )
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'office_open.extensions' must be a list of strings, got table"
    )
    config.setup({})
  end

  -- ERR-22: filemanager.command ("a string ... or an argv list") degrades on
  -- any other shape, including a boolean/number and an EMPTY list -- an
  -- empty argv is not "no override" the way an empty string already is one
  -- layer down in lib.nvim's reveal_in_fm, and used to reach run_detached as
  -- a 0-element argv (shifting the resolved path into argv[1] and crashing
  -- the dispatch with a raw "E475: ... is not executable" the next time the
  -- handler ran) instead of falling back to nil (platform auto-detect). ----
  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ filemanager = { command = true } })
    H.eq(config.get().filemanager.command, nil, "filemanager.command (boolean) fell back to nil")
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'filemanager.command' must be a string or non-empty list of strings, got boolean"
    )
    config.setup({})
  end

  do
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ filemanager = { command = {} } })
    H.eq(config.get().filemanager.command, nil, "filemanager.command (empty list) fell back to nil")
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'filemanager.command' must be a string or non-empty list of strings, got table"
    )
    config.setup({})
  end

  do
    -- A list with a blank command name is just as unusable as an empty
    -- list -- it must not slip past cmdspec validation into run_detached.
    ---@diagnostic disable-next-line: assign-type-mismatch
    config.setup({ filemanager = { command = { "" } } })
    H.eq(
      config.get().filemanager.command,
      nil,
      "filemanager.command (blank element) fell back to nil"
    )
    H.contains(
      table.concat(config.issues(), "\n"),
      "option 'filemanager.command' must be a string or non-empty list of strings, got table"
    )
    config.setup({})
  end

  do
    config.setup({ filemanager = { command = "thunar" } })
    H.eq(config.get().filemanager.command, "thunar", "a valid string command is kept as-is")
    H.eq(#config.issues(), 0, "a valid filemanager.command raises no issue")
    config.setup({})
  end

  do
    config.setup({ filemanager = { command = { "dolphin", "--select" } } })
    H.eq(
      table.concat(config.get().filemanager.command, ","),
      "dolphin,--select",
      "a valid argv-list command is kept as-is"
    )
    H.eq(#config.issues(), 0, "a valid filemanager.command raises no issue")
    config.setup({})
  end

  -- ERR-50: an unrecognized key is flagged with a did-you-mean hint, dropped
  -- rather than merged in, and the issue list is cleared by a later
  -- well-formed setup() ------------------------------------------------
  do
    config.setup({ hanlders = { "browser" } })
    H.contains(
      table.concat(config.issues(), "\n"),
      "unknown option 'hanlders' (did you mean 'handlers'?)"
    )
    H.eq(config.get().hanlders, nil, "the unrecognized key was not merged in")

    config.setup({})
    H.eq(#config.issues(), 0, "a later well-formed setup() clears the issue list")
  end
end
