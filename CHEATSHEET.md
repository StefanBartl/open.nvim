# open.nvim — Cheatsheet

## Table of content

  - [All registered handlers](#all-registered-handlers)
  - [Scope tokens (2nd argument)](#scope-tokens-2nd-argument)
  - [Common command examples](#common-command-examples)
  - [Platform dispatch summary](#platform-dispatch-summary)
  - [Link listing (`:UrlView`)](#link-listing-urlview)
  - [Lua API](#lua-api)
  - [Integrations](#integrations)

---

`:Open [target] [scope]` is built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion for both arguments.

## All registered handlers

| Handler | Key | Description | Platform |
|---|---|---|---|
| Default app | `default` | Open in system default app (like double-click); PDFs → PDF viewer, .docx → Word, etc. | all |
| System browser | `browser` | URL or text → default browser; plain text → Google search | all |
| Google Chrome | `chrome` | Named browser: Google Chrome / Chromium | Linux · WSL · Win · Mac |
| Chromium | `chromium` | Named browser: Chromium | Linux · WSL · Win · Mac |
| Mozilla Firefox | `firefox` | Named browser: Mozilla Firefox | Linux · WSL · Win · Mac |
| Microsoft Edge | `edge` | Named browser: Microsoft Edge | Linux · WSL · Win · Mac |
| Safari | `safari` | Named browser: Safari | macOS only |
| File manager | `filemanager` | Path → Explorer / Finder / xdg-open | all |
| GUI text editor | `notepad` | Text → temp `.txt` → notepad.exe / TextEdit / gedit… | all |
| GUI text editor | `editor` | Alias for `notepad` | all |
| Nvim split | `split` | File path → horizontal split in Neovim | all |
| Nvim vsplit | `vsplit` | File path → vertical split in Neovim | all |
| Nvim tab | `tab` | File path → new tab in Neovim | all |
| Terminal | `terminal` | Path → terminal split in that directory (file → its parent dir) | all |

## Scope tokens (2nd argument)

| Token | Source |
|---|---|
| *(omitted)* | Heuristic: tree node → cfile → cWORD / buffer path |
| `%` | Current buffer file path |
| `cfile` | `<cfile>` under cursor |
| `path=<path>` | Literal path (supports `<Tab>` file completion) |
| `<any text>` | Verbatim text |

## Common command examples

```vim
" Context-aware (recommended for everyday use)
:Open

" Open current buffer in file manager
:Open filemanager %

" Open URL under cursor in Firefox
:Open firefox cfile

" Open <cfile> path in a vertical split
:Open vsplit cfile

" Google-search the word under cursor
:Open browser

" Open an explicit path in a new tab
:Open tab path=~/dotfiles/init.lua

" Open current file in the browser (file:// URL)
:Open browser %
```

## Platform dispatch summary

| Action | Windows | WSL | macOS | Linux |
|---|---|---|---|---|
| File manager | `explorer.exe /select,` | `explorer.exe` (via wslpath) | `open` / `open -R` | `xdg-open` / nautilus… |
| Browser (default) | `cmd /C start` | `wslview` / `cmd /C start` | `open` | `xdg-open` |
| GUI text editor | `notepad.exe` | `notepad.exe` | `open -e` (TextEdit) | `xdg-open` / gedit… |
| Detached spawn | `jobstart(detach)` | `jobstart(detach)` | `vim.system(detach)` | `vim.system(detach)` |

## Link listing (`:UrlView`)

`:Open viewer [kind] [scope] [options]` — wrappers `:UrlView` (kind=urls) and
`:MDLinksView` (kind=mdlinks) take `[scope] [options]` only.

| Kind | Keeps |
|---|---|
| `all` *(default)* | Everything |
| `urls` | Target is a URL — including `[text](https://…)` |
| `mdlinks` | Markdown-syntax links, whatever they point at |
| `files` | Target is a local file or directory |
| `paths` | Bare filesystem paths (needs `--paths`) |

| Scope | Scans |
|---|---|
| *(omitted)* / `%` | Current buffer |
| `cwd` | Every file under `getcwd()`, recursively |
| `buffers` | Every listed, loaded buffer |
| `<path>` | A file, or a directory tree |
| *(a range)* | `:'<,'>UrlView` — only those lines |

| Option | Values |
|---|---|
| `sort=` | `none` (default) · `file` · `kind` · `alpha` |
| `out=` | `picker` (default) · `table` · `csv` · `mdlinks` · `clipboard` · `echo` · `file:<path>` |
| `match=` | Lua pattern on the basename, e.g. `match=%.md$` |
| `--paths` | Also report existing filesystem paths |
| `--anchors` | Include `[x](#heading)` anchors (dropped by default) |
| `--dupes` | Keep duplicate targets |
| `--flat` | Do not recurse |

In the picker: whole line highlighted, `j`/`k` and arrows only, `<CR>` opens
(URL → browser, file → Neovim split, directory → file manager), `<Esc>`/`q`
closes.

```
:UrlView                                 URLs in this buffer → picker
:MDLinksView cwd                         every markdown link in the project
:Open viewer cwd sort=file out=table     everything, as a table
:Open viewer files cwd --paths           local targets, incl. bare paths
:UrlView cwd match=%.md$ out=mdlinks     doc URLs as markdown → clipboard
:UrlView % out=file:/tmp/links.md        write this buffer's URLs to a file
:'<,'>UrlView                            just the selection
```

## Lua API

```lua
local open = require("open")

open.open()                      -- context-aware default
open.open("browser")             -- explicit handler, auto scope
open.open("filemanager", "%")    -- explicit handler + scope
open.open("split", "cfile")      -- split on <cfile>
```

## Integrations

```lua
-- urlview.nvim (superseded by the built-in :UrlView — see docs/integrations.md):
-- route picked URLs through open.nvim's browser handler
require("open.integrations.urlview").setup()
```
