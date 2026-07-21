# open.nvim — Installation

## Table of content

- [Requirements](#requirements)
- [Installing](#installing)

## Requirements

- Neovim 0.9+
- [lib.nvim](https://github.com/StefanBartl/lib.nvim)
- Platform tools are optional but needed per handler (see `:checkhealth open`,
  documented in [docs/health-check.md](health-check.md))

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
