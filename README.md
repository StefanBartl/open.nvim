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

open.nvim gives you a single `:Open [target] [scope]` command that routes the
thing under your cursor — path, URL, or plain text — to the right
destination: system file manager, browser (with named-browser support), GUI
text editor, or a Neovim split/tab. It is context-aware: it knows when you
are in a Neo-tree, nvim-tree, or netrw buffer and opens the node under the
cursor directly. Built on [lib.nvim](https://github.com/StefanBartl/lib.nvim)
as a deliberate shared dependency.

## Quickstart

Requires Neovim 0.9+ and [lib.nvim](https://github.com/StefanBartl/lib.nvim).

```lua
-- lazy.nvim
{
  "StefanBartl/open.nvim",
  cmd  = "Open",
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

```
:Open                context-aware default (tree → filemanager, URL → browser)
:Open browser %      open current file in the browser (file:// URL)
:Open split cfile    open <cfile> path under the cursor in a split
```

## Documentation

- [Features](docs/features.md) — handler table and smart context resolution.
- [Installation](docs/installation.md) — requirements and setup for lazy.nvim, packer, and others.
- [Configuration](docs/configuration.md) — all `setup()` options and their defaults.
- [Command Reference](docs/commands.md) — full `:Open` command, scope tokens, and tab-completion.
- [Built-in Keywords](docs/keywords.md) — named scope shortcuts for shell, editor, git, SSH, and more config files.
- [Lua API](docs/api.md) — calling open.nvim directly from Lua.
- [Integrations](docs/integrations.md) — urlview.nvim integration.
- [Health Check](docs/health-check.md) — what `:checkhealth open_nvim` reports.
- [Bindings](docs/BINDINGS.md) — full inventory of user commands, keymaps, and autocmds.
- [Roadmap](docs/ROADMAP.md) — planned features.
