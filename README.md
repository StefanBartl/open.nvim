<pre>
   ___                _  _         _
  / _ \ _ __   ___ _ \| |__  _  _(_)_ __
 | (_) | '_ \ / -_) ' \ '_ \ | | | | '  \
  \___/| .__/\___|_||_|_.__/ \_,_|_|_|_|_|
       |_|
        open files, URLs, and paths from anywhere in Neovim
</pre>

![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)
![Depends](https://img.shields.io/badge/depends-lib.nvim-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey)

---

A single `:Open [target] [scope]` command that routes the thing under your
cursor — path, URL, or plain text — to the right destination: system file
manager, browser (with named-browser support), GUI text editor, or Neovim
split/tab. Context-aware: knows when you are in a Neo-tree, nvim-tree, or
netrw buffer and opens the node under the cursor directly.

Built on [lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate
shared dependency.

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Command Reference](#command-reference)
- [Tab Completion](#tab-completion)
- [Lua API](#lua-api)
- [Health Check](#health-check)
- [Architecture](#architecture)

## Features

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

**Smart context resolution:**
- In a **Neo-tree / nvim-tree / netrw** buffer → opens the node under the cursor
- Cursor on a **URL** with no explicit target → falls back to `browser`
- Cursor on a **file path** → falls back to `filemanager`
- Visual selection → used as the target text

## Requirements

- Neovim 0.9+
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)
- Platform tools are optional but needed per handler (see `:checkhealth open_nvim`)

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/open.nvim",
  -- dir = vim.env.REPOS_DIR .. "/open.nvim",  -- local checkout
  cmd  = "Open",
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

## Configuration

Full defaults:

```lua
require("open_nvim").setup({
  command             = "Open",        -- user command name
  default_filemanager = "filemanager", -- handler used for paths when no target given
  default_browser     = "browser",     -- handler used for URLs when no target given

  -- Which handler modules to load. Remove entries to trim the command's
  -- tab-completion to only the handlers you actually use.
  handlers = {
    "filemanager",
    "browser",
    "notepad",
    "nvim_internal",
  },

  keymaps = {},  -- reserved for future keymap bindings
})
```

## Command Reference

```
:Open                          context-aware default (tree → filemanager, URL → browser)
:Open default                  open in the system default application (like double-click)
:Open filemanager              open current path/node in the system file manager
:Open browser                  open URL or text in the system default browser
:Open chrome                   open in Google Chrome
:Open firefox                  open in Mozilla Firefox
:Open edge                     open in Microsoft Edge
:Open safari                   open in Safari (macOS only)
:Open notepad                  copy text to a temp file and open in GUI editor
:Open editor                   alias for notepad
:Open split                    open file in a horizontal split
:Open vsplit                   open file in a vertical split
:Open tab                      open file in a new tab
```

### Scope (2nd argument)

| Scope | What is opened |
|---|---|
| *(omitted)* | Target-aware heuristic (tree node → cfile → buffer path or cWORD) |
| `%` | Current buffer's file path |
| `cfile` | `<cfile>` text under the cursor |
| `path=<path>` | Literal path (supports file completion after `path=`) |
| `<text>` | Anything else is used verbatim |

Examples:
```
:Open browser %                open current file in browser (file:// URL)
:Open filemanager cfile        open <cfile> path in file manager
:Open browser path=/tmp/x.md   open a specific file in browser
:Open split ~/.config/nvim/init.lua
```

## Tab Completion

```
:Open <Tab>           → all registered handler names
:Open browser <Tab>   → %  cfile  path=  <file completion>
:Open filemanager path=<Tab>   → file/directory completion after path=
```

## Lua API

```lua
local open = require("open_nvim")

-- Context-aware open (same as :Open with no args)
open.open()

-- Explicit handler
open.open("browser")

-- Handler + scope
open.open("filemanager", "%")       -- open current buffer in file manager
open.open("browser", "cfile")       -- open <cfile> in browser
open.open("split", "path=/tmp/x")   -- open explicit path in split
```

## Health Check

```
:checkhealth open_nvim
```

Reports:
- Neovim version and `vim.system` availability
- `lib.nvim.notify` presence
- Detected platform (Windows / WSL / macOS / Linux)
- Per-platform tool availability (explorer.exe, xdg-open, wslview, …)
- All registered handlers and their descriptions

---
