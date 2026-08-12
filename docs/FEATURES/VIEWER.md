# Viewer

`:Open viewer` and its `:UrlView` / `:MDLinksView` wrappers — the other
direction from every handler in [`HANDLERS.md`](HANDLERS.md): instead of
opening one given target, it scans a scope for links and hands you a
picker (or an export).

## Link viewer — `:Open viewer` / `:UrlView` / `:MDLinksView`

Scans a scope for links and either hands you a picker or exports the
result. Replaces the former
[urlview.nvim](https://github.com/axieax/urlview.nvim) dependency with a
native implementation built on `lib.nvim.harvest`, covering more ground:
files, whole directories, every listed buffer, and a visual range, not just
the current buffer.

Recognizes three syntactic shapes — bare URLs (`https://…`, `www.…`),
markdown links (`[text](target)`), and, opt-in via `--paths`, bare
filesystem paths that actually exist on disk — then filters on `kind`
(`urls`, `mdlinks`, `files`, `paths`, `all`). Scope defaults to the current
buffer; `cwd` scans the working directory recursively (skipping `.git`,
`node_modules`, and other conventional junk), `buffers` scans every listed
buffer, a bare path scans one file or directory, and a visual/line range
scans only those lines. Links inside fenced code blocks are skipped, and a
URL already consumed by a markdown link is not reported a second time as a
bare URL.

Default output is an interactive picker (`lib.nvim.ui.kit.chooser`) whose
`<CR>` is kind-aware: a URL goes to the configured browser handler, a local
file opens through the handler named by `opts.viewer.open_file`
(`"split"` by default), and a directory goes to the file manager. A
`file.md#heading` target does a best-effort jump to that heading after
opening. Non-picker outputs (`table`, `csv`, `mdlinks`, `clipboard`,
`echo`, `file:<path>`) render the whole result set instead of opening
anything.

- **Module:** `open/viewer/init.lua` (`M.collect`, `M.filter`, `M.sort`,
  `M.run`, `M.open`), `open/viewer/scan.lua`
- **Usercmds:** `:Open viewer [kind] [scope] [options]` ·
  `:UrlView [scope] [options]` · `:MDLinksView [scope] [options]`
  (see [`../BINDINGS.md#usrcmds`](../BINDINGS.md#usrcmds))
- **Config:** `opts.viewer` (`commands`, `sort`, `output`,
  `mdlinks_output`, `open_file`)
- **Docs:** [`docs/commands.md`](../commands.md#open-viewer--urlview--mdlinksview),
  [`docs/api.md`](../api.md#link-listing)
