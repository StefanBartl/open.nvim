# open.nvim — Bindings

Full inventory of user commands, keymaps, and autocmds registered by
open.nvim. See [lua/open/bindings/](../lua/open/bindings/) for the
source.

## Table of content

  - [Usrcmds](#usrcmds)
  - [Keymaps](#keymaps)
  - [Autocmds](#autocmds)

---

## Usrcmds

Built via [`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim)
with `<Tab>` completion, defined in
[lua/open/bindings/usrcmds.lua](../lua/open/bindings/usrcmds.lua).

| Command | Registered in |
|---|---|
| `:Open [target] [scope]` | [lua/open/bindings/usrcmds.lua](../lua/open/bindings/usrcmds.lua) |
| `:Open viewer [kind] [scope] [options]` | [lua/open/bindings/usrcmds.lua](../lua/open/bindings/usrcmds.lua) |
| `:UrlView [scope] [options]` | Shallow wrapper pinning `kind=urls`; name from `viewer.commands.urls`, `false` disables it |
| `:MDLinksView [scope] [options]` | Shallow wrapper pinning `kind=mdlinks`; name from `viewer.commands.mdlinks` |

`:Open` tab-completion:
- 1st arg (`target`) → all registered handler keys (see `:Open` in the
  [README](../README.md#command-reference)).
- 2nd arg (`scope`) → `%`, `cfile`, `path=<file completion>`, all named scope
  keywords, then general file completion.

`:Open viewer` tab-completion:
- 1st arg → kinds (`all`, `urls`, `mdlinks`, `files`, `paths`) **and** scopes
  (`%`, `cwd`, `buffers`, files). The handler disambiguates: a token that
  names a kind is one, anything else is the scope.
- 2nd arg (`scope`) → `%`, `cwd`, `buffers`, then general file completion.
- `sort=` → `none`, `file`, `kind`, `alpha`.
- `out=` → `picker`, `table`, `clipboard`, `mdlinks`, `csv`, `echo`, `file:`.
- Flags → `--paths`, `--anchors`, `--dupes`, `--flat`.

The wrapper commands pin the kind, so their single positional is always the
scope. All of them accept a range.

`viewer` is a reserved handler key: `:Open viewer` matches the literal
subcommand route before the flat `:Open [target]` grammar sees it, so a
handler registered under that key would be unreachable.

See [docs/commands.md](commands.md) for the full command reference and scope
tokens.

## Keymaps

None by default. `setup()` accepts an optional `keymaps` table to register
fixed, common invocations without writing `vim.keymap.set` yourself:

```lua
require("open").setup({
  keymaps = {
    open_default = "<leader>oo",  -- :Open
    open_browser = "<leader>ob",  -- :Open browser
    open_manager = "<leader>of",  -- :Open filemanager
  },
})
```

Registered in [lua/open/bindings/keymaps.lua](../lua/open/bindings/keymaps.lua).
An unrecognized key in `keymaps` warns and registers nothing. You can still
map `:Open` (or any other invocation) yourself instead:

```lua
vim.keymap.set("n", "<leader>oo", "<Cmd>Open<CR>")
```

## Autocmds

None.
