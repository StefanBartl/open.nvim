# open.nvim — Configuration

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
    "default",
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

  -- `:Open urlview` / `:UrlView` — list links in a scope.
  urlview = {
    command        = "UrlView",  -- standalone wrapper command; false to skip it
    sort           = "none",     -- "none" | "file" | "kind" | "alpha"
    output         = "picker",   -- "picker" | "table" | "clipboard" | "mdlinks" | "csv"
    mdlinks_output = "clipboard",-- sink for `out=mdlinks`
  },
})
```

See [docs/keywords.md](keywords.md) for the full list of built-in keywords and
how to define your own.

## `urlview`

| Key | Default | Meaning |
|---|---|---|
| `command` | `"UrlView"` | Name of the standalone wrapper command. Set to `false` (or `""`) to register only `:Open urlview`. |
| `sort` | `"none"` | Default ordering when no `sort=` is given. |
| `output` | `"picker"` | Default sink when no `out=` is given. |
| `mdlinks_output` | `"clipboard"` | Where `out=mdlinks` sends its result. |

Every one of these is overridable per invocation — see
[docs/commands.md](commands.md#open-urlview--urlview).

If you still run [urlview.nvim](https://github.com/axieax/urlview.nvim), both
plugins want the `:UrlView` name and whichever registers last wins. Set
`urlview.command = false` to stay out of its way, or drop urlview.nvim (see
[docs/integrations.md](integrations.md)).
