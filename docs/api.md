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

See [docs/commands.md](commands.md) for the full list of handlers and scope
tokens, and [docs/configuration.md](configuration.md) for `setup()` options.
