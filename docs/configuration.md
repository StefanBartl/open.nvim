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
    "terminal",
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

  -- User-defined handlers, registered in addition to the built-in ones
  -- listed in `handlers` above. Each entry is a full OpenNvim.Handler.
  custom_handlers = {
    -- {
    --   key  = "zathura",
    --   desc = "Open PDF in Zathura",
    --   run  = function(ctx)
    --     return require("open.util").run_detached({ "zathura", ctx.text }, "zathura")
    --   end,
    -- },
  },

  -- Optional keymaps for common invocations. Empty by default (no default
  -- keymaps are registered). Valid keys: open_default, open_browser,
  -- open_manager. Values are the {lhs} passed to vim.keymap.set().
  keymaps = {
    -- open_default = "<leader>oo",  -- :Open
    -- open_browser = "<leader>ob",  -- :Open browser
    -- open_manager = "<leader>of",  -- :Open filemanager
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

## `custom_handlers`

Register your own handlers directly from `setup()` instead of calling
`require("open.registry").register()` yourself. Each entry is a full
`OpenNvim.Handler` — `key`, `desc`, and a `run(ctx)` function returning a
boolean. They are registered after the built-in `handlers` modules, so a
`key` here overrides a built-in handler of the same name.

```lua
require("open").setup({
  custom_handlers = {
    {
      key  = "zathura",
      desc = "Open PDF in Zathura",
      run  = function(ctx)
        return require("open.util").run_detached({ "zathura", ctx.text }, "zathura")
      end,
    },
  },
})
```

## `keymaps`

None registered by default. Set any of these to a keymap `lhs` to register a
normal-mode mapping for that fixed invocation:

| Key | Triggers |
|---|---|
| `open_default` | `:Open` (context-aware default) |
| `open_browser` | `:Open browser` |
| `open_manager` | `:Open filemanager` |

```lua
require("open").setup({
  keymaps = {
    open_default = "<leader>oo",
    open_browser = "<leader>ob",
    open_manager = "<leader>of",
  },
})
```

An unrecognized key warns and is ignored. For anything not covered by these
three fixed targets, map `:Open ...` yourself — see
[docs/BINDINGS.md](BINDINGS.md#keymaps).

## `filemanager`

| Key | Default | Meaning |
|---|---|---|
| `reveal` | `true` | Reveal a file (select it in its parent directory) instead of navigating into that directory. |

```lua
require("open").setup({
  filemanager = { reveal = false },
})
```

Directories are always navigated into, regardless of `reveal` — there is
nothing to "select" for a directory target. Only Windows Explorer and
macOS Finder distinguish reveal from navigate at the OS level; on Linux the
handler passes the file's parent directory to the file manager instead of
the file itself when `reveal = false`.

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
