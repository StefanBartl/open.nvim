# Core

Dispatch and configuration surfaces that apply across every handler, rather
than belonging to any one of them.

## Context-aware dispatch

`:Open` with no explicit target figures out what you mean from where your
cursor is. In a Neo-tree, nvim-tree, or netrw buffer it takes the node under
the cursor; otherwise it looks at `<cfile>`, `<cWORD>`, a visual selection,
and the buffer path, in that priority order, and decides between the
configured file-manager handler and the configured browser handler based on
whether the candidate text looks like a URL.

- **Module:** `open/context.lua` (`gather`, `resolve`, `default_target`),
  `open/init.lua` (`M.open`)
- **Usercmds:** [`../BINDINGS.md#usrcmds`](../BINDINGS.md#usrcmds)
- **Config:** `opts.default_filemanager` (default `"filemanager"`),
  `opts.default_browser` (default `"browser"`)

## Scope tokens, including the git scope

An explicit 2nd argument to `:Open` bypasses the context heuristic entirely:
`%` (buffer path), `cfile` (text under the cursor), `cwd` (Neovim's working
directory), `git` (nearest Git root via `git rev-parse --show-toplevel`),
`path=<path>` (literal path), or a named scope keyword. `git` is resolved
with its own shell-out and returns `nil` (nothing to open) outside a Git
repo rather than falling back to a guess.

- **Module:** `open/context.lua` (`M.resolve`, `resolve_git_root`)
- **Docs:** [`docs/commands.md`](../commands.md#scope-2nd-argument)

## Per-invocation context cache

`open.context.with_cache()` wraps one `:Open` invocation so that every
nested `M.resolve()` call which gathers its own signals (rather than being
handed a pre-gathered `signals` table) reuses the same read of editor state
instead of re-reading `<cfile>`/`<cWORD>`/tree-node/visual-selection/buffer
path multiple times per command. The cache is invalidated as soon as the
outermost `with_cache()` call returns, so it never leaks stale signals
across separate `:Open` invocations.

- **Module:** `open/context.lua` (`M.with_cache`, `M.gather`)

## Debug mode

`setup({ debug = true })` logs every context-gather and dispatch step to
`:messages` — the raw signals `M.gather()` collected, and what `M.resolve()`
decided to open (or why it resolved to nothing) for the given scope/target.
Off by default; adds no overhead to `:messages` when disabled since the
logging call is gated by `M.is_debug()` before formatting the message.

- **Module:** `open/context.lua` (`debug_log`), `open/config/init.lua`
  (`M.is_debug`)
- **Config:** `opts.debug` (default `false`)

## Handler-choice picker

Opt-in `vim.ui.select` prompt for a no-target `:Open` when more than one
handler would plausibly apply to the current context (e.g. cursor on a URL:
browser or notepad; cursor on an existing file path: file manager, split,
vsplit, tab). Off by default, so `:Open` with no picker configured keeps
always picking a single handler deterministically. Any `vim.ui.select`
override (telescope-ui-select, fzf-lua, dressing.nvim) is picked up
automatically through `respect_override = true`; `lib.nvim.ui.kit`'s own
themed chooser is used otherwise. An explicit target (`:Open browser`,
`open.open("browser")`) always bypasses the picker.

- **Module:** `open/picker.lua` (`M.select`), `open/context.lua`
  (`M.candidate_targets`)
- **Config:** `opts.picker.enabled` (default `false`)

## Custom handlers via setup()

`opts.custom_handlers` registers additional `OpenNvim.Handler` entries
(`key`, `desc`, `run(ctx)`) straight from `setup()`, without calling
`require("open.registry").register()` directly. They are registered after
the built-in handler modules listed in `opts.handlers`, so a `key` reused
here overwrites a built-in handler of the same name (with a warning, not
silently).

- **Module:** `open/registry.lua` (`M.register`), `open/init.lua`
  (`M.setup`)
- **Config:** `opts.custom_handlers` (default `{}`)

## Keymap config

`setup()` accepts an optional `keymaps` table with exactly three recognized
keys — `open_default`, `open_browser`, `open_manager` — that register a
normal-mode keymap for a fixed `:Open` / `:Open browser` / `:Open
filemanager` invocation. No default keymaps are registered; an unrecognized
key warns and registers nothing.

- **Module:** `open/bindings/keymaps.lua` (`M.register`)
- **Config:** `opts.keymaps` (default `{}`)
- **Keymaps:** [`../BINDINGS.md#keymaps`](../BINDINGS.md#keymaps)

## Built-in scope keywords

Named shortcuts to commonly edited config files, usable as the scope
argument to any handler (`:Open split zshrc`, `:Open default MY_ROADMAP`).
Covers shell profiles, editor configs, terminal emulators, git, SSH,
package-manager RC files, and system files. Several resolve dynamically
(`pwsh_profile` shells out to read the real `$PROFILE`; `gitignore_global`
reads actual `git config` values) rather than being static paths, and those
resolvers only run when the keyword is actually used.

- **Module:** `open/keywords.lua` (`M.builtin`)
- **Config:** `opts.builtin_keywords` (default `true`), `opts.keywords`
  (user overrides/additions, default `{}`)
- **Docs:** [`docs/keywords.md`](../keywords.md)

## Health check

`:checkhealth open` reports the Neovim version, `vim.system` availability,
`lib.nvim` presence (`:Open` itself is built on
`lib.nvim.usercmd.composer`), detected platform, per-platform tool
availability, and the full list of currently registered handlers with their
descriptions.

- **Module:** `open/health.lua` (`M.check`)
- **Usercmds:** `:checkhealth open`
