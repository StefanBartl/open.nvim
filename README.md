> **Alpha stage — active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# open.nvim

```
   ___                _  _         _
  / _ \ _ __   ___ _ \| |__  _  _(_)_ __
 | (_) | '_ \ / -_) ' \ '_ \ | | | | '  \
  \___/| .__/\___|_||_|_.__/ \_,_|_|_|_|_|
       |_|
        open files, URLs, and paths from anywhere in Neovim
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-active%20development-blue)
[![CI](https://github.com/StefanBartl/open.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/open.nvim/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey)

---

> Looking to understand a project's structure before opening files in it?
> Check out [insights.nvim](https://github.com/StefanBartl/insights.nvim).

open.nvim gives you a single `:Open [target] [scope]` command that routes the
thing under your cursor — path, URL, or plain text — to the right
destination: system file manager, browser (with named-browser support), GUI
text editor, terminal split rooted in the target's directory, inline image
viewer (via images.nvim, with fallback), or a Neovim split/tab. It is
context-aware: it knows when you are in a Neo-tree, nvim-tree, or netrw
buffer and opens the node under the cursor directly, and it transparently
redirects reads of `.docx`/`.xlsx`/`.pptx` (and legacy/OpenDocument
counterparts) to their system app instead of showing garbage in a buffer.
Built on [lib.nvim](https://github.com/StefanBartl/lib.nvim) as a deliberate
shared dependency.

It also goes the other way: `:Open viewer` — with `:UrlView` and
`:MDLinksView` as shortcuts — lists the links in a buffer, a selection, a
directory, or the whole project, then hands you a picker. Pick a URL and it
opens in your browser; pick a markdown link and the document opens in a
Neovim split. Or export the lot as a markdown table, as markdown links, to
the clipboard, or to a file.

```
:UrlView                                 URLs in this buffer → pick one to open
:MDLinksView cwd                         every markdown link in the project
:Open viewer cwd sort=file out=table     everything, as a table
```

## Table of Contents

- [Quickstart](#quickstart)
- [Context Menu (optional)](#context-menu-optional)
- [Documentation](#documentation)

---

## Quickstart

Requires Neovim 0.9+ and [lib.nvim](https://github.com/StefanBartl/lib.nvim).

```lua
-- lazy.nvim
{
  "StefanBartl/open.nvim",
  cmd  = { "Open", "UrlView", "MDLinksView" },
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

```
:Open                context-aware default (tree → filemanager, URL → browser)
:Open browser %      open current file in the browser (file:// URL)
:Open split cfile    open <cfile> path under the cursor in a split
```

## Context Menu (optional)

`open.integrations.menu` contributes context-aware entries — Open, Open in
Browser, Reveal in File Manager, Open in Terminal, List Links Here — in the
shape [nvzone/menu](https://github.com/nvzone/menu) expects. open.nvim has
**no** dependency on `menu` and never opens a context menu itself; a host
(typically your own `<RightMouse>` dispatcher) has to compose these entries
into its own menu for them to ever be shown. See
[docs/integrations.md](docs/integrations.md#nvzonemenu-context-menu) for the
wiring and how entries self-gate to the resolved cursor context.

## Documentation

- [Features](docs/FEATURES/README.md) — handler catalog and smart context resolution.
- [Installation](docs/installation.md) — requirements and setup for lazy.nvim, packer, and others.
- [Configuration](docs/configuration.md) — all `setup()` options and their defaults.
- [Command Reference](docs/commands.md) — full `:Open` and `:Open viewer` commands, scope tokens, and tab-completion.
- [Workflow](docs/WORKFLOW.md) — day-to-day usage: scope/target resolution in practice, `:Open viewer` vs a direct handler, and other traps.
- [Built-in Keywords](docs/keywords.md) — named scope shortcuts for shell, editor, git, SSH, and more config files.
- [Lua API](docs/api.md) — calling open.nvim directly from Lua.
- [Integrations](docs/integrations.md) — urlview.nvim (superseded by the built-in `:UrlView`) and an opt-in telescope.nvim source.
- [Health Check](docs/health-check.md) — what `:checkhealth open` reports.
- [Declared external tools](docs/install.json) — the optional CLI tools (`wslview`, for handing URLs to the Windows browser intact from WSL) with why each matters. `:Lib deps show open.nvim` reports what's missing here, `:Lib deps install open.nvim` offers to install it — via [lib.nvim.deps](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/deps/README.md), which asks before it installs anything. A popup shows this once, the first time `setup()` runs after installing. Turn it off with `vim.g.lib_nvim_deps_disable_first_run = true` (every plugin) or `vim.g.lib_nvim_deps_disabled_plugins = { "open.nvim" }` (just this one).
- [Bindings](docs/BINDINGS.md) — full inventory of user commands, keymaps, and autocmds.

## License

MIT — see [LICENSE](LICENSE).
