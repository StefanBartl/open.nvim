# open.nvim — Lua API

```lua
local open = require("open")

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

`require("open.viewer")` backs `:Open viewer` / `:UrlView` /
`:MDLinksView`, and each step is usable on its own.

```lua
local viewer = require("open.viewer")

-- Collect. Returns links, err.
local links = viewer.collect("cwd", {
  kind      = "urls",  -- "all" | "urls" | "mdlinks" | "files" | "paths"
  paths     = false,   -- also report existing filesystem paths
  unique    = true,    -- de-duplicate by target
  anchors   = false,   -- include bare "#heading" links
  recursive = true,
  match     = "%.md$", -- Lua pattern on the basename
})

-- Or a line range of the current buffer:
local sel = viewer.collect(nil, { range = true, line1 = 10, line2 = 20 })

viewer.filter(links, "mdlinks")   -- filter an already-collected list
viewer.sort(links, "file")        -- "none" | "file" | "kind" | "alpha"
viewer.kinds()                    -- every valid filter token

local labels = viewer.labels(links, 100)  -- aligned, width-capped picker rows
local headers, rows = viewer.rows(links)  -- for a table/CSV renderer
local md = viewer.as_markdown(links)      -- "[label](target)" per line

viewer.open(links[1])             -- browser for a URL, split for a file

-- Everything at once, exactly as the user commands do it:
viewer.run({ kind = "urls", scope = "cwd", sort = "file", out = "table" })
```

Each link is an `OpenNvim.Viewer.Link`:

```lua
{
  target     = "/repo/lua/init.lua",  -- resolved: a URL, or an absolute path
  raw_target = "../../lua/init.lua",  -- exactly as written in the source
  kind       = "mdlink",              -- "url" | "mdlink" | "path"
  is_url     = false,                 -- true when a browser can open it
  is_anchor  = false,                 -- true for a bare "#heading"
  display    = "[init](../../lua/init.lua)",
  text       = "init",                -- label, for markdown links only
  lnum       = 12,                    -- 1-based line in its file/buffer
  col        = 4,                     -- 0-based byte column
  file       = "/repo/docs/a.md",     -- absolute source path, when known
  bufnr      = nil,                   -- source buffer, when it came from one
}
```

`kind` is syntactic and `is_url` is semantic; filtering on the latter is what
makes `urls` include `[text](https://…)`.

The scope/render/sink primitives underneath are
[`lib.nvim.harvest`](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/harvest/README.md)
and are reusable outside open.nvim. The picker is
[`lib.nvim.ui.kit.chooser`](https://github.com/StefanBartl/lib.nvim).

See [docs/commands.md](commands.md) for the full list of handlers and scope
tokens, and [docs/configuration.md](configuration.md) for `setup()` options.
