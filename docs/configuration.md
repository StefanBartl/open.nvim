# open.nvim — Configuration

Full defaults:

```lua
require("open").setup({
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

  -- `:Open viewer [kind]` — list links in a scope.
  viewer = {
    -- Standalone wrapper commands, one per filter. false = do not register.
    commands = {
      urls    = "UrlView",      -- only browser-openable targets
      mdlinks = "MDLinksView",  -- only markdown-syntax links
      all     = false,          -- everything; use `:Open viewer` instead
    },
    sort           = "none",      -- "none" | "file" | "kind" | "alpha"
    output         = "picker",    -- "picker" | "table" | "clipboard" | "mdlinks" | "csv"
    mdlinks_output = "clipboard", -- sink for `out=mdlinks`
    open_file      = "split",     -- handler for a picked local file
  },
})
```

See [docs/keywords.md](keywords.md) for the full list of built-in keywords and
how to define your own.

## `viewer`

| Key | Default | Meaning |
|---|---|---|
| `commands.urls` | `"UrlView"` | Command listing URL targets. `false` to skip. |
| `commands.mdlinks` | `"MDLinksView"` | Command listing markdown links. `false` to skip. |
| `commands.all` | `false` | Command listing everything. Off by default — `:Open viewer` already covers it. |
| `sort` | `"none"` | Default ordering when no `sort=` is given. |
| `output` | `"picker"` | Default sink when no `out=` is given. |
| `mdlinks_output` | `"clipboard"` | Where `out=mdlinks` sends its result. |
| `open_file` | `"split"` | Handler used when a picked entry is a local file. Any registered handler key works — `"vsplit"`, `"tab"`, or even `"notepad"`. |

Every one of these is overridable per invocation — see
[docs/commands.md](commands.md#open-viewer--urlview--mdlinksview).

`open_file` is what makes following a markdown link land you in an editable
buffer rather than in your system file manager. URLs are unaffected: they
always go through `default_browser`.

If you still run [urlview.nvim](https://github.com/axieax/urlview.nvim), both
plugins want the `:UrlView` name and whichever registers last wins. Set
`viewer.commands.urls = false` to stay out of its way, or drop urlview.nvim
(see [docs/integrations.md](integrations.md)).
