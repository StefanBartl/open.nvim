> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

# open.nvim

```
 ██████╗ ██████╗ ███████╗███╗   ██╗
██╔═══██╗██╔══██╗██╔════╝████╗  ██║
██║   ██║██████╔╝█████╗  ██╔██╗ ██║
██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║
╚██████╔╝██║     ███████╗██║ ╚████║
 ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝
                              .nvim
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows%20%7C%20WSL-lightgrey)
[![CI](https://github.com/StefanBartl/open.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/open.nvim/actions/workflows/ci.yml)

Open files, URLs and paths from anywhere in Neovim, with one command.

`:Open [target] [scope]` routes the thing under your cursor — a path, a URL, or
plain text — to the right destination, and it goes the other way too:
`:Open viewer` lists every link in a buffer, a selection or the whole project
and hands you a picker.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Integrations](#integrations)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Cheatsheet](docs/cheatsheet.md) — everything on one screen: every handler, the scope tokens, the platform dispatch, and common examples.
- [Features](docs/FEATURES/README.md) — one page per area: [the core](docs/FEATURES/CORE.md), [the handlers](docs/FEATURES/HANDLERS.md), [the viewer](docs/FEATURES/VIEWER.md).
- [Installation](docs/installation.md) — requirements, and a spec per plugin manager.
- [Configuration](docs/configuration.md) — every `setup()` option, with the full defaults printed out.
- [Command reference](docs/commands.md) — the two command families in full, and what each argument does.
- [Workflow](docs/WORKFLOW.md) — how the commands combine day to day, `:Open viewer` against a direct handler, and the traps.
- [Built-in keywords](docs/keywords.md) — named scope shortcuts for shell, editor, git, SSH and other config files, and how to add your own.
- [Lua API](docs/api.md) — every function a config or another plugin can call.
- [Bindings](docs/BINDINGS.md) — every user command, keymap and autocommand this plugin registers.
- [Integrations](docs/integrations.md) — which other plugins this reaches, which it supersedes, and what changes when one is absent.
- [Health check](docs/health-check.md) — what `:checkhealth open` reports, and how to read it.
- [Contributing](docs/CONTRIBUTING.md) — ground rules, project layout, and how to add a handler.

`:help open` is the same reference inside the editor.

---

## What it does

Opening something outside the editor is a small problem that fragments into
many small answers: `gx` for URLs, `netrw` for a directory, a shell command for
the file manager, and nothing at all for "the thing under my cursor, in the
right application". This plugin is the one dispatcher over all of them.

| Area | Does |
| --- | --- |
| **One command** | `:Open [target] [scope]` — the target names the destination, the scope names what to send there; both complete with `<Tab>` |
| **Destinations** | System default app, the browser (including named browsers), a GUI text editor, a terminal split rooted in the target's directory, an inline image viewer, or a Neovim split, vsplit or tab |
| **Context awareness** | It knows when you are in a Neo-tree, nvim-tree or netrw buffer and opens the node under the cursor directly, with no scope argument |
| **Office redirect** | Reading a `.docx` / `.xlsx` / `.pptx` — or a legacy or OpenDocument counterpart — opens the system app instead of loading garbled text into a buffer |
| **The viewer** | `:Open viewer`, with `:UrlView` and `:MDLinksView` as shortcuts, lists the links in a buffer, a selection, a directory or the project, then hands you a picker |
| **Export** | The same list as a Markdown table, as Markdown links, to the clipboard, or to a file |

Pick a URL in the viewer and it opens in your browser; pick a Markdown link and
the document opens in a Neovim split.

---

## Around it

> **[insights.nvim](https://github.com/StefanBartl/insights.nvim)** — for
> understanding a project's structure *before* opening files in it: who imports
> what, which imports are unused, where the symbols are.
>
> **[markdown.nvim](https://github.com/StefanBartl/markdown.nvim)** — the
> Markdown side of the same cursor question, with its own dispatcher over
> anchors, images and headings inside a document.
>
> **[images.nvim](https://github.com/StefanBartl/images.nvim)** — draws an
> image in the editor rather than handing it to the system viewer; open.nvim
> uses it when it is there and falls back when it is not.
>
> All of the above are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the `:Open` command layer, with completion over both arguments |

Everything else is resolved from the platform at runtime — Explorer, Finder or
`xdg-open`, whichever browser is installed, the system default application.
Optional, each degrading to nothing when absent:

| | |
| --- | --- |
| `wslview` | Hands URLs to the Windows browser intact from inside WSL |
| [images.nvim](https://github.com/StefanBartl/images.nvim) | An inline image viewer instead of the system one |
| telescope.nvim | An opt-in picker source for the link viewer |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [Integrations](#integrations) |

`wslview` is declared in [docs/install.json](docs/install.json) and read by
lib.nvim's
[deps module](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/deps/README.md).
A popup says what is missing the first time `setup()` runs after installing;
`:Lib deps show open.nvim` repeats it, `:Lib deps install open.nvim` offers to
install it and asks first. Turn the popup off with
`vim.g.lib_nvim_deps_disable_first_run = true`, or for this plugin only with
`vim.g.lib_nvim_deps_disabled_plugins = { "open.nvim" }`.

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/open.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  cmd = { "Open", "UrlView", "MDLinksView" },
  opts = {},
}
```

