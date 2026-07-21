-- TESTS/viewer_scan_spec.lua — link extraction.

return function(H)
  local scan = require("open.viewer.scan")

  ---@param lines string[]
  ---@param opts table|nil
  local function scan_lines(lines, opts)
    return scan.from_source({ lines = lines, first = 1 }, opts)
  end

  -- bare URL -----------------------------------------------------------------
  do
    local out = scan_lines({ "see https://example.com/a for more" })
    H.eq(#out, 1, "one bare URL found")
    H.eq(out[1].kind, "url", "kind is url")
    H.eq(out[1].target, "https://example.com/a", "target extracted")
    H.eq(out[1].lnum, 1, "line number recorded")
  end

  -- trailing sentence punctuation is not part of the URL ---------------------
  do
    local out = scan_lines({ "go to https://example.com/x." })
    H.eq(out[1].target, "https://example.com/x", "trailing period stripped")

    local paren = scan_lines({ "(see https://example.com/y)" })
    H.eq(paren[1].target, "https://example.com/y", "trailing paren stripped")
  end

  -- markdown link ------------------------------------------------------------
  do
    local out = scan_lines({ "[docs](https://example.com/d)" })
    H.eq(#out, 1, "markdown link reported once, not twice")
    H.eq(out[1].kind, "mdlink", "kind is mdlink")
    H.eq(out[1].target, "https://example.com/d", "target is the URL, not the label")
    H.eq(out[1].text, "docs", "label captured")
  end

  -- a markdown link's URL must not also be reported as a bare URL ------------
  do
    local out = scan_lines({ "[a](https://x.dev) and https://y.dev" })
    H.eq(#out, 2, "one mdlink + one bare URL")
    local kinds = {}
    for _, l in ipairs(out) do
      kinds[l.kind] = (kinds[l.kind] or 0) + 1
    end
    H.eq(kinds.mdlink, 1, "exactly one mdlink")
    H.eq(kinds.url, 1, "exactly one bare url")
  end

  -- angle-bracketed markdown target ------------------------------------------
  do
    local out = scan_lines({ "[a](<https://x.dev/sp ace>)" })
    H.eq(out[1].target, "https://x.dev/sp ace", "angle brackets stripped from target")
  end

  -- www without a scheme -----------------------------------------------------
  do
    local out = scan_lines({ "visit www.example.com today" })
    H.eq(#out, 1, "www-only URL found")
    H.eq(out[1].target, "www.example.com", "www target kept verbatim")
  end

  -- non-http schemes ---------------------------------------------------------
  do
    local out = scan_lines({ "ftp://files.example.com/pub" })
    H.eq(out[1].target, "ftp://files.example.com/pub", "non-http scheme recognized")
  end

  -- fenced code blocks are skipped -------------------------------------------
  do
    local out = scan_lines({
      "https://before.dev",
      "```",
      "https://inside.dev",
      "```",
      "https://after.dev",
    })
    H.eq(#out, 2, "links inside a fence are skipped")
    H.eq(out[1].target, "https://before.dev", "pre-fence link kept")
    H.eq(out[2].target, "https://after.dev", "post-fence link kept")
  end

  -- fence skipping can be disabled -------------------------------------------
  do
    local out = scan_lines({ "```", "https://inside.dev", "```" }, { code_fences = false })
    H.eq(#out, 1, "code_fences=false scans inside fences")
  end

  -- line numbers respect the source offset -----------------------------------
  do
    local out = scan.from_source({ lines = { "https://x.dev" }, first = 42 })
    H.eq(out[1].lnum, 42, "lnum is offset by source.first")
  end

  -- lines without links ------------------------------------------------------
  do
    H.eq(#scan_lines({ "just some prose", "" }), 0, "no links in plain prose")
    -- A bare word with a dot is not a URL; without this, every `foo.bar()`
    -- method call in source code would be reported.
    H.eq(#scan_lines({ "obj.method() and a.b.c" }), 0, "dotted identifiers are not URLs")
  end

  -- paths are opt-in and must exist on disk ----------------------------------
  H.tmpdir(function(dir)
    H.write(dir .. "/real.md", "x\n")
    local line = dir .. "/real.md and " .. dir .. "/ghost.md"

    local without = scan_lines({ line })
    H.eq(#without, 0, "paths are not reported unless opted in")

    local with = scan_lines({ line }, { paths = true })
    H.eq(#with, 1, "only the path that exists is reported")
    H.eq(with[1].kind, "path", "kind is path")
    H.contains(with[1].target, "real.md", "the existing path is the one found")
  end)

  -- from_sources: unique de-duplicates across sources -------------------------
  do
    local sources = {
      { lines = { "https://dup.dev" }, first = 1, file = "/a" },
      { lines = { "https://dup.dev" }, first = 1, file = "/b" },
    }
    H.eq(#scan.from_sources(sources), 2, "duplicates kept by default")
    H.eq(#scan.from_sources(sources, { unique = true }), 1, "unique collapses duplicates")
  end

  -- provenance is attached ---------------------------------------------------
  do
    local out = scan.from_sources({ { lines = { "https://x.dev" }, first = 1, file = "/tmp/a.md", bufnr = 7 } })
    H.eq(out[1].file, "/tmp/a.md", "file provenance attached")
    H.eq(out[1].bufnr, 7, "bufnr provenance attached")
  end

  -- is_url / is_anchor classification ----------------------------------------
  do
    H.ok(scan.is_url("https://x.dev"), "https is a URL")
    H.ok(scan.is_url("ftp://x.dev"), "ftp is a URL")
    H.ok(scan.is_url("www.x.dev"), "www is a URL")
    H.falsy(scan.is_url("../notes.md"), "a relative path is not a URL")
    H.falsy(scan.is_url(nil), "nil is not a URL")

    H.ok(scan.is_anchor("#heading"), "a leading # is an anchor")
    H.falsy(scan.is_anchor("file.md#heading"), "a path with a fragment is not a bare anchor")
  end

  -- a markdown link is flagged by target, not by syntax ----------------------
  do
    local url_md = scan_lines({ "[docs](https://x.dev)" })
    H.eq(url_md[1].kind, "mdlink", "syntactic kind stays mdlink")
    H.ok(url_md[1].is_url, "but a markdown link to a URL is flagged is_url")

    local file_md = scan.from_source(
      { lines = { "[doc](../notes.md)" }, first = 1, file = "/repo/docs/a.md" }
    )
    H.eq(file_md[1].kind, "mdlink", "local markdown link is still an mdlink")
    H.falsy(file_md[1].is_url, "but is not flagged is_url")
  end

  -- relative targets resolve against the source file's directory -------------
  do
    local out = scan.from_source(
      { lines = { "[x](../../lua/startup/init.lua)" }, first = 1, file = "/repo/docs/notes/startup.md" }
    )
    H.eq(out[1].target, "/repo/lua/startup/init.lua", "relative target resolved against the source dir")
    H.eq(out[1].raw_target, "../../lua/startup/init.lua", "raw target preserved as written")
  end

  -- a fragment is kept but not treated as part of the filename ---------------
  do
    local out = scan.from_source(
      { lines = { "[x](./other.md#some-heading)" }, first = 1, file = "/repo/docs/a.md" }
    )
    H.eq(out[1].target, "/repo/docs/other.md#some-heading", "path resolved, fragment reattached")
  end

  -- an absolute target is normalized, not re-anchored ------------------------
  do
    local out = scan.from_source(
      { lines = { "[x](/abs/target.md)" }, first = 1, file = "/repo/docs/a.md" }
    )
    H.contains(out[1].target, "/abs/target.md", "absolute target left absolute")
  end

  -- bare anchors are dropped by default --------------------------------------
  do
    local lines = { "[Kontext](#kontext)", "[Real](./real.md)" }
    local src = { lines = lines, first = 1, file = "/repo/docs/a.md" }

    local without = scan.from_source(src)
    H.eq(#without, 1, "in-document anchors are dropped by default")
    H.contains(without[1].target, "real.md", "the surviving link is the file one")

    local with = scan.from_source(src, { anchors = true })
    H.eq(#with, 2, "anchors = true keeps them")
    H.ok(with[1].is_anchor, "the anchor is flagged as one")
    H.eq(with[1].target, "#kontext", "an anchor target is left untouched")
  end
end
