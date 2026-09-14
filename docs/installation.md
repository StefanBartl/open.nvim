# open.nvim — Installation

## Table of content

- [Requirements](#requirements)
- [Installing](#installing)

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
| [ui.nvim](https://github.com/StefanBartl/ui.nvim) | Backs the handler-choice picker (`opts.picker.enabled = true`) and the `open.integrations.menu` context-menu entries |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [integrations.md](integrations.md) |

`wslview` is declared in [install.json](install.json) and read by lib.nvim's
[deps module](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/deps/README.md).
A popup says what is missing the first time `setup()` runs after installing;
`:Lib deps show open.nvim` repeats it, `:Lib deps install open.nvim` offers to
install it and asks first. Turn the popup off with
`vim.g.lib_nvim_deps_disable_first_run = true`, or for this plugin only with
`vim.g.lib_nvim_deps_disabled_plugins = { "open.nvim" }`.

See `:checkhealth open`, documented in [health-check.md](health-check.md), for
which platform tools resolved.

## Installing

open.nvim only does anything once `:Open` is actually invoked, so it should be
loaded lazily on that command rather than eagerly at startup (`lazy = false`)
or on a UI event (`event = "VeryLazy"`) — those would just load the plugin
sooner for no benefit.

```lua
-- lazy.nvim
{
  "StefanBartl/open.nvim",
  cmd  = { "Open", "UrlView", "MDLinksView" },
  dependencies = { "StefanBartl/lib.nvim" },
  opts = {},
}
```

```lua
-- packer
use {
  "StefanBartl/open.nvim",
  requires = { "StefanBartl/lib.nvim" },
  cmd = { "Open", "UrlView", "MDLinksView" },
  config = function()
    require("open").setup()
  end,
}
```

See [docs/configuration.md](configuration.md) for all available `setup()` options.
