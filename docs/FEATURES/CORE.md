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

`setup()` accepts an optional `keymaps` table registering a normal-mode
keymap for a fixed `:Open [target]` invocation. No default keymaps are
registered; an unrecognized key warns, names the accepted keys, and registers
nothing.

**The accepted keys come from the handler registry, not a list in
`keymaps.lua`** (changed 2026-08-24, closing the flag/option audit's entry
about `:Open split` and `:Open terminal` having no keymap option). Before
this it was a hardcoded three — `open_default`, `open_browser`,
`open_manager` — which is exactly why six perfectly ordinary targets had no
option: the list had not grown with the handlers. Now `open_<handler key>`
works for every registered handler, a `custom_handlers` one included.

Reading the live registry rather than a static list also means a target
switched off via `opts.handlers` is rejected here, instead of being mapped to
a command that would fail at press time. `open_manager` stays as a historical
alias of `open_filemanager`; `open_default` keeps meaning the bare `:Open`
even though the registry has its own `default` handler, since both end up at
the same context-aware handler anyway.

Registration goes through `lib.nvim.map` rather than `vim.keymap.set`
directly, so a bad lhs is reported against the real call site. The `desc` is
now the command itself (`open.nvim: :Open split`) instead of the config key
name.

- **Module:** `open/bindings/keymaps.lua` (`M.register`, `resolve_target`,
  `accepted_names`)
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

## Right-click context menu (nvzone/menu)

`open.integrations.menu` contributes entries — Open, Open in Browser,
Reveal in File Manager, Open in Terminal, List Links Here — in the shape
[nvzone/menu](https://github.com/nvzone/menu) expects, self-gated against
the same `open.context` resolution `:Open` itself uses: "Open in Browser"
only appears when the resolved target is a URL, "Reveal in File Manager" /
"Open in Terminal" only when it resolves to an existing path. open.nvim has
no dependency on `menu` and never opens a context menu itself — a host
(typically your own `<RightMouse>` dispatcher) composes the entries into
its own menu.

- **Module:** `open/integrations/menu.lua` (`M.items`, `M.submenu`)
- **Config:** `opts.menu.enable` (default `true`)
- **Docs:** [`docs/integrations.md`](../integrations.md#nvzonemenu-context-menu)

## Health check

`:checkhealth open` reports the Neovim version, `vim.system` availability,
`lib.nvim` presence (`:Open` itself is built on
`lib.nvim.usercmd.composer`), detected platform, per-platform tool
availability, and the full list of currently registered handlers with their
descriptions.

- **Module:** `open/health.lua` (`M.check`)
- **Usercmds:** `:checkhealth open`
