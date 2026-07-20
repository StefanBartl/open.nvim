-- TESTS/harvest_scope_spec.lua — lib.nvim.harvest.scope resolution.

return function(H)
  local scope = require("lib.nvim.harvest.scope")

  -- buffer ------------------------------------------------------------------
  do
    H.scratch({ "one", "two", "three" })
    local srcs, err = scope.resolve("buffer")
    H.falsy(err, "buffer scope has no error")
    H.eq(#srcs, 1, "buffer yields one source")
    H.eq(#srcs[1].lines, 3, "buffer source has 3 lines")
    H.eq(srcs[1].first, 1, "buffer source starts at line 1")
  end

  -- range: `first` must reflect the real starting line ------------------------
  do
    H.scratch({ "a", "b", "c", "d", "e" })
    local srcs, err = scope.resolve("range", { line1 = 2, line2 = 4 })
    H.falsy(err, "range scope has no error")
    H.eq(#srcs[1].lines, 3, "range yields 3 lines")
    H.eq(srcs[1].lines[1], "b", "range starts at line 2")
    H.eq(srcs[1].first, 2, "range reports its real offset")
  end

  -- range clamps out-of-bounds bounds rather than erroring --------------------
  do
    H.scratch({ "a", "b" })
    local srcs = scope.resolve("range", { line1 = 1, line2 = 99 })
    H.eq(#srcs[1].lines, 2, "range clamps line2 to buffer length")
  end

  -- an inverted range is empty, not a crash ----------------------------------
  do
    H.scratch({ "a", "b", "c" })
    local srcs, err = scope.resolve("range", { line1 = 3, line2 = 1 })
    H.eq(#srcs, 0, "inverted range yields nothing")
    H.ok(err, "inverted range reports an error")
  end

  -- path: single file --------------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "hello\nworld\n")
    local srcs, err = scope.resolve("path", { path = dir .. "/a.md" })
    H.falsy(err, "file path scope has no error")
    H.eq(#srcs, 1, "one file yields one source")
    H.eq(#srcs[1].lines, 2, "trailing newline does not add a phantom line")
    H.eq(srcs[1].lines[2], "world", "second line read correctly")
  end)

  -- path: directory, recursive by default, with a match filter ---------------
  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "x\n")
    H.write(dir .. "/b.txt", "y\n")
    H.write(dir .. "/sub/c.md", "z\n")

    local all = scope.resolve("path", { path = dir })
    H.eq(#all, 3, "recursive by default finds nested files")

    local md = scope.resolve("path", { path = dir, match = "%.md$" })
    H.eq(#md, 2, "match filter keeps only .md")

    local flat = scope.resolve("path", { path = dir, recursive = false })
    H.eq(#flat, 2, "recursive=false stays shallow")
  end)

  -- path: ignore list prunes conventional junk directories -------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/keep.md", "x\n")
    H.write(dir .. "/node_modules/drop.md", "y\n")
    local srcs = scope.resolve("path", { path = dir })
    H.eq(#srcs, 1, "node_modules is pruned by the default ignore list")
    H.contains(srcs[1].file, "keep.md", "the kept file is the non-ignored one")
  end)

  -- binary files are skipped -------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/bin.dat", "abc\0def")
    H.write(dir .. "/ok.md", "text\n")
    local srcs = scope.resolve("path", { path = dir })
    H.eq(#srcs, 1, "NUL-containing file is skipped as binary")
  end)

  -- oversized files are skipped ----------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/big.md", string.rep("x", 500))
    local srcs = scope.resolve("path", { path = dir, max_filesize = 100 })
    H.eq(#srcs, 0, "file above max_filesize is skipped")
  end)

  -- CRLF is normalized -------------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/crlf.md", "a\r\nb\r\n")
    local srcs = scope.resolve("path", { path = dir .. "/crlf.md" })
    H.eq(#srcs[1].lines, 2, "CRLF file has 2 lines")
    H.eq(srcs[1].lines[1], "a", "CR is stripped from line content")
  end)

  -- errors -------------------------------------------------------------------
  do
    local _, err = scope.resolve("path", {})
    H.ok(err, "path scope without a path errors")

    local _, err2 = scope.resolve("path", { path = "/definitely/not/here/xyz" })
    H.ok(err2, "nonexistent path errors")

    local _, err3 = scope.resolve("nope")
    H.ok(err3, "unknown scope errors")
  end

  -- resolve_token ------------------------------------------------------------
  do
    H.scratch({ "a" })
    local srcs = scope.resolve_token(nil)
    H.eq(#srcs, 1, "nil token defaults to the current buffer")

    local srcs2 = scope.resolve_token("%")
    H.eq(#srcs2, 1, "'%' token means the current buffer")
  end

  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "x\n")
    local srcs = scope.resolve_token(dir)
    H.eq(#srcs, 1, "an unrecognized token is treated as a path")
  end)
end