`cmd` is enough: everything this plugin does starts with one of the three
commands, so there is nothing to load before you ask for it. The one exception
is the office auto-redirect, which needs the plugin loaded to catch the read —
[docs/installation.md](docs/installation.md) has that variant, and the other
plugin managers.

---

## Quickstart

Put the cursor on a path or a URL and let it decide where that belongs:

```vim
:Open
```

With no arguments it resolves the context itself — a tree node opens in the
file manager, a URL in the browser, a path in the sensible place for a path.
Then, when you want to say where it goes:

```vim
:Open browser %       " the current file in the browser, as a file:// URL
:Open split cfile     " the path under the cursor, in a split
:Open terminal %      " a terminal split rooted in this file's directory
```

And the other direction — the links in a buffer or the whole project:

```vim
:UrlView                              " URLs in this buffer, pick one to open
:MDLinksView cwd                      " every Markdown link in the project
:Open viewer cwd sort=file out=table  " all of it, as a Markdown table
```

Verify your setup any time with:

```vim
:checkhealth open
```

---

## What you get with the defaults

| Target | Does |
| --- | --- |
| *(omitted)* | Context-aware: tree node → file manager, URL → browser, path → the sensible place |
| `default` | The system default application, like a double-click |
| `browser` | A URL or text to the default browser; plain text becomes a search |
| `chrome`, `chromium`, `firefox`, `edge`, `brave`, `opera`, `safari` | A named browser instead of the default |
| `filemanager` | Explorer, Finder, or `xdg-open` |
| `notepad` / `editor` | Text through a temporary `.txt` into the GUI editor |
| `split` / `vsplit` / `tab` | A file path into Neovim |
| `terminal` | A terminal split in that directory — a file resolves to its parent |
| `viewer` | The link listing, with a picker and the export modes |

The second argument is the scope: `%` for the current file, `cfile` for the
path under the cursor, `cwd` for the working directory, a
[named keyword](docs/keywords.md) for a config file you open often, or nothing
at all for the heuristic. Both arguments complete with `<Tab>`; the full table
is [docs/cheatsheet.md](docs/cheatsheet.md).

---

## Integrations

### Context menu

`open.integrations.menu` contributes context-aware entries — Open, Open in
Browser, Reveal in File Manager, Open in Terminal, List Links Here — in the
shape [nvzone/menu](https://github.com/nvzone/menu) expects. open.nvim has
**no** dependency on `menu` and never opens a context menu itself; a host,
typically your own `<RightMouse>` dispatcher, has to compose these entries into
its own menu for them to ever be shown. Each entry self-gates to the resolved
cursor context, so the menu never offers something that would fail on click —
see [docs/integrations.md](docs/integrations.md#nvzonemenu-context-menu).

### File trees and pickers

Neo-tree, nvim-tree and netrw buffers are recognized directly: `:Open` with no
scope takes the node under the cursor. telescope.nvim can be registered as a
source for the link viewer, and `urlview.nvim` is superseded by the built-in
`:UrlView` rather than wired to it — [docs/integrations.md](docs/integrations.md)
says what changes when any of them is absent.

---

## Health check

```vim
:checkhealth open
```

Seven sections: the core, lib.nvim, the detected platform, which executables
resolved, the office auto-redirect, the registered handlers, and the declared
tools. The platform and executables sections are the ones to read when a
handler opens nothing — [docs/health-check.md](docs/health-check.md) says how.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the
project layout, including where a new handler plugs in.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/open.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/open.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
