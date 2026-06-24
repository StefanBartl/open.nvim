# open.nvim — ROADMAP

Possible future features, in rough priority order.

---

## Table of content

  - [Near-term](#near-term)
    - [User-defined handlers via `setup()`](#user-defined-handlers-via-setup)
    - [`terminal` handler](#terminal-handler)
    - [Keymap bindings in config](#keymap-bindings-in-config)
  - [Medium-term](#medium-term)
    - [`brave` and `opera` browser handlers](#brave-and-opera-browser-handlers)
    - [`scope = "git"` — open Git root](#scope-git-open-git-root)
    - [Picker integration](#picker-integration)
    - [`reveal` option for filemanager handler](#reveal-option-for-filemanager-handler)
  - [Long-term / speculative](#long-term-speculative)
    - [Debug / verbose mode](#debug-verbose-mode)
    - [Context cache](#context-cache)
    - [`open_nvim.sources` plugin integration](#open_nvimsources-plugin-integration)

---

## Near-term

### User-defined handlers via `setup()`

Allow registering custom handlers directly from the config table without
needing to call `registry.register()` manually:

```lua
require("open_nvim").setup({
  custom_handlers = {
    {
      key  = "zathura",
      desc = "Open PDF in Zathura",
      run  = function(ctx)
        require("open_nvim.util").run_detached({ "zathura", ctx.text }, "zathura")
      end,
    },
  },
})
```

### `terminal` handler

Open a path in a new terminal split:

```
:Open terminal          → opens terminal in the directory of the current buffer
:Open terminal cfile    → opens terminal in <cfile>'s parent directory
```

### Keymap bindings in config

```lua
require("open_nvim").setup({
  keymaps = {
    open_default   = "<leader>oo",  -- :Open
    open_browser   = "<leader>ob",  -- :Open browser
    open_manager   = "<leader>of",  -- :Open filemanager
  },
})
```

---

## Medium-term

### `brave` and `opera` browser handlers

Additional named-browser handlers following the same `make_named_handler`
pattern already used for Chrome/Firefox/Edge.

### `scope = "git"` — open Git root

A special scope token that resolves the nearest `.git` parent directory
and passes it to the handler (useful with `filemanager`):

```
:Open filemanager git   → open project root in file manager
```

### Picker integration

When called without arguments and multiple meaningful targets are available,
show a telescope/fzf picker instead of making an automatic choice.

### `reveal` option for filemanager handler

Config option to control whether `filemanager` _reveals_ a file (selects it
in the parent directory) or _navigates_ to it (opens the directory):

```lua
filemanager = { reveal = true }  -- default true → /select, behaviour
```

---

## Long-term / speculative

### Debug / verbose mode

```lua
require("open_nvim").setup({ debug = true })
```

Logs every context-gather and dispatch step to `:messages`.

### Context cache

Cache the result of `gather()` for the duration of a single command
invocation so that `resolve()` calls within chained operations don't
re-read the editor state.

### `open_nvim.sources` plugin integration

Publish a telescope/fzf-lua source that lists all registered handlers with
live preview of what they would open for the current context.
