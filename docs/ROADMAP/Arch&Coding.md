# Architektur- & Codierungsrichtlinien — applied to open.nvim

Audit against
[`regeln/PRINCIPLES.md`](../../../WKDBooks/Development/wkdbook-Lua/Checklists/regeln/PRINCIPLES.md).
✅ good · 🟡 partial · ❌ gap · ➖ N/A (no matching surface area).

> The source checklists (`Arch&Coding-Regeln.md`, `Checklist.md`,
> `Zentrale-Prinzipien.md`) were retired: they were absorbed into the rule
> collection under `WKDBooks/Development/wkdbook-Lua/Checklists/`, which is
> now the canonical one. The links above point there.


open.nvim is a ~600-line plugin: one user command (`:Open`), no keymaps, no
autocmds, no async watchers, no persisted state. Several checklist sections
target problems this plugin structurally doesn't have; those are marked ➖
rather than padded out.

## 1. Sicherheitsprinzipien & Fehlerbehandlung — ✅
Every external call (`vim.system`, `jobstart`, `require` of optional deps like
neo-tree/nvim-tree) is `pcall`-guarded — see `util.lua:31,41,50`,
`context.lua:73,79,93,105,107`. `registry.dispatch` wraps every handler
invocation in `pcall` (`registry.lua:92`) so one broken handler can't crash
`:Open`. Handlers return explicit `boolean` success instead of throwing
(`filemanager.lua:90`, `browser.lua:92`, `notepad.lua:66`). Low-level modules
(`util`, `platform`, `context`) never call `notify` for user-facing success/
failure framing beyond `error`/`warn` on genuine failures — no stray `print()`
anywhere in the tree. One gap: no `@raises`/`@error` annotation tags anywhere,
and there's no `safe_call`-style standardized error wrapper — failures are
plain `pcall` + `notify.error`, which is adequate at this scale but not
"structured error types."

## 2. Modularisierung & Strukturprinzipien — ✅
Clean single-responsibility layout: `registry.lua` (dispatch), `context.lua`
(signal gathering + resolution), `platform.lua` (OS detection, cached),
`config/` (setup/defaults), `bindings/usrcmds.lua` (the one user command),
`handlers/*.lua` (one file per handler family). Tools are registered via
`registry.register` exactly as the checklist prescribes (`registry.lua:22`).
No global state: `platform._cache` and `config.current` are module-local
upvalues, not globals; all handler `run(ctx)` functions take state as an
argument rather than reading ambient globals. Helper functions
(`resolve_path`, `to_url`, `write_temp`, etc.) are consistently `local`, never
exported unless part of the public contract.

## 3. Buffer- & Window-Management — 🟡 (minimal surface area)
The only "window management" is `nvim_internal.lua`'s `split`/`vsplit`/`tab`
handlers, which just shell out to `vim.cmd("split "..path)` etc. — no window
handles are stored or reused, so most of §3 (`ui_state` module, `cleanup_all`,
getter/setter buffer handles) doesn't apply. What is present is done
correctly: the path is validated with `vim.uv.fs_stat` before the ex-command
runs (`nvim_internal.lua:21`), and the `vim.cmd` call itself is `pcall`-guarded
(`nvim_internal.lua:38`). `context.lua`'s tree-buffer detection reads
`vim.api.nvim_get_current_buf()` and guards it with
`nvim_buf_is_valid` (`context.lua:131-132`) before touching `filetype`. No
`nvim_win_is_valid` checks exist anywhere because no window handles are ever
cached across calls — nothing to invalidate.

## 4. Methoden, Metatables & Datenmodelle — ➖
No metatables, no OOP-style objects, no ring buffers anywhere in the codebase.
Every module is a plain `M = {}` table with functions attached. This is
appropriate for the problem size (stateless dispatch + one cached platform
table) — introducing metatables here would be over-engineering, not a gap.

