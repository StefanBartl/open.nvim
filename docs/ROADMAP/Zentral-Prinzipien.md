# Zentrale Prinzipien — applied to open.nvim

Audit of open.nvim against
[`Zentrale-Prinzipien.md`](E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md).
Status: ✅ good · 🟡 partial / improvable · ❌ gap (action item).

open.nvim is a single-command dispatch plugin (`:Open [target] [scope]`) with
no keymaps, no autocommands, and no persistent runtime state. Many principles
below are aimed at modules with hot paths (`CursorMoved`, tree buffers,
Treesitter) that simply do not exist here — those are marked N/A rather than
padded with invented action items.

## lib.nvim usage (the "WICHTIG" preamble)

| Helper | Status | Notes |
|---|---|---|
| `lib.notify` | ✅ | Every handler and `registry.lua`/`init.lua` creates a scoped notifier via `require("lib.nvim.notify").create("[open_nvim.*]")` — no raw `vim.notify()`/`print()` anywhere. |
| `lib.map` | N/A | open.nvim registers zero keymaps by design (`docs/BINDINGS.md` shows a *suggested* user keymap, not one the plugin creates). Nothing to migrate. |
| `lib.usercmd` | ❌ | `bindings/usrcmds.lua:9` calls `vim.api.nvim_create_user_command` directly. `lib.nvim.usercmd.create()` (`E:/repos/lib.nvim/lua/lib/nvim/usercmd/init.lua`) already wraps this with a `pcall`-guarded callback and notify-on-error — exactly the pattern `registry.dispatch` re-implements by hand at `registry.lua:92-95`. Small, one-call migration. |
| `lib.autocmd` / `lib.augroup` | N/A | open.nvim creates no autocommands at all (confirmed via repo-wide grep — the only `vim.g.loaded_open_nvim` guard in `plugin/open.lua` isn't an autocmd). |
| `lib.cross` | ❌ | `platform.lua` hand-rolls `is_win`/`is_mac`/`is_wsl`/`is_linux` detection and caches it locally. `lib.nvim.cross.platform.is` (`E:/repos/lib.nvim/lua/lib/nvim/cross/platform/is.lua`) already provides the same cached, uname-based detection (`is_windows`, `is_wsl`, `is_macos`, `is_linux` sub-modules). This is a genuine duplication, not a stylistic choice — see action item below. |
| `lib.hover_select` | N/A | open.nvim never prompts the user to pick from a list (`:Open` takes explicit args or resolves automatically); there is no `vim.ui.select` call to replace. |
| `lib.lazy` | 🟡 | Handler modules are only `require`d inside `setup()` for the keys listed in `cfg.handlers` (`init.lua:66-80`), so unused handler families are never loaded — same *effect* as `lib.lazy`, just hand-written instead of using the shared proxy. Cosmetic, not a functional gap. |
| `lib.memo` | N/A | `platform.get()` and `keywords.builtin()`'s dynamic resolvers only need a plain one-shot cache (module-local variable / lazy table build), not the general memoization machinery. See Principle 7. |

**Action:** the concrete lib-adoption item is replacing `platform.lua`'s
hand-rolled OS detection with `lib.nvim.cross.platform.is` (or its
`is_windows`/`is_wsl`/`is_macos` sub-functions), and routing `:Open`'s
registration through `lib.nvim.usercmd.create`. Both are small, isolated
changes — no other module needs to change alongside them.

## The 10 principles

**1. Events bündeln, Logik entkoppeln** — ✅ (N/A)
No `nvim_create_autocmd` calls anywhere in the plugin (verified by repo-wide
grep). All entry points are the single `:Open` command
(`lua/open_nvim/bindings/usrcmds.lua:9`) and the public `M.open()` Lua API
(`lua/open_nvim/init.lua:39`), both routed through the same
`context.gather()` → `context.resolve()` → `registry.dispatch()` pipeline.
Nothing to bundle.

**2. Eigene Logik lazy laden** — ✅
`init.lua:66-80` only `require`s a handler module if its key is listed in
`cfg.handlers` (default: all five, but user-configurable). Keyword resolver
functions in `keywords.lua` are stored as closures and only invoked at
scope-resolution time (`context.lua:229`), so blocking calls like `git config`
or `pwsh -Command` never run unless the keyword is actually referenced — noted
explicitly in the module's own doc comment (`keywords.lua:7-8`).

**3. Kontext statt Mehrfach-API-Zugriffe** — ✅
This is the plugin's namesake pattern: `context.gather()` collects all raw
signals (tree path, cfile, cword, visual selection, buffer path) exactly once
per invocation (`context.lua:159-187`), and `context.resolve()` turns them into
a single `OpenNvim.Context` consumed by every handler (`context.lua:212-249`).
Handlers never call `vim.fn.expand("<cfile>")` or query buffer state
themselves — they only read `ctx.text`/`ctx.is_url`/`ctx.is_path`.

**4. Autocommand-Gruppen sauber nutzen** — N/A
No autocommands exist to group.

**5. Event oder Command?** — ✅ (trivially)
The plugin *is* the command — `:Open` is explicit, user-triggered, and never
fires automatically on a buffer/window event. This principle is essentially
answered by the plugin's architecture rather than something to check per
function.

**6. Treesitter notwendig oder nicht?** — ✅ (N/A)
No Treesitter usage anywhere. Tree-buffer detection (neo-tree/nvim-tree/netrw)
in `context.lua:72-138` is done via each plugin's own Lua API
(`neo-tree.sources.manager`, `nvim-tree.api`) or plain buffer-local variables
(`vim.b[buf].netrw_curdir`) — never syntax parsing.

**7. Cache vorhanden und explizit?** — ✅
`platform.lua:9-44` caches the OS-detection result in a module-local
`_cache`, computed at most once per session and documented as such
(`"called at most once per session"`). It's a plain in-memory cache (not
`stdpath("cache")`), which is correct here — the value is derived from
`vim.fn.has()` / `/proc/version`, is process-lifetime-only, and never needs to
survive a restart or be invalidated. `keywords.lua`'s dynamic resolvers are
*not* cached (each re-runs `git config` / `pwsh -Command` / `vim.uv.fs_stat`
on every reference), but this is intentional and acceptable: keyword lookups
happen at most once per `:Open` invocation (an explicit, infrequent user
action), not in a hot path, so a cache would add invalidation complexity for
no measurable benefit.

