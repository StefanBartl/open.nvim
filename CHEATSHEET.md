# open.nvim — Cheatsheet

## All registered handlers

| Handler | Key | Description | Platform |
|---|---|---|---|
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

## Lua API

```lua
local open = require("open_nvim")

open.open()                      -- context-aware default
open.open("browser")             -- explicit handler, auto scope
open.open("filemanager", "%")    -- explicit handler + scope
open.open("split", "cfile")      -- split on <cfile>
```
