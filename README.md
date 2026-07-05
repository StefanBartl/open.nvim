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
![Depends](https://img.shields.io/badge/depends-lib.nvim-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey)

---

> Looking to understand a project's structure before opening files in it?
> Check out [project-insight.nvim](https://github.com/StefanBartl/project-insight.nvim).

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
- [Built-in Keywords](#built-in-keywords)
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

open.nvim only does anything once `:Open` is actually invoked, so it should be
loaded lazily on that command rather than eagerly at startup (`lazy = false`)
or on a UI event (`event = "VeryLazy"`) — those would just load the plugin
sooner for no benefit.

```lua
-- lazy.nvim
{
  "StefanBartl/open.nvim",
  cmd  = "Open",
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

```lua
-- packer
use {
  "StefanBartl/open.nvim",
  requires = { "StefanBartl/lib.nvim" },
  cmd = "Open",
  config = function()
    require("open_nvim").setup()
  end,
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

  -- Built-in named scope keywords (shell profiles, git, SSH, …).
  -- Set to false to disable all built-ins.
  builtin_keywords = true,

  -- User-defined scope keyword overrides / additions.
  -- Each value is a static path string or a function() → string|nil.
  keywords = {
    -- Override a built-in:
    -- zshrc = "~/dotfiles/.zshrc",

    -- Add your own shortcuts:
    -- MY_ROADMAP = "E:\\projects\\ROADMAP.md",
    -- MY_LOGO    = function() return vim.fn.expand("~/assets/logo.png") end,
  },
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
| `<keyword>` | Named scope keyword (see [Built-in Keywords](#built-in-keywords)) |
| `<text>` | Any other text is used verbatim |

Examples:
```
:Open browser %                   open current file in browser (file:// URL)
:Open filemanager cfile           open <cfile> path in file manager
:Open browser path=/tmp/x.md      open a specific file in browser
:Open split nvim_init             open your Neovim init.lua in a split
:Open tab zshrc                   open ~/.zshrc in a new tab
:Open split pwsh_profile          open PowerShell $PROFILE in a split
:Open default MY_ROADMAP          open a user keyword with the default app
```

## Built-in Keywords

Named scope aliases for commonly edited config files. Use them as the 2nd
argument to any handler: `:Open <handler> <keyword>`.

All keywords support tab-completion.

### Shell profiles

| Keyword | Path |
|---|---|
| `pwsh_profile` | PowerShell `$PROFILE` (all platforms, requires `pwsh` or `powershell`) |
| `zshrc` | `~/.zshrc` |
| `zprofile` | `~/.zprofile` |
| `bashrc` | `~/.bashrc` |
| `bash_profile` | `~/.bash_profile` |
| `profile` | `~/.profile` |
| `fish_config` | `~/.config/fish/config.fish` |
| `nushell_config` | `~/.config/nushell/config.nu` |

### Editor / IDE

| Keyword | Path |
|---|---|
| `nvim_init` | `~/AppData/Local/nvim/init.lua` (Win) · `~/.config/nvim/init.lua` (Unix) |
| `vimrc` | `~/.vimrc` |

### Terminal emulators & multiplexers

| Keyword | Path |
|---|---|
| `tmux_conf` | `~/.config/tmux/tmux.conf` or `~/.tmux.conf` |
| `wezterm_conf` | `~/.config/wezterm/wezterm.lua` or `~/.wezterm.lua` |
| `kitty_conf` | `~/.config/kitty/kitty.conf` |
| `alacritty_conf` | `.toml` preferred, `.yml` fallback |
| `starship_conf` | `~/.config/starship.toml` |

### Git

| Keyword | Path |
|---|---|
| `gitconfig` | `~/.gitconfig` |
| `gitignore_global` | `core.excludesFile` from git config, or `~/.gitignore_global` |
| `gitmessage` | `commit.template` from git config, or `~/.gitmessage` |

### SSH

| Keyword | Path |
|---|---|
| `ssh_config` | `~/.ssh/config` |
| `ssh_known_hosts` | `~/.ssh/known_hosts` |
| `ssh_authorized_keys` | `~/.ssh/authorized_keys` |

### Package managers & runtimes

| Keyword | Path |
|---|---|
| `npmrc` | `~/.npmrc` |
| `yarnrc` | `~/.yarnrc.yml` |
| `cargo_config` | `~/.cargo/config.toml` |
| `pip_conf` | `~/.config/pip/pip.conf` (Unix) · `%APPDATA%\pip\pip.ini` (Win) |
| `gemrc` | `~/.gemrc` |
| `curlrc` | `~/.curlrc` |

### System / misc

| Keyword | Path / Platform |
|---|---|
| `inputrc` | `~/.inputrc` (Readline config) |
| `hosts` | `/etc/hosts` (Unix) · `C:\Windows\System32\drivers\etc\hosts` (Win) |
| `docker_config` | `~/.docker/config.json` |
| `wsl_conf` | `/etc/wsl.conf` (WSL only) |
| `wslconfig` | `~/.wslconfig` (Windows only) |

### User-defined keywords

Add your own in `setup()`:

```lua
require("open_nvim").setup({
  keywords = {
    MY_ROADMAP = "E:\\projects\\ROADMAP.md",
    MY_LOGO    = "E:\\assets\\logo.png",
    -- dynamic resolver:
    MY_DATE_LOG = function()
      return vim.fn.expand("~/logs/") .. os.date("%Y-%m-%d") .. ".md"
    end,
  },
})
```

Then use them like any built-in: `:Open split MY_ROADMAP`, `:Open default MY_LOGO`.

To override a built-in, use the same key: `keywords = { zshrc = "~/dotfiles/.zshrc" }`.
To disable all built-ins: `builtin_keywords = false`.

## Tab Completion

```
:Open <Tab>                      all registered handler names
:Open browser <Tab>              %  cfile  path=  <keywords>  <file completion>
:Open split <Tab>                %  cfile  path=  <keywords>  <file completion>
:Open filemanager path=<Tab>     file/directory completion after path=
:Open split zsh<Tab>             → zshrc  zprofile  (keyword prefix filter)
```

## Lua API

```lua
local open = require("open_nvim")

-- Context-aware open (same as :Open with no args)
open.open()

-- Explicit handler
open.open("browser")

-- Handler + scope
open.open("filemanager", "%")         -- open current buffer in file manager
open.open("browser", "cfile")         -- open <cfile> in browser
open.open("split", "path=/tmp/x")     -- open explicit path in split
open.open("split", "nvim_init")       -- open Neovim init.lua in a split
open.open("tab",   "pwsh_profile")    -- open PowerShell profile in a tab
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