**8. Allokationen im Hot-Path vermeiden** — N/A
There is no hot path — no loop, no per-keystroke or per-event code. The one
loop-like structure (`registry.list_keys()` / `list()` in `registry.lua:59-73`)
only runs for command completion, an already-throttled, human-triggered path.

**9. Debugbarkeit eingeplant?** — 🟡
`health.lua` gives a solid `:checkhealth open_nvim` covering Neovim version,
`lib.nvim` presence, detected platform, executables per platform, and
registered handlers — better-than-typical debuggability for a plugin this
size. Control flow is easy to follow (gather → resolve → dispatch, one
`pcall` boundary per handler in `registry.dispatch` at `registry.lua:92`).
What's missing: no debug/verbose switch — failures surface only as a single
`notify.error` line with no way to see the constructed command vector or
resolved context. *Minor, optional action:* an opt-in `debug` config flag that
notifies the built `cmd` table and resolved `ctx` before `run_detached` is
called, for troubleshooting platform-specific launch failures.

**10. Laufzeit wichtiger als Startup?** — ✅ (N/A)
No `CursorMoved`/`TextChanged`/`BufEnter` handlers exist, so this principle
does not apply. Startup cost is also negligible: `plugin/open.lua` only sets
a load guard; `setup()` does a handful of `require`s and one user-command
registration.

## Summary

open.nvim is structurally clean for its size: a single command, a proper
signals-then-context pipeline (Principle 3 is essentially the whole
architecture), lazy handler loading, and no autocommands or hot paths to worry
about — most principles are honestly N/A rather than partially met. The two
real, concentrated action items are both **lib.nvim adoption**, not design
flaws: (1) replace `platform.lua`'s hand-rolled Windows/WSL/macOS/Linux
detection with `lib.nvim.cross.platform.is` (a genuine duplication of
existing, already-cached logic), and (2) route `:Open`'s registration through
`lib.nvim.usercmd.create` instead of a raw `nvim_create_user_command` call.
Everything else — caching, debuggability, event/command choice — is already
adequate for a plugin of this scope.
