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

  -- keymaps -------------------------------------------------------------
  do
    require("open").setup({
      keymaps = {
        open_default = "zzootest",
        open_browser = "zzobtest",
        open_manager = "zzoftest",
        bogus_name   = "zzoxtest",
      },
    })

    local function mapped_rhs(lhs)
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == lhs then return m.rhs end
      end
      return nil
    end

    H.eq(mapped_rhs("zzootest"), "<Cmd>Open<CR>", "open_default keymap maps to :Open")
    H.eq(mapped_rhs("zzobtest"), "<Cmd>Open browser<CR>", "open_browser keymap maps to :Open browser")
    H.eq(mapped_rhs("zzoftest"), "<Cmd>Open filemanager<CR>", "open_manager keymap maps to :Open filemanager")
    H.falsy(mapped_rhs("zzoxtest"), "unknown keymaps.* name registers nothing")

    vim.keymap.del("n", "zzootest")
    vim.keymap.del("n", "zzobtest")
    vim.keymap.del("n", "zzoftest")
  end

  -- brave / opera browser handlers -----------------------------------------
  do
    require("open").setup({})
    local registry = require("open.registry")

    local brave = registry.get("brave")
    H.ok(brave, "brave handler registered")
    H.eq(brave.desc, "Open in Brave", "brave handler desc")

    local opera = registry.get("opera")
    H.ok(opera, "opera handler registered")
    H.eq(opera.desc, "Open in Opera", "opera handler desc")
  end

  -- filemanager reveal option ----------------------------------------------
  do
    require("open").setup({ filemanager = { reveal = false } })
    H.eq(require("open.config").get().filemanager.reveal, false, "filemanager.reveal is configurable")

    require("open").setup({})
    H.eq(require("open.config").get().filemanager.reveal, true, "filemanager.reveal defaults to true")

    H.tmpdir(function(dir)
      local file = dir .. "/reveal_test.txt"
      H.write(file, "x")

      local filemanager = require("open.handlers.filemanager")
      local registered
      filemanager.register_all(function(h) registered = h return true end)

      local util = require("open.util")
      local orig_run_detached = util.run_detached
      local seen_cmd

      util.run_detached = function(cmd) seen_cmd = cmd return true end

      require("open").setup({ filemanager = { reveal = true } })
      registered.run({ text = file, is_url = false, is_path = true })
      local reveal_cmd = table.concat(seen_cmd, " ")

      require("open").setup({ filemanager = { reveal = false } })
      registered.run({ text = file, is_url = false, is_path = true })
      local navigate_cmd = table.concat(seen_cmd, " ")

      util.run_detached = orig_run_detached

      H.ok(reveal_cmd ~= navigate_cmd,
        "filemanager.reveal=true and reveal=false build different commands for a file target")
    end)
  end

  -- debug mode --------------------------------------------------------------
  do
    require("open").setup({ debug = true })
    H.ok(require("open.config").is_debug(), "debug=true is reflected by config.is_debug()")

    local seen_any = false
    local orig_create = require("lib.nvim.notify").create
    require("lib.nvim.notify").create = function(tag)
      local inst = orig_create(tag)
      local orig_info = inst.info
      inst.info = function(...)
        seen_any = true
        return orig_info(...)
      end
      return inst
    end

    local context = require("open.context")
    context.gather()

    require("lib.nvim.notify").create = orig_create
    H.ok(seen_any, "debug=true causes context.gather() to emit an info log")

    require("open").setup({ debug = false })
    H.falsy(require("open.config").is_debug(), "debug defaults to false")
  end

  -- picker integration --------------------------------------------------------
  do
    local context = require("open.context")

    H.eq(#context.candidate_targets({ tree_path = "/x" }), 1,
      "a tree node has exactly one candidate target")

    local url_candidates = context.candidate_targets({ cword = "https://example.com" })
    H.ok(#url_candidates > 1, "a URL-like context has more than one candidate target")

    local path_candidates = context.candidate_targets({ cfile_path = "/tmp/x" })
    H.ok(#path_candidates > 1, "an existing-path context has more than one candidate target")

    -- picker.enabled = false (default): no picker prompt, dispatch happens
    -- exactly as before.
    do
      require("open").setup({})
      local registry = require("open.registry")
      local orig_dispatch = registry.dispatch
      local orig_select = vim.ui.select
      local dispatched, prompted = nil, false

      registry.dispatch = function(target) dispatched = target end
      vim.ui.select = function(...) prompted = true end

      require("open").open("filemanager", "path=/tmp")

      registry.dispatch = orig_dispatch
      vim.ui.select = orig_select

      H.eq(dispatched, "filemanager", "explicit target still dispatches directly")
      H.falsy(prompted, "vim.ui.select is not invoked when picker.enabled is false")
    end

    -- picker.enabled = true + ambiguous context + no explicit target: prompt.
    do
      require("open").setup({ picker = { enabled = true } })
      local registry = require("open.registry")
      local orig_dispatch = registry.dispatch
      local orig_select = vim.ui.select
      local dispatched, seen_items = nil, nil

      registry.dispatch = function(target) dispatched = target end
      vim.ui.select = function(items, _opts, on_choice)
        seen_items = items
        on_choice(items[1])
      end

      H.scratch({ "https://example.com" })
      vim.fn.setpos(".", { 0, 1, 1, 0 })
      require("open").open(nil, nil)

      registry.dispatch = orig_dispatch
      vim.ui.select = orig_select

      H.ok(seen_items and #seen_items > 1, "picker prompts with multiple candidates for a URL context")
      H.ok(dispatched, "the chosen candidate is dispatched")

      require("open").setup({ picker = { enabled = false } })
    end
  end

  -- context cache -------------------------------------------------------------
  do
    local context = require("open.context")
    local orig_bufname = vim.api.nvim_buf_get_name
    local calls = 0
    vim.api.nvim_buf_get_name = function(...)
      calls = calls + 1
      return orig_bufname(...)
    end

    context.with_cache(function()
      context.gather()
      context.gather()
      context.gather()
    end)
    H.eq(calls, 1, "gather() only reads editor state once inside with_cache")

    calls = 0
    context.gather()
    context.gather()
    H.eq(calls, 2, "gather() is not cached outside with_cache")

    -- Nested with_cache: the inner call must not clear the outer's cache.
    calls = 0
    context.with_cache(function()
      context.gather()
      context.with_cache(function()
        context.gather()
      end)
      context.gather()
    end)
    H.eq(calls, 1, "nested with_cache reuses the outer cache")

    vim.api.nvim_buf_get_name = orig_bufname
  end

  -- scope = "git" -----------------------------------------------------------
  do
    require("open").setup({})
    local context = require("open.context")

    -- The test suite itself runs inside a git worktree, so "git" must
    -- resolve to some existing directory containing a .git entry point.
    local ctx = context.resolve("git", "filemanager", {})
    H.ok(ctx, "git scope resolves to a context inside a git repo")
    if ctx then
      H.ok(ctx.is_path, "git scope resolves to an existing path")
      H.falsy(ctx.is_url, "git scope is not a URL")
    end
  end
end
