-- TESTS/viewer_spec.lua — collect / sort / render / dispatch behavior.

return function(H)
  local viewer = require("open_nvim.viewer")

  local scan = require("open_nvim.viewer.scan")

  ---@param t table
  local function link(t)
    local base = { kind = "url", lnum = 1, col = 0, display = t.target }
    local lk = vim.tbl_extend("force", base, t)
    -- Mirror what scan.lua derives, so the helper cannot drift from the real
    -- shape and make a filter test pass for the wrong reason.
    if lk.is_url == nil then
      lk.is_url = scan.is_url(lk.target)
    end
    if lk.is_anchor == nil then
      lk.is_anchor = scan.is_anchor(lk.target)
    end
    lk.raw_target = lk.raw_target or lk.target
    return lk
  end

  -- sort ---------------------------------------------------------------------
  do
    local links = {
      link({ target = "https://c.dev", file = "/b.md", lnum = 1 }),
      link({ target = "https://a.dev", file = "/a.md", lnum = 9 }),
      link({ target = "https://b.dev", file = "/a.md", lnum = 2 }),
    }

    local by_file = viewer.sort(vim.deepcopy(links), "file")
    H.eq(by_file[1].file, "/a.md", "file sort groups by path")
    H.eq(by_file[1].lnum, 2, "within a file, sorted by line")
    H.eq(by_file[3].file, "/b.md", "later path sorts last")

    local by_alpha = viewer.sort(vim.deepcopy(links), "alpha")
    H.eq(by_alpha[1].target, "https://a.dev", "alpha sorts by target")
    H.eq(by_alpha[3].target, "https://c.dev", "alpha ordering is complete")

    local untouched = viewer.sort(vim.deepcopy(links), "none")
    H.eq(untouched[1].target, "https://c.dev", "sort=none preserves input order")

    -- An unknown sort name must not silently reorder or crash.
    local unknown = viewer.sort(vim.deepcopy(links), "bogus")
    H.eq(unknown[1].target, "https://c.dev", "unknown sort is a no-op")
  end

  -- sort by kind -------------------------------------------------------------
  do
    local links = {
      link({ target = "u", kind = "url", file = "/a", lnum = 1 }),
      link({ target = "m", kind = "mdlink", file = "/a", lnum = 2 }),
      link({ target = "p", kind = "path", file = "/a", lnum = 3 }),
    }
    local sorted = viewer.sort(links, "kind")
    H.eq(sorted[1].kind, "mdlink", "kinds sort alphabetically")
    H.eq(sorted[3].kind, "url", "url sorts last of the three")
  end

  -- sorting is a total order (stable across repeated runs) --------------------
  do
    local function fresh()
      return {
        link({ target = "https://same.dev", file = "/a.md", lnum = 1, col = 5 }),
        link({ target = "https://same.dev", file = "/a.md", lnum = 1, col = 0 }),
      }
    end
    local a = viewer.sort(fresh(), "alpha")
    local b = viewer.sort(fresh(), "alpha")
    H.eq(a[1].col, b[1].col, "equal targets break ties deterministically by position")
    H.eq(a[1].col, 0, "the earlier column comes first")
  end

  -- rows ---------------------------------------------------------------------
  do
    local headers, rows = viewer.rows({
      link({ target = "https://x.dev", file = "/tmp/a.md", lnum = 3, kind = "mdlink", text = "X" }),
    })
    H.eq(#headers, 4, "four columns")
    H.eq(rows[1][1], "mdlink", "kind column")
    H.eq(rows[1][2], "a.md:3", "location column is basename:line")
    H.eq(rows[1][3], "X", "text column")
    H.eq(rows[1][4], "https://x.dev", "target column")
  end

  -- a buffer-only link still gets a location label ---------------------------
  do
    local _, rows = viewer.rows({ link({ target = "https://x.dev", lnum = 8 }) })
    -- Short on purpose: this column repeats on every row, so the width it
    -- takes comes straight out of the target column's budget.
    H.eq(rows[1][2], "buf:8", "unnamed source labelled as buffer")
  end

  -- as_markdown --------------------------------------------------------------
  do
    -- A markdown link keeps its own label.
    local kept = viewer.as_markdown({ link({ target = "https://x.dev", kind = "mdlink", text = "Docs" }) })
    H.eq(kept, "[Docs](https://x.dev)", "existing label preserved")

    -- A bare URL has no label; falling back to the host keeps the output from
    -- rendering as an invisible "[]()".
    local host = viewer.as_markdown({ link({ target = "https://example.com/deep/path" }) })
    H.eq(host, "[example.com](https://example.com/deep/path)", "bare URL labelled with its host")

    -- A path is labelled with its basename.
    local p = viewer.as_markdown({ link({ target = "/tmp/dir/file.md", kind = "path" }) })
    H.eq(p, "[file.md](/tmp/dir/file.md)", "path labelled with its basename")
  end

  -- collect ------------------------------------------------------------------
  do
    H.scratch({ "https://a.dev", "nothing here", "[b](https://b.dev)" })
    local links, err = viewer.collect("%")
    H.falsy(err, "collect over the current buffer succeeds")
    H.eq(#links, 2, "both links collected")
  end

  -- collect over a range -----------------------------------------------------
  do
    H.scratch({ "https://a.dev", "https://b.dev", "https://c.dev" })
    local links = viewer.collect(nil, { range = true, line1 = 2, line2 = 3 })
    H.eq(#links, 2, "range limits the collection")
    H.eq(links[1].target, "https://b.dev", "range starts where asked")
    H.eq(links[1].lnum, 2, "range reports real buffer line numbers")
  end

  -- collect propagates a scope error instead of silently returning nothing ---
  do
    local links, err = viewer.collect("/definitely/not/here/xyz")
    H.eq(#links, 0, "bad scope yields no links")
    H.ok(err, "bad scope reports an error")
  end

  -- collect from disk --------------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "https://one.dev\n")
    H.write(dir .. "/sub/b.md", "https://two.dev\n")
    local links = viewer.collect(dir)
    H.eq(#links, 2, "directory scope collects recursively")
  end)

  -- unique de-duplication ----------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "https://dup.dev\n")
    H.write(dir .. "/b.md", "https://dup.dev\n")
    H.eq(#viewer.collect(dir, { unique = true }), 1, "unique collapses across files")
    H.eq(#viewer.collect(dir), 2, "without unique, both are kept")
  end)

  -- filter -------------------------------------------------------------------
  do
    local links = {
      link({ target = "https://bare.dev", kind = "url" }),
      link({ target = "https://in-md.dev", kind = "mdlink", text = "d" }),
      link({ target = "/tmp/doc.md", kind = "mdlink", text = "doc" }),
      link({ target = "/tmp/file.lua", kind = "path" }),
    }

    -- `urls` selects on the target, so a markdown link to https:// counts.
    -- This is the whole point of the split: :UrlView means "browser-openable".
    local urls = viewer.filter(links, "urls")
    H.eq(#urls, 2, "urls keeps both the bare URL and the markdown link to one")

    -- `mdlinks` selects on the syntax, so a markdown link to a local file counts.
    local md = viewer.filter(links, "mdlinks")
    H.eq(#md, 2, "mdlinks keeps both markdown links regardless of target")

    local files = viewer.filter(links, "files")
    H.eq(#files, 2, "files keeps the two local targets")

    local paths = viewer.filter(links, "paths")
    H.eq(#paths, 1, "paths keeps only bare filesystem paths")

    H.eq(#viewer.filter(links, "all"), 4, "all keeps everything")
    H.eq(#viewer.filter(links, nil), 4, "nil kind behaves as all")
  end

  -- labels: alignment must survive a long filename ---------------------------
  do
    local links = {
      link({ target = "https://a.dev", file = "/x/a.md", lnum = 1 }),
      link({ target = "https://b.dev", file = "/x/a-very-long-filename-indeed.md", lnum = 4321 }),
    }
    local labels = viewer.labels(links, 80)
    H.eq(#labels, 2, "one label per link")
    for i, l in ipairs(labels) do
      H.ok(vim.fn.strdisplaywidth(l) <= 80, "label " .. i .. " fits the width budget")
    end
    -- The target column has to start at the same *display* column on every
    -- row, which is exactly what a hardcoded %-24s failed to guarantee.
    -- Measured in cells, not bytes: a shortened row contains a "…" that is
    -- 3 bytes but 1 cell, so a byte offset would differ even when the rows
    -- line up perfectly on screen.
    local function target_col(label)
      local byte = assert(label:find("https://", 1, true), "label has no target")
      return vim.fn.strdisplaywidth(label:sub(1, byte - 1))
    end
    H.eq(target_col(labels[1]), target_col(labels[2]),
      "target column starts at the same display column on every row")
  end

  -- labels: a huge list still produces bounded rows --------------------------
  do
    local links = {}
    for i = 1, 200 do
      links[i] = link({
        target = "https://example.com/very/deep/path/segment/" .. i,
        file = "/repo/docs/some/nested/place/file" .. i .. ".md",
        lnum = i,
      })
    end
    local labels = viewer.labels(links, 100)
    H.eq(#labels, 200, "every link gets a label")
    for _, l in ipairs(labels) do
      if vim.fn.strdisplaywidth(l) > 100 then
        error("FAIL: label exceeded the width budget: " .. l)
      end
    end
  end

  -- open(): URLs go to the browser -------------------------------------------
  do
    local registry = require("open_nvim.registry")
    local orig = registry.dispatch
    local seen_handler, seen
    registry.dispatch = function(handler, ctx)
      seen_handler, seen = handler, ctx
      return true
    end

    viewer.open(link({ target = "www.example.com", kind = "url" }))
    H.eq(seen.text, "https://www.example.com", "www target gains a scheme")
    H.ok(seen.is_url, "dispatched as a URL")

    -- A markdown link whose target is a URL must also go to the browser.
    viewer.open(link({ target = "https://md.dev", kind = "mdlink", text = "x" }))
    H.ok(seen.is_url, "markdown link to a URL dispatches as a URL")

    registry.dispatch = orig
  end

  -- open(): a local file goes into a Neovim buffer, not the file manager -----
  H.tmpdir(function(dir)
    H.write(dir .. "/doc.md", "# Title\n\nbody\n")
    local registry = require("open_nvim.registry")
    local orig = registry.dispatch
    local seen_handler, seen
    registry.dispatch = function(handler, ctx)
      seen_handler, seen = handler, ctx
      return true
    end

    viewer.open(link({ target = dir .. "/doc.md", kind = "mdlink", text = "doc" }))
    H.eq(seen_handler, "split", "a local file is opened in a split, not the filemanager")
    H.eq(seen.text, dir .. "/doc.md", "the file path is dispatched unchanged")
    H.falsy(seen.is_url, "a file is not dispatched as a URL")

    -- A "file.md#heading" target must have its fragment stripped before the
    -- path is handed over, or the dispatch would name a nonexistent file.
    seen = nil
    viewer.open(link({ target = dir .. "/doc.md#title", kind = "mdlink", text = "t" }))
    H.eq(seen.text, dir .. "/doc.md", "trailing #anchor stripped from the dispatched path")

    -- A target that does not exist must warn, not dispatch a bogus path.
    seen = nil
    viewer.open(link({ target = dir .. "/ghost.md", kind = "mdlink", text = "g" }))
    H.falsy(seen, "a nonexistent target is not dispatched")

    registry.dispatch = orig
  end)
end
