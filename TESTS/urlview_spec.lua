-- TESTS/urlview_spec.lua — collect / sort / render / dispatch behavior.

return function(H)
  local urlview = require("open_nvim.urlview")

  ---@param t table
  local function link(t)
    return vim.tbl_extend("force", { kind = "url", lnum = 1, col = 0, display = t.target }, t)
  end

  -- sort ---------------------------------------------------------------------
  do
    local links = {
      link({ target = "https://c.dev", file = "/b.md", lnum = 1 }),
      link({ target = "https://a.dev", file = "/a.md", lnum = 9 }),
      link({ target = "https://b.dev", file = "/a.md", lnum = 2 }),
    }

    local by_file = urlview.sort(vim.deepcopy(links), "file")
    H.eq(by_file[1].file, "/a.md", "file sort groups by path")
    H.eq(by_file[1].lnum, 2, "within a file, sorted by line")
    H.eq(by_file[3].file, "/b.md", "later path sorts last")

    local by_alpha = urlview.sort(vim.deepcopy(links), "alpha")
    H.eq(by_alpha[1].target, "https://a.dev", "alpha sorts by target")
    H.eq(by_alpha[3].target, "https://c.dev", "alpha ordering is complete")

    local untouched = urlview.sort(vim.deepcopy(links), "none")
    H.eq(untouched[1].target, "https://c.dev", "sort=none preserves input order")

    -- An unknown sort name must not silently reorder or crash.
    local unknown = urlview.sort(vim.deepcopy(links), "bogus")
    H.eq(unknown[1].target, "https://c.dev", "unknown sort is a no-op")
  end

  -- sort by kind -------------------------------------------------------------
  do
    local links = {
      link({ target = "u", kind = "url", file = "/a", lnum = 1 }),
      link({ target = "m", kind = "mdlink", file = "/a", lnum = 2 }),
      link({ target = "p", kind = "path", file = "/a", lnum = 3 }),
    }
    local sorted = urlview.sort(links, "kind")
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
    local a = urlview.sort(fresh(), "alpha")
    local b = urlview.sort(fresh(), "alpha")
    H.eq(a[1].col, b[1].col, "equal targets break ties deterministically by position")
    H.eq(a[1].col, 0, "the earlier column comes first")
  end

  -- rows ---------------------------------------------------------------------
  do
    local headers, rows = urlview.rows({
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
    local _, rows = urlview.rows({ link({ target = "https://x.dev", lnum = 8 }) })
    H.eq(rows[1][2], "[buffer]:8", "unnamed source labelled as buffer")
  end

  -- as_markdown --------------------------------------------------------------
  do
    -- A markdown link keeps its own label.
    local kept = urlview.as_markdown({ link({ target = "https://x.dev", kind = "mdlink", text = "Docs" }) })
    H.eq(kept, "[Docs](https://x.dev)", "existing label preserved")

    -- A bare URL has no label; falling back to the host keeps the output from
    -- rendering as an invisible "[]()".
    local host = urlview.as_markdown({ link({ target = "https://example.com/deep/path" }) })
    H.eq(host, "[example.com](https://example.com/deep/path)", "bare URL labelled with its host")

    -- A path is labelled with its basename.
    local p = urlview.as_markdown({ link({ target = "/tmp/dir/file.md", kind = "path" }) })
    H.eq(p, "[file.md](/tmp/dir/file.md)", "path labelled with its basename")
  end

  -- collect ------------------------------------------------------------------
  do
    H.scratch({ "https://a.dev", "nothing here", "[b](https://b.dev)" })
    local links, err = urlview.collect("%")
    H.falsy(err, "collect over the current buffer succeeds")
    H.eq(#links, 2, "both links collected")
  end

  -- collect over a range -----------------------------------------------------
  do
    H.scratch({ "https://a.dev", "https://b.dev", "https://c.dev" })
    local links = urlview.collect(nil, { range = true, line1 = 2, line2 = 3 })
    H.eq(#links, 2, "range limits the collection")
    H.eq(links[1].target, "https://b.dev", "range starts where asked")
    H.eq(links[1].lnum, 2, "range reports real buffer line numbers")
  end

  -- collect propagates a scope error instead of silently returning nothing ---
  do
    local links, err = urlview.collect("/definitely/not/here/xyz")
    H.eq(#links, 0, "bad scope yields no links")
    H.ok(err, "bad scope reports an error")
  end

  -- collect from disk --------------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "https://one.dev\n")
    H.write(dir .. "/sub/b.md", "https://two.dev\n")
    local links = urlview.collect(dir)
    H.eq(#links, 2, "directory scope collects recursively")
  end)

  -- unique de-duplication ----------------------------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/a.md", "https://dup.dev\n")
    H.write(dir .. "/b.md", "https://dup.dev\n")
    H.eq(#urlview.collect(dir, { unique = true }), 1, "unique collapses across files")
    H.eq(#urlview.collect(dir), 2, "without unique, both are kept")
  end)

  -- open(): a scheme-less www target must be given one before dispatch -------
  do
    local registry = require("open_nvim.registry")
    local orig = registry.dispatch
    local seen
    registry.dispatch = function(_handler, ctx)
      seen = ctx
      return true
    end

    urlview.open(link({ target = "www.example.com", kind = "url" }))
    H.eq(seen.text, "https://www.example.com", "www target gains a scheme")
    H.ok(seen.is_url, "dispatched as a URL")

    urlview.open(link({ target = "/tmp/x.md", kind = "path" }))
    H.eq(seen.text, "/tmp/x.md", "path target passed through unchanged")
    H.falsy(seen.is_url, "path is not dispatched as a URL")

    registry.dispatch = orig
  end
end
