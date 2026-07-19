# open.nvim — Bindings

Full inventory of user commands, keymaps, and autocmds registered by
open.nvim. See [lua/open_nvim/bindings/](../lua/open_nvim/bindings/) for the
source.

## Table of content

  - [Usrcmds](#usrcmds)
  - [Keymaps](#keymaps)
  - [Autocmds](#autocmds)

---

## Usrcmds

One command, `:Open [target] [scope]` (built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion), defined in
[lua/open_nvim/bindings/usrcmds.lua](../lua/open_nvim/bindings/usrcmds.lua).

| Command | Registered in |
|---|---|
| `:Open [target] [scope]` | [lua/open_nvim/bindings/usrcmds.lua](../lua/open_nvim/bindings/usrcmds.lua) |

Tab-completion:
- 1st arg (`target`) → all registered handler keys (see `:Open` in the
  [README](../README.md#command-reference)).
- 2nd arg (`scope`) → `%`, `cfile`, `path=<file completion>`, all named scope
  keywords, then general file completion.

See [README.md](../README.md#command-reference) for the full command
reference and scope tokens.

## Keymaps

None. open.nvim ships with no default keymaps and no `keymaps` config option
— use `:Open ...` directly, or map it yourself:

```lua
vim.keymap.set("n", "<leader>oo", "<Cmd>Open<CR>")
```

Built-in keymap bindings (configurable via `setup()`) are tracked as a
near-term idea in [docs/ROADMAP.md](ROADMAP.md#keymap-bindings-in-config).

## Autocmds

None.
