# Contributing to open.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/open.nvim/issues); pull requests
very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it
to the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/open.nvim")
require("open").setup({})
```

[lib.nvim](https://github.com/StefanBartl/lib.nvim) has to be on the runtime
path too — the `:Open` command layer is built on it. Nothing else is required;
everything a handler needs is resolved from the platform at runtime.

Test on more than one platform where you can. This plugin's whole job is
crossing the boundary out of the editor, and that boundary is different on
Linux, macOS, native Windows and WSL — most of the bugs live exactly there.

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation, `.stylua.toml` decides
  the rest.
- **Cross-platform dispatch is lib.nvim's, not this plugin's.**
  `lib.nvim.cross.open_default` owns extension and scheme dispatch, including
  WSL → Windows path translation. A handler that reimplements it will disagree
  with the office redirect, which uses the shared one.
- **A missing tool is a message, not an error.** Every handler resolves its
  executable at runtime; if it is not there, say which one and stop. Nothing
  may throw at `setup()` because a browser is not installed.
- **A handler that cannot run on this platform refuses.** `safari` is
  registered everywhere and declines outside macOS. Registering conditionally
  would make `<Tab>` completion silently differ between machines, which is
  worse than an honest refusal.
- **Say why, when nothing opened.** The most common report about a plugin like
  this is "it did nothing". A handler that finds no target, or an unresolvable
  scope, reports that — and `:checkhealth open` has to be able to show the same
  thing without a target present.
- **Scopes are resolved in one place.** The second argument — `%`, `cfile`,
  `cwd`, a keyword, or the heuristic — is parsed once and handed to the
  handler as a resolved value. A handler never re-reads the cursor.
- **The office redirect stays a `BufReadCmd`.** It has to fire on any read of a
  matching path — `:e`, `gf`, a picker, a tree plugin's `<CR>` — not only on
  `:Open default`.
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, with
  completion over both arguments.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/open/handlers/` | One file per destination: `default`, `browser`, `filemanager`, `notepad`, `terminal`, `image`, `nvim_internal` |
| `lua/open/viewer/` | The link listing and its scanner: buffer, selection, directory or project, then the picker and the export modes |
| `lua/open/integrations/` | `menu.lua` (nvzone/menu entries), `telescope.lua`, `urlview.lua` |
| `lua/open/bindings/` | `usrcmds.lua` — the `:Open` route tree and completion — and `keymaps.lua` |
| `lua/open/office_open.lua` | The `BufReadCmd` redirect for binary office documents |
| `lua/open/config/` | `DEFAULTS.lua` and `setup()` validation |
| `lua/open/@types/` | Shared type definitions |
| `doc/`, `docs/` | The vimdoc, and everything the README links to |
| `TESTS/` | The spec suite |

## Adding a handler

1. Add the module under `lua/open/handlers/`, taking an already-resolved
   target. It does not look at the cursor and it does not parse a scope.
2. Dispatch through `lib.nvim.cross.open_default` if the OS should decide;
   only reach for a platform-specific command when the destination genuinely is
   one specific program.
3. Resolve the executable at runtime, and report the missing one by name rather
   than failing silently.
4. If it cannot work on a platform, register it anyway and refuse there — see
   the ground rules.
5. Register it in the handler table so `<Tab>` completion and
   `:checkhealth open`'s registered-handlers section pick it up without a
   second list.
6. Add a spec under `TESTS/`.
7. Document it in [`cheatsheet.md`](cheatsheet.md),
   [`FEATURES/HANDLERS.md`](FEATURES/HANDLERS.md) and
   [`commands.md`](commands.md).

## Adding a keyword

Named scopes — the shortcuts for config files you open often — live in one
table and are documented in [`keywords.md`](keywords.md). Add both, or the
completion and the documentation drift apart. A keyword whose target does not
exist on a machine resolves to nothing and says so; it is not an error.

## Tests

`TESTS/` is a headless spec suite.

```
nvim --headless -u NONE -c "set rtp+=." -c "set rtp+=../lib.nvim" \
  -c "luafile TESTS/run.lua" -c "qa!"
```

Exit 0 is a pass; lib.nvim is expected as a sibling checkout.
[GitHub Actions](../.github/workflows/ci.yml) runs it plus stylua and luacheck
on every push and pull request to `main`.

Handlers that would actually launch something are exercised through the
dispatch layer rather than by opening a browser in CI — keep it that way when
adding one.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why — and say which
   platforms you tested on.
