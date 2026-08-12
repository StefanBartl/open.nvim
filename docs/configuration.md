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

  -- `filemanager` handler settings.
  filemanager = {
    reveal = true, -- false: navigate to a file's parent dir instead of selecting it
  },

  -- Redirect MS Office documents to the system default app on read (BufReadCmd),
  -- instead of loading them as a text buffer. Fires for :e, gf, pickers, and
  -- tree plugins alike — not just `:Open default`.
  office_open = {
    enabled    = true,
    extensions = { "doc", "docx", "xls", "xlsx", "ppt", "pptx" },
  },

  -- When true, logs every context-gather and dispatch step to :messages.
  debug = false,

  -- Handler-choice picker for ambiguous no-target invocations. Off by default.
  picker = { enabled = false },

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
| `command` | `nil` | Launcher override: a string (`"thunar"`) or an argv list (`{ "dolphin", "--select" }`). The resolved path is appended as the last argument and the built-in platform dispatch is skipped. |

```lua
require("open").setup({
  filemanager = { reveal = false },
})
```

Directories are always navigated into, regardless of `reveal` — there is
nothing to "select" for a directory target. Windows Explorer, macOS Finder,
and the select-capable Linux managers (nautilus, nemo, `dolphin --select`,
thunar, caja) distinguish reveal from navigate; with `reveal = false`, or
when none of those is installed, the file's parent directory is opened
instead. `xdg-open` is never handed a file when revealing — it would launch
that file's default *application* rather than a file manager.

The dispatch lives in `lib.nvim.cross.reveal_in_fm` and is shared with
filetree.nvim's `<leader>fm`, so platform fixes land in both at once.

## `office_open`

| Key | Default | Meaning |
|---|---|---|
| `enabled` | `true` | Install the `BufReadCmd` redirect. |
| `extensions` | `{"doc","docx","xls","xlsx","ppt","pptx"}` | Bare extensions (no dot) to redirect. |

```lua
require("open").setup({
  office_open = {
    enabled    = true,
    -- Add ODF formats too, for example:
    extensions = { "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "odp" },
  },
})
```

Reading a matching path — via `:e`, `gf`, a picker, or a tree plugin's
`<CR>` — hands it to the system default application (the same dispatch as
the `default` handler) instead of loading it as text, then wipes the empty
placeholder buffer Neovim created for the read. Set `enabled = false` to
turn this off entirely and get Neovim's normal (garbled) text-buffer
behavior back for these extensions.

## `debug`

```lua
require("open").setup({ debug = true })
```

Logs every `context.gather()`, `context.resolve()`, and `registry.dispatch()`
step to `:messages` via `lib.nvim.notify`, tagged `[open.context]` /
`[open.registry]`. Off by default. Useful for understanding why a given
`:Open` invocation resolved to the text it did.

## `picker`

```lua
require("open").setup({
  picker = { enabled = false },  -- default
})
```

When `enabled = true` and `:Open` (or `open.open()`) is called with **no
explicit target** and the current context has more than one meaningful
handler (see below), a `vim.ui.select` prompt lets you choose instead of
open.nvim silently picking one. Any `vim.ui.select` override —
telescope-ui-select, fzf-lua, dressing.nvim — is used automatically; the
built-in `vim.ui.select` otherwise.

Candidates by context:

| Context | Candidates |
|---|---|
| Tree-buffer node | `default_filemanager` only (no ambiguity, no prompt) |
| Looks like a URL | `default_browser`, `notepad` |
| `<cfile>` resolves to an existing path | `default_filemanager`, `split`, `vsplit`, `tab` |
| Anything else | `default_filemanager` only |

An explicit target (`:Open browser`, `open.open("browser")`) always bypasses
the picker, same as before this option existed.

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