## 5. Dokumentation & Annotationen — ✅
Every file opens with `---@module`, `---@brief`, and (for the meatier modules)
`---@description` blocks — e.g. `context.lua:1-26`, `keywords.lua:1-13`,
`init.lua:1-19`. Functions are annotated with `---@param`/`---@return`
throughout, including the two-tuple `string|nil, string|nil` returns in
`filemanager.lua:17-21` and `notepad.lua:20-21`. `@see` cross-links exist
(`init.lua:18-19`, `context.lua:25`). Naming is consistent snake_case
throughout, no mixed conventions. There is a proper `@types/init.lua` with
`---@meta`, one `---@class`/`---@alias` per concern (`OpenNvim.Platform`,
`OpenNvim.Context`, `OpenNvim.Signals`, `OpenNvim.Handler`, `OpenNvim.Config`),
and it ends in `return {}` exactly as prescribed
(`@types/init.lua:81`). Gap: only one `@types` file exists at the package
root — subdirectories (`handlers/`, `bindings/`, `config/`) don't each have
their own `/types` folder as §5's "Subverzeichnis → '/types'-ordner" rule
asks for, but given there are only 5 handler files sharing one `OpenNvim.Handler`
shape, a single shared types file is proportionate rather than a real gap.
No `@raises` tags are used anywhere (see §1). README/doc/help split is
correctly in place (`README.md`, `doc/open.txt`, `CHEATSHEET.md`,
`docs/BINDINGS.md`) — though the checklist's German-README requirement is
this-project's call, not evaluated here since open.nvim's docs are
English-only by design (public plugin, not a personal nvim/config module).

## 6. Testbarkeit & Lesbarkeit — ❌
There is no `test/` directory and no dry-run entry point anywhere in the repo.
Functions are small and single-purpose (e.g. `resolve_path`, `is_file`,
`wsl_to_win_path` in `filemanager.lua` are each 2-6 lines), and there are no
hardcoded states or hidden globals, so the code is testable *by design* — it's
just not tested. This is the single clearest gap against the checklist.

## 7. Fehlerbehandlung & Validierung (Sicherheit) — 🟡
Validation is thorough at call sites (`registry.register` type-checks
`handler`/`handler.key`/`handler.run` before accepting registration —
`registry.lua:23-37`; `resolve_file_path` checks `ctx.is_url` and
`fs_stat` before any ex-command runs). But there is no standardized
`safe_call(fn, args) -> {ok, result, err}` wrapper and no named error types
(`InvalidQueryError`-style) anywhere — every failure path is an ad hoc
`notify.error(string)`. Adequate for this plugin's size, but exactly the gap
the checklist flags in §7.

## 8. Performance & Speicher — ➖
No hot loops, no per-keystroke or per-cursor-move handlers, nothing async, no
caches beyond `platform._cache` (computed once, `platform.lua:25`). String
building is trivial (single `..` concatenations for command labels, never in
a loop). None of §8's weak-table/memoization/debounce machinery is relevant
at this call frequency — `:Open` runs once per invocation, by hand. Not
applicable rather than missing.

## 9. Cache hitting — ➖
Same reasoning as §8: the only cache is the one-shot platform detection
(`platform.lua:10,25`), which is already correctly memoized in a module-local
variable. No query/match-count caching applies because there's no repeated
querying.

