# open.nvim — Lua API

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

## Link listing

`require("open_nvim.urlview")` backs `:Open urlview` / `:UrlView`, and each
step is usable on its own.

```lua
local urlview = require("open_nvim.urlview")

-- Collect. Returns links, err.
local links = urlview.collect("cwd", {
  paths     = false,   -- also report existing filesystem paths
  unique    = true,    -- de-duplicate by target
  recursive = true,
  match     = "%.md$", -- Lua pattern on the basename
})

-- Or a line range of the current buffer:
local sel = urlview.collect(nil, { range = true, line1 = 10, line2 = 20 })

urlview.sort(links, "file")        -- "none" | "file" | "kind" | "alpha"

local headers, rows = urlview.rows(links)   -- for a table/CSV renderer
local md = urlview.as_markdown(links)       -- "[label](target)" per line

urlview.open(links[1])             -- dispatch through the configured handler

-- Everything at once, exactly as the user command does it:
urlview.run({ scope = "cwd", sort = "file", out = "table" })
```

Each link is an `OpenNvim.UrlView.Link`:

```lua
{
  target  = "https://example.com",  -- the thing to open
  kind    = "url",                  -- "url" | "mdlink" | "path"
  display = "https://example.com",  -- as it appeared in the source
  text    = nil,                    -- label, for markdown links only
  lnum    = 12,                     -- 1-based line in its file/buffer
  col     = 4,                      -- 0-based byte column
  file    = "/repo/README.md",      -- absolute source path, when known
  bufnr   = nil,                    -- source buffer, when it came from one
}
```

The scope/render/sink primitives underneath are
[`lib.nvim.harvest`](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/harvest/README.md)
and are reusable outside open.nvim.

See [docs/commands.md](commands.md) for the full list of handlers and scope
tokens, and [docs/configuration.md](configuration.md) for `setup()` options.
