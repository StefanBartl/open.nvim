# open.nvim — Features

A single `:Open [target] [scope]` command that routes the thing under your
cursor — path, URL, or plain text — to the right destination: system file
manager, browser (with named-browser support), GUI text editor, or Neovim
split/tab. Context-aware: knows when you are in a Neo-tree, nvim-tree, or
netrw buffer and opens the node under the cursor directly.

See [README.md](../README.md) for a quickstart, and
[docs/commands.md](commands.md) for the full command reference.

## Table of content

- [Handlers](#handlers)
- [Smart context resolution](#smart-context-resolution)
- [Link listing (`:UrlView`)](#link-listing-urlview)

## Handlers

| Handler | What it opens | Platform |
|---|---|---|
| `default` | Open in the system default app (like double-click) | all |
| `browser` | URL or text → system default browser (text → Google search) | all |
| `chrome` | Google Chrome | Linux / WSL / Windows / macOS |
| `chromium` | Chromium | Linux / WSL / Windows / macOS |
| `firefox` | Mozilla Firefox | Linux / WSL / Windows / macOS |
| `edge` | Microsoft Edge | Linux / WSL / Windows / macOS |
| `safari` | Safari | macOS only |
| `filemanager` | Path → system file manager (Explorer / Finder / xdg-open) | all |
| `notepad` | Text → temp file → GUI text editor | all |
| `editor` | Alias for `notepad` | all |
| `split` | File path → Neovim horizontal split | all |
| `vsplit` | File path → Neovim vertical split | all |
| `tab` | File path → Neovim new tab | all |

## Smart context resolution

- In a **Neo-tree / nvim-tree / netrw** buffer → opens the node under the cursor
- Cursor on a **URL** with no explicit target → falls back to `browser`
- Cursor on a **file path** → falls back to `filemanager`
- Visual selection → used as the target text

## Link listing (`:UrlView`)

`:Open viewer [kind]` — with `:UrlView` and `:MDLinksView` as shortcuts —
collects links in a scope and either hands you a picker or exports the lot.
It replaces the former
[urlview.nvim](https://github.com/axieax/urlview.nvim) dependency.

**Scopes:** the current buffer, a visual range, every listed buffer, a single
file, a directory tree, or the whole cwd. Directory scans use lib.nvim's
shared ignore list and skip binary and oversized files.

**Recognizes:** bare URLs (`https://…`, `ftp://…`, `www.…`), markdown links
(reported by target, with the label kept), and — with `--paths` — filesystem
paths that actually exist on disk. Links inside fenced code blocks are
skipped, a URL already inside a markdown link is not reported twice, and
in-document anchors (`[Kontext](#kontext)`) are dropped unless you pass
`--anchors`.

**Filters:** `urls` selects on the *target* (so `[docs](https://x)` counts),
`mdlinks` on the *syntax* (so `[doc](./a.md)` counts). That is what lets
`:UrlView` mean "things a browser can open".

**Relative targets are resolved** against the file they were found in, so a
`[x](../../lua/init.lua)` in a nested doc is openable from anywhere.

**The picker** is lib.nvim's `ui.kit.chooser`: the whole current line is
highlighted, the cursor moves only up and down, and `<CR>` is kind-aware — a
URL goes to your browser, a local file opens in a Neovim split, a directory
goes to the file manager.

**Outputs:** the picker, a GFM table, CSV, markdown links, the clipboard, a
file, or the message area.

```
:UrlView                                 URLs in this buffer → picker
:MDLinksView cwd                         every markdown link in the project
:Open viewer cwd sort=file out=table     everything, as a table
:'<,'>UrlView                            just the selection
```

Built on [`lib.nvim.harvest`](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/harvest/README.md).
See [docs/commands.md](commands.md#open-viewer--urlview--mdlinksview) for every option.
