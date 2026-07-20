-- TESTS/urlview_scan_spec.lua — link extraction.

return function(H)
  local scan = require("open_nvim.urlview.scan")

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
end
