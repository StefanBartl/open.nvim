-- TESTS/context_spec.lua — open.context: M.resolve()'s full branch matrix
-- and M.default_target(). features_spec.lua already covers "git", "cwd", and
-- a keyword resolver returning nil; this spec covers the remaining explicit
-- scope tokens, the PATH_TARGETS split, the no-arg fallback chain (using
-- hand-built signals tables, so none of it needs a real cursor/selection),
-- and the tree-buffer resolvers that had no coverage at all.

return function(H)
  require("open").setup({})
  local context = require("open.context")

  -- resolve(): "%" uses the buffer_path signal --------------------------------
  do
    local ctx = context.resolve("%", "browser", { buffer_path = "/tmp/buf.md" })
    H.eq(ctx.text, "/tmp/buf.md", "'%' resolves to signals.buffer_path")
  end

  -- resolve(): "cfile" uses the cfile signal, not cfile_path -----------------
  do
    local ctx = context.resolve("cfile", "browser", { cfile = "raw-cfile-text" })
    H.eq(ctx.text, "raw-cfile-text", "'cfile' resolves to the raw <cfile> text")
  end

  -- resolve(): "path=" is a literal, expanded path ---------------------------
  H.tmpdir(function(dir)
    local file = dir .. "/target.md"
    H.write(file, "x")
    local ctx = context.resolve("path=" .. file, "browser", {})
    H.contains(ctx.text:gsub("\\", "/"), "target.md", "path= resolves to the literal path")
    H.ok(ctx.is_path, "an existing path= target is flagged is_path")
  end)

  -- resolve(): no arg, target is path-oriented → cfile_path wins over buffer -
  do
    local ctx = context.resolve(nil, "split", {
      cfile_path = "/resolved/cfile.md",
      buffer_path = "/resolved/buffer.md",
    })
    H.eq(ctx.text, "/resolved/cfile.md", "a path-oriented target prefers cfile_path")
  end

  -- resolve(): no arg, path-oriented target, no cfile_path → buffer_path -----
  do
    local ctx = context.resolve(nil, "vsplit", { buffer_path = "/resolved/buffer.md" })
    H.eq(ctx.text, "/resolved/buffer.md", "falls back to buffer_path when cfile_path is absent")
  end

  -- resolve(): no arg, non-path target → visual > cword > buffer_path --------
  do
    local ctx = context.resolve(nil, "browser", {
      visual = "V",
      cword = "C",
      buffer_path = "B",
    })
    H.eq(ctx.text, "V", "visual selection wins over cword and buffer_path")

    local ctx2 = context.resolve(nil, "browser", { cword = "C", buffer_path = "B" })
    H.eq(ctx2.text, "C", "cword wins over buffer_path when there is no visual selection")

    local ctx3 = context.resolve(nil, "browser", { buffer_path = "B" })
    H.eq(ctx3.text, "B", "buffer_path is the last resort")
  end

  -- resolve(): a tree_path signal wins regardless of target, when arg is nil -
  do
    local ctx = context.resolve(nil, "browser", { tree_path = "/tree/node", cword = "ignored" })
    H.eq(ctx.text, "/tree/node", "tree_path overrides even a non-path-oriented target")
  end

  -- resolve(): nothing resolvable → nil, not an error -------------------------
  do
    local ctx = context.resolve(nil, "browser", {})
    H.falsy(ctx, "an empty signals table with no arg resolves to nil")
  end

  -- resolve(): is_url / is_path classification --------------------------------
  do
    local url_ctx = context.resolve(nil, "browser", { cword = "https://example.com" })
    H.ok(url_ctx.is_url, "an http(s) target is flagged is_url")
    H.falsy(url_ctx.is_path, "a URL is not also flagged is_path")

    local www_ctx = context.resolve(nil, "browser", { cword = "www.example.com" })
    H.ok(www_ctx.is_url, "a bare www. target is flagged is_url")
  end

  -- resolve(): a relative candidate falls back to the current buffer's dir --
  H.tmpdir(function(dir)
    H.write(dir .. "/sibling.md", "x")
    vim.cmd("edit " .. vim.fn.fnameescape(dir .. "/main.md"))
    local ctx = context.resolve("sibling.md", "browser", {})
    H.ok(ctx.is_path, "a relative target existing next to the current buffer resolves as a path")
    vim.cmd("bwipeout!")
  end)

  -- default_target(): tree_path always means the filemanager -----------------
  do
    H.eq(
      context.default_target({ tree_path = "/x" }),
      "filemanager",
      "a tree node defaults to the filemanager handler"
    )
  end

  -- default_target(): a URL-shaped probe defaults to the browser -------------
  do
    H.eq(
      context.default_target({ cword = "https://x.dev" }),
      "browser",
      "an http probe defaults to browser"
    )
    H.eq(
      context.default_target({ cfile = "www.x.dev" }),
      "browser",
      "a www probe defaults to browser"
    )
  end

  -- default_target(): anything else falls back to the filemanager ------------
  do
    H.eq(
      context.default_target({ buffer_path = "/some/file.lua" }),
      "filemanager",
      "a plain file path defaults to the filemanager"
    )
    H.eq(
      context.default_target({}),
      "filemanager",
      "no signals at all still defaults to the filemanager"
    )
  end

  -- default_target() / candidate_targets() honor configured defaults ---------
  do
    require("open").setup({ default_filemanager = "vsplit", default_browser = "firefox" })
    H.eq(
      context.default_target({ cword = "https://x.dev" }),
      "firefox",
      "default_target reads the configured default_browser"
    )
    H.eq(
      context.default_target({}),
      "vsplit",
      "default_target reads the configured default_filemanager"
    )

    local candidates = context.candidate_targets({ tree_path = "/x" })
    H.eq(
      candidates[1],
      "vsplit",
      "candidate_targets' tree_path branch also reads the configured default"
    )
    require("open").setup({})
  end

  -- gather(): a netrw buffer's node under the cursor becomes tree_path -------
  H.tmpdir(function(dir)
    H.write(dir .. "/entry.txt", "x")
    local buf = H.scratch({ "entry.txt" }, "netrw")
    vim.b[buf].netrw_curdir = dir
    local signals = context.gather()
    H.contains(
      signals.tree_path:gsub("\\", "/"),
      "entry.txt",
      "a netrw buffer resolves tree_path from netrw_curdir + the current line"
    )
  end)

  -- netrw: banner and header lines are no entry; thin and long lists give the bare name -----
  do
    local entry = context._netrw_entry
    H.eq(entry("entry.txt"), "entry.txt", "thin list: the line is the name")
    H.eq(
      entry("  my file.txt  "),
      "my file.txt",
      "thin list: spaces in a name are kept, the edges trimmed"
    )
    H.eq(entry("sub/"), "sub/", "thin list: a directory keeps its slash")
    H.eq(
      entry("my file.txt  1234 Wed Jan 01 12:00:00 2026"),
      "my file.txt",
      "long list: size and timestamp are cut off"
    )
    H.eq(entry("sub/  0 Wed Jan 01 12:00:00 2026"), "sub/", "long list: also for a directory")
    H.eq(
      entry('" ============================================================================'),
      nil,
      "banner rule"
    )
    H.eq(
      entry('" Netrw Directory Listing                                        (netrw v175)'),
      nil,
      "banner title"
    )
    H.eq(entry('"   Sorted by      name'), nil, "banner sort line")
    H.eq(entry(""), nil, "an empty line")

    -- A long list in a locale whose date is not the C shape: the existing file decides the cut.
    local files = { ["my file 2.txt"] = true, ["my file"] = true, ["sub/"] = true }
    local function exists(name)
      return files[name] == true
    end
    H.eq(
      entry("report.txt  1234 15.10.2026 01:52:17", function(n)
        return n == "report.txt"
      end),
      "report.txt",
      "long list, German date: cut at the size column"
    )
    H.eq(
      entry("my file 2.txt      1234 Wed 01 Jan 2026 12:00:00 PM UTC", exists),
      "my file 2.txt",
      "long list, glibc date: the longest existing candidate wins, not the first number"
    )
    H.eq(
      entry("sub/     0 01.01.2026 12:00:00", exists),
      "sub/",
      "long list, German date: directory"
    )
    H.eq(
      entry("my file 2.txt", exists),
      "my file 2.txt",
      "a thin-list name that holds a number is kept whole"
    )
    H.eq(
      entry("ghost.txt  12 15.10.2026 01:52:17", exists),
      "ghost.txt  12 15.10.2026 01:52:17",
      "no candidate exists: the line stands (no guess)"
    )

    -- C locale together with `exists` (what gather() always passes): the existing file decides,
    -- longest candidate first, and a stale C line still falls back to the C pattern cut.
    local c_files = { ["notes 2 final.txt"] = true, ["notes"] = true }
    local function c_exists(name)
      return c_files[name] == true
    end
    H.eq(
      entry("notes 2 final.txt  1234 Wed Jan 01 12:00:00 2026", c_exists),
      "notes 2 final.txt",
      "long list, C date, exists: the longest existing candidate wins over a shorter one"
    )
    H.eq(
      entry("gone.txt  1234 Wed Jan 01 12:00:00 2026", c_exists),
      "gone.txt",
      "long list, C date, exists: a stale line (file deleted) still cuts by the C pattern"
    )

    -- Stale line (file deleted) whose shorter prefix up to a number token exists: resolves to
    -- that neighbour. Kept on purpose: open.nvim only opens or reveals, the case needs a deleted
    -- file plus an unrefreshed listing, and a stricter cut cannot tell a locale's date from the
    -- rest of a name. Pinned so a change to it is a deliberate one.
    H.eq(
      entry("notes 2 draft.txt  1234 15.10.2026 01:52:17", c_exists),
      "notes",
      "stale long line: a shorter existing prefix (the neighbour file) wins"
    )

    H.tmpdir(function(dir)
      H.write(dir .. "/my file 2.txt", "x")
      local buf = H.scratch({ "my file 2.txt      1234 15.10.2026 01:52:17" }, "netrw")
      vim.b[buf].netrw_curdir = dir
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local signals = context.gather()
      H.eq(
        (signals.tree_path:gsub("\\", "/")),
        dir:gsub("\\", "/") .. "/my file 2.txt",
        "gather(): a long list line in a non-C locale resolves to the bare file"
      )
    end)

    H.tmpdir(function(dir)
      H.write(dir .. "/notes 2 final.txt", "x")
      H.write(dir .. "/notes", "x")
      local buf = H.scratch({ "notes 2 final.txt  1234 Wed Jan 01 12:00:00 2026" }, "netrw")
      vim.b[buf].netrw_curdir = dir
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local signals = context.gather()
      H.eq(
        (signals.tree_path:gsub("\\", "/")),
        dir:gsub("\\", "/") .. "/notes 2 final.txt",
        "gather(): a C locale long line resolves to the file, not to an existing shorter prefix"
      )
    end)

    H.tmpdir(function(dir)
      local buf = H.scratch({ '" Netrw Directory Listing', "entry.txt" }, "netrw")
      vim.b[buf].netrw_curdir = dir
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      local signals = context.gather()
      H.eq(signals.tree_path, dir, "the cursor on the banner resolves to the directory itself")
    end)
  end

  -- gather(): an unrecognised/soft-dep tree filetype never errors -------------
  do
    H.scratch({ "x" }, "neo-tree")
    local ok, signals = pcall(context.gather)
    H.ok(ok, "gather() does not error when neo-tree.sources.manager is not installed")
    H.falsy(signals.tree_path, "tree_path stays nil when the tree plugin is absent")
  end

  -- gather(): BUG -- the visual signal can never be the selection the user
  -- is actually making, only ever nil or a stale, unrelated one. It reads
  -- the `'<`/`'>` marks, which Neovim commits only once Visual mode is
  -- *left*, guarded by a check that mode() is *still* "v"/"V"/CTRL-V (i.e.
  -- Visual mode has not been left). Those two conditions cannot both hold
  -- for the same selection:
  --   1. `:'<,'>Open` from the command line -- the only way :Open itself is
  --      invoked -- auto-leaves Visual mode and sets the marks *before* the
  --      command callback runs, so by the time gather() would run, mode()
  --      already reads "n" and the whole branch is skipped, real fresh
  --      selection or not.
  --   2. The one path where mode() == "v" really does hold during the
  --      callback -- a user's own Visual-mode keymap calling
  --      require("open").open() directly -- is exactly the path where the
  --      current selection is *not finished yet*, so `'<`/`'>` still name
  --      whatever selection was last left (or {0,0,0,0} if there has not
  --      been one this session), never the one in progress.
  -- Pinned as-is on both fronts: fixing it (read `getpos("v")`, the live
  -- selection's anchor, plus the cursor, instead of `'<`/`'>`) is a
  -- deliberate change to what "visual" means here, not a side effect of a
  -- coverage pass.
  do
    H.scratch({ "hello world", "second line here" })

    -- 1) The command-line path: mode() is already "n" by the time a command
    --    would run, even for a real, just-finished selection.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v4l<Esc>", true, false, true), "x", false)
    H.eq(vim.fn.mode(), "n", "Visual mode is already gone by the time a command would run")
    H.falsy(
      context.gather().visual,
      "BUG: a real, just-finished selection is invisible from the only path :Open is actually invoked from"
    )

    -- 2) The Visual-mode-keymap path: mode() == "v" holds, but '</'> still
    --    name the *previous* (here: the one from part 1) selection, not the
    --    one being made right now.
    local seen
    vim.keymap.set("v", "<F2>", function()
      seen = context.gather().visual
    end, { buffer = 0 })

    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("v6l<F2>", true, false, true), "x", false)
    H.eq(
      seen,
      "hello",
      "BUG: mid-selection, gather() returns the previous selection's stale text ('hello'), not the current one ('second')"
    )
  end

  -- with_cache(): the cache is cleared even when the wrapped fn errors -------
  do
    H.scratch({ "x" })
    local orig_bufname = vim.api.nvim_buf_get_name
    local calls = 0
    vim.api.nvim_buf_get_name = function(...)
      calls = calls + 1
      return orig_bufname(...)
    end

    local ok = pcall(context.with_cache, function()
      context.gather()
      error("boom")
    end)
    H.falsy(ok, "the error inside with_cache propagates to the caller")

    calls = 0
    context.gather()
    context.gather()
    H.eq(calls, 2, "a prior error inside with_cache did not leave the cache stuck on")

    vim.api.nvim_buf_get_name = orig_bufname
  end
end