## 10. Schwache Tabellen & Memoisierung — ➖
No weak tables anywhere, and none are warranted: `_handlers` in `registry.lua`
is a small, intentionally-persistent table (handler registrations should
*not* be GC'd), and `platform._cache` is a 4-boolean table that lives for the
whole session by design. Nothing here would benefit from `__mode`.

## 11. Spezialfälle — ✅ (cross-platform correctness)
This is where open.nvim actually concentrates its complexity, and it's
handled well: every handler branches over `is_win` / `is_wsl` / `is_mac` /
else-Linux (`filemanager.lua:65-86`, `browser.lua:36-47,56-73`,
`notepad.lua:48-62`, `default.lua:43-72`), with WSL treated as a genuinely
distinct case (path translation via `wslpath`, not just "treat as Linux") —
e.g. `filemanager.lua:32-35`, `default.lua:31-34`. `util.run_detached`
explicitly documents *why* Windows/WSL use `jobstart(detach=true)` instead of
`vim.system` (GUI child processes staying tethered — `util.lua:27-29`), which
is exactly the kind of platform-specific rationale §11/MISC ask to be
recorded, not just coded. Named-scope keywords (`keywords.lua`) also
platform-branch correctly (`resolve_nvim_init`, `resolve_pip_conf`,
`resolve_hosts`, and WSL-only/Windows-only keys gated at
`keywords.lua:180-185`). No "Dual Representation"/history/FIFO patterns apply
— there's no bounded history or favorites list in this plugin.

## MISC (Cross-Platform) — ✅
Directly demonstrated throughout (see §11). `platform.lua` is the single
source of truth every other module consumes instead of re-calling
`vim.fn.has()` (`platform.lua:5`), matching the checklist's "determine once,
cache, reuse" guidance almost verbatim.

## NVIM-Config-spezifisch (`lib.nvim`) — 🟡
`lib.nvim.notify` is used consistently and correctly everywhere instead of
raw `vim.notify`/`print` (every handler + `registry.lua:8` + `util.lua:9`).
`lib.usercmd`/`lib.map`/`lib.autocmd` are not used — `usrcmds.lua:9` calls
`vim.api.nvim_create_user_command` directly. This is a real but minor
inconsistency: open.nvim only registers *one* user command, so the
centralization benefit `lib.usercmd` provides is small, but for strict
adherence it's still a deviation from the checklist's explicit
`lib.usercmd` preference. `lib.lazy`, `lib.hover_select`, `lib.memo` are
correctly not needed at this scope.

## Annotations- / Import-Regeln — ✅
Every handler module caches its `require` results as top-level locals
(`local notify = require(...)`, `local platform = require(...)`,
`local util = require(...)` — pattern repeated at the top of every
`handlers/*.lua` file) rather than repeating `require("mod").fn` inline.
Import ordering is consistent: stdlib/vim first implicitly, then
`lib.nvim.notify`, then project modules (`platform`, `util`), matching the
checklist's prescribed order. `context.lua` and `bindings/usrcmds.lua`
correctly `require` on-demand inside functions (`context.lua:226`,
`usrcmds.lua:10-11`) where a module-level require would create a circular
dependency (`context` ↔ `config`) — a deliberate, documented tradeoff rather
than sloppiness.

## Tables / Strings / GC / CPU — ➖
No table-building loops, no string concatenation in loops, no measurable hot
path anywhere in the codebase — `table.concat` is used once for a visual
selection join (`context.lua:178`) and once for handler-key list rendering
in error messages (`registry.lua:87`), both trivially small and outside any
loop. None of the micro-benchmark guidance (table pre-sizing, `t[i]=v`,
weak-table memoization, GC tuning) has anything to attach to at this scale.

## Concentrated action items
1. ~~**Add a minimal test entry point.**~~ — ✅ done, and the finding was
   already stale when written: `TESTS/` exists with six specs
   (`features`, `usrcmds`, `viewer`, `viewer_scan`, `harvest_render`,
   `harvest_scope`), a shared `harness.lua` and a headless `run.lua` that
   exits non-zero on failure. It is now gated in CI
   (`.github/workflows/ci.yml`) alongside stylua and luacheck.
2. ~~**Adopt `lib.usercmd` for the one `:Open` registration**~~ — ✅ done,
   also stale as written: `bindings/usrcmds.lua` builds every command
   through `lib.nvim.usercmd.composer`, including two custom completion
   types (`OPEN_TARGET`, `OPEN_SCOPE`) and the `:UrlView`/`:MDLinksView`
   wrapper verbs.
3. **Consider a `safe_call`-style wrapper** — still open, still not urgent.
   Error handling remains ad hoc `notify.error(string)`, which is
   proportionate at this size; revisit only if a caller ever needs to
   branch on *why* a dispatch failed rather than just report it.
4. No action needed on §§3/4/8/9/10 — these are correctly N/A for a
   plugin this size; do not add ceremony (metatables, weak tables, caches)
   that has nothing to justify it yet.

## Status

Items 1 and 2 were both already satisfied by the time this audit was
re-read; they are marked done rather than deleted so a future run does not
re-flag them. Item 3 is the only genuinely open line, and is deliberately
deferred. Platform detection likewise already delegates to
`lib.nvim.cross.platform.*` (`platform.lua`), and WSL path conversion now
goes through the shared `lib.nvim.cross.fs.wslpath`.
