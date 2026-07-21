# Lua/Neovim Checklist — applied to open.nvim

Audit against
[`Checklist.md`](E:/repos/Notes/MyNotes/Checklists/Lua/Checklist.md).
✅ good · 🟡 partial · ❌ gap · ➖ N/A for this plugin.

open.nvim is a small, single-purpose dispatcher: `:Open [target] [scope]`
resolves a path/URL/text from editor context and hands it to a registered
handler that shells out to an OS tool (explorer/open/xdg-open/browser/…).
No keymaps, no autocmds, no data-heavy algorithms, no streaming/networking/
compression code, no test suite (explicit project decision, out of scope).

## Schnell-Check (10 Punkte, vor jedem Merge) — ✅ / 🟡
- Fehlerbehandlung — ✅. Every handler call goes through `registry.dispatch`'s
  `pcall(handler.run, ctx)` (`lua/open/registry.lua:92`); optional deps
  (`neo-tree`, `nvim-tree`, `config.neotree.utils.node`) are pcall-guarded in
  `context.lua:73,83,93,105,107`.
- Type Guards — ✅. `registry.register` checks `type(handler)`, `type(handler.key)`,
  `type(handler.run)` before storing (`registry.lua:22-34`); `util.run_detached`
  checks `type(cmd) ~= "table"` (`util.lua:22`).
- Buffer/Window validieren — 🟡. Only one buffer read (`context.lua:131-132`
  `nvim_buf_is_valid` before `vim.bo[buf].filetype`); no windows are opened/
  closed by this plugin at all (nvim_internal handlers use `vim.cmd("split "..)`,
  not raw window APIs), so most of this checkpoint is structurally N/A rather
  than unaddressed.
- Keine globalen States — ✅. All state is module-local upvalues: `registry.lua`'s
  `_handlers`, `config/init.lua`'s `current`, `platform.lua`'s `_cache`. No `_G.*`.
- Single Responsibility — ✅. registry=dispatch, context=signal resolution,
  config=defaults/merge, platform=OS detection, keywords=alias table, each
  handler=one OS-integration concern.
- UI-Cleanup — ➖ N/A. No windows/buffers are created by open.nvim (temp files
  in `notepad.lua:22` are written to disk and handed to an external GUI editor;
  nothing to clean up on the Neovim side).
- Performance-Hotspots — ➖ N/A. No loops over user data; `table.concat` already
  used where it matters (`registry.lua:87` error message).
- Annotationen — ✅. Every file has `---@module`/`---@brief`, public functions
  have `---@param`/`---@return`; shared aliases live in `@types/init.lua`.
- Testbarkeit — 🟡. Handlers are pure given `ctx`/`platform`, but there is no
  DI seam for `vim.system`/`vim.fn.executable` — acceptable given the explicit
  "no test suite" decision; note only, not a gap to action.
- Import-Reihenfolge — ✅. `init.lua` requires config → registry → handlers →
  bindings, matching System→Utils→State→Controller ordering at a plugin-file
  granularity (no distinct "UI" layer to order).

### Bonuspunkt: Custom `lib`-Modul — ✅
`lib.nvim.notify` used exclusively for user-facing messages (every handler,
`registry.lua`, `util.lua`, `health.lua`); no `vim.notify()`/`print()` calls
found. No keymaps are registered by this plugin, so `lib.map`/`lib.usercmd`
don't apply beyond the one `nvim_create_user_command` in `bindings/usrcmds.lua:9`,
which is the correct primitive for a `:Open` ex-command (not a keymap).

## PR-Review-Checkliste (Detail)

### 1. Sicherheit und Fehlerbehandlung — ✅
- pcall around handler dispatch (`registry.lua:92`) and every optional
  `require` of a foreign plugin (`context.lua`).
- Explicit boolean returns throughout (`run_detached`, every handler's `run`,
  `registry.register`) — no silent `nil`/exception leakage into callers.
- Guards before API access — ✅, e.g. `type(cmd) ~= "table" or #cmd == 0` in
  `util.lua:22` before touching `vim.system`/`vim.fn.jobstart`.
- No "structured error type" objects (`InvalidStateError` etc.) — errors are
  plain strings passed to `notify.error`. Reasonable for a plugin this size;
  not flagged as a gap.

### 2. Modularität und Struktur — ✅
- Single Responsibility per module (see Schnell-Check above).
- No globals; registry/config each own their state with a narrow read/write API.
- Pure-ish helpers kept local and unexported: `to_url`, `looks_like_url`,
  `resolve_path`, `wsl_to_win_path` in each handler file are `local function`.
- Registry pattern — ✅, `registry.lua` is exactly this; `config/DEFAULTS.lua`
  matches the "`/config` folder with `DEFAULTS.lua`" convention.

### 3. Buffer-/Window-Management (Neovim) — ➖ mostly N/A
open.nvim does not open/close/configure any Neovim window or scratch buffer.
The only buffer touch is a read (`context.lua:131` current buffer's filetype,
validity-checked first) and `vim.api.nvim_buf_get_text` for the visual
selection (`context.lua:177`), guarded by `pcall` in case marks are stale.
`nvim_internal.lua` opens files via `vim.cmd("split "..path)`/`vsplit`/`tabedit`
— i.e. delegates window creation to Neovim's own ex-commands rather than
raw `nvim_open_win`, which sidesteps most of this section's concerns entirely.

### 4. UI-State-Management — ➖ N/A
No persistent UI state exists in this plugin (no floating windows, no picker,
no multi-step UI flow).

### 5. Dokumentation und Annotationen — ✅
- Kopf-Tags — ✅ on all 16 lua files: `---@module`, `---@brief`, most also
  `---@description`.
- Funktions-Tags — ✅, consistent `---@param`/`---@return` on every public
  function; `@see` cross-refs used in `init.lua:18-19` and `context.lua:25`.
- Aliase/Typen — ✅, dedicated `@types/init.lua` defines `OpenNvim.Config`,
  `OpenNvim.Context`, `OpenNvim.Signals`, `OpenNvim.Handler`, `OpenNvim.Platform`,
  `OpenNvim.HandlerKey` — no inline monster tables.
- Comment convention (`#` in `@alias`/`@return`) — 🟡 not used, minor/cosmetic,
  not worth a follow-up on its own.

### 6. Testbarkeit und Lesbarkeit — 🟡
- No DI for external calls (`vim.system`, `vim.fn.executable`, `io.open`) —
  acceptable trade-off given no test suite is planned for this repo (explicit
  project decision, not re-flagged as a gap here).
- Pure functions used where the logic allows it (`context.resolve`,
  `to_url`, `looks_like_url`) — the actual OS-interaction is isolated at the
  edges of each handler's `run`, which is good separation even without tests.
- No `tools/_test` entry point — consistent with "no test suite" scope.

### 7. Tooling — 🟡
- Lua LS settings — ✅, `.luarc.json` sets `diagnostics.globals=["vim"]`,
  `workspace.library` for luv + `$VIMRUNTIME/lua`, `runtime.version=LuaJIT`.
- Formatter/Linter in CI — ❌ gap. No `.stylua.toml`, no `.luacheckrc`, no
  `.github/workflows/*`. Low priority for a personal plugin this size, but
  worth flagging since filetree.nvim (sibling, same author) does have this
  tier of tooling expectation in its own checklist.

## Coding-Checkliste (beim Implementieren)

### Funktionales Programmieren (Filter/Sources/Sinks/Pumps) — ➖ N/A
No file processing, network/protocol handling, compression/encoding,
streaming transforms, ETL, or parallel/remote processing in this plugin.
`notepad.lua` writes one whole string to one temp file (`io.open`/`f:write`/
`f:close`) — not a streaming concern at this size. `keywords.lua`'s
`capture()` runs one synchronous `vim.system(...):wait()` per resolver
(git config, pwsh profile) — a single blocking call, not a stream.

### A. Strings und Tabellen — ➖ mostly N/A
No string concatenation in loops or large table-building hot paths exist in
this codebase — all tables built here are small, fixed-shape config/handler
tables (`HANDLER_MODULES`, `PATH_TARGETS`, keyword maps of ~30 entries).
`table.concat` already used correctly where multiple strings are joined
(`registry.lua:87` handler-list message, `context.lua:178` visual selection
lines).

### B. Performance-Quickwins — ✅ / ➖
- Async statt Blocken — 🟡 partial by design: `util.run_detached` correctly
  uses `vim.system(..., {detach=true})`/`jobstart(detach=true)` so the spawned
  GUI/browser process never blocks Neovim (`util.lua:21-56`). However
  `keywords.lua`'s `capture()` (`keywords.lua:27-33`) and
  `filemanager.lua`/`default.lua`'s `wsl_to_win_path` (`vim.fn.system(...)`,
  synchronous) *do* block — this is a deliberate trade-off (path/keyword
  resolution needs the result before dispatch) but worth naming explicitly:
  these are rare, on-demand, single-shot calls (only when a WSL path handler
  or a dynamic keyword like `gitignore_global` is actually invoked), not a
  hot path, so ✅ in practice despite being synchronous.
- Memoization — ➖ N/A (no repeated expensive computation; `platform.get()`
  is already the one deliberate cache in this codebase, see below).
- `vim.fn` micro-optimization — ➖ N/A, no hot loop calls `vim.fn.*` repeatedly.

### C. Neovim-API sicher verwenden — ✅ (scoped)
- Handle-Validierung — ✅ where handles are used at all: `nvim_buf_is_valid`
  before `vim.bo[buf].filetype` (`context.lua:132`); `nvim_get_current_buf`/
  `nvim_buf_get_name` are safe without a validity check (always return a
  valid handle for "current buffer"). No windows are opened directly by this
  plugin, so `nvim_win_is_valid` doesn't apply.
- Deferred Calls — ➖ N/A, no `vim.defer_fn`/`vim.schedule` callbacks exist
  in this codebase; all dispatch is synchronous up to the point where an
  external detached process is spawned.
- Einheitliche Fenster-API — ➖ N/A, no window management performed.

### D. State- und Datenmodelle — ✅ / 🟡
- Getter/Setter — ✅, `config.get()`/`config.setup()`, `registry.get()`/
  `registry.register()`/`registry.list()` — no direct field poking from
  outside the owning module.
- Metatables — 🟡 not used (`vim.tbl_deep_extend("force", defaults, opts)` in
  `config/init.lua:39` is used instead of a metatable-based lazy-default
  pattern — see Lazy-Loading section below for the specific note on this).
- FIFO/Ringbuffer — ➖ N/A, no bounded history/favorites feature exists.

### E. Garbage-Collector bewusst steuern — ➖ N/A
No large objects, no coroutines, nothing GC-pressure-relevant in this codebase
(the largest table is the ~30-entry built-in keyword map in `keywords.lua`).

### F. Lazy-Loading und On-Demand-Konfiguration — ✅
This is actually a notable strength: `keywords.lua` builtin entries are
either static expanded strings or **resolver functions** (e.g.
`kw.pwsh_profile = resolve_pwsh_profile`, `kw.hosts = resolve_hosts`,
`keywords.lua:136-177`) that are only invoked lazily at scope-resolution time
(`context.lua:229` `type(kw) == "function" and kw() or ...`). This directly
matches the checklist's "lazy-initializing, on-demand config, default-resolver
per field" pattern — blocking calls (git config, pwsh `$PROFILE`) only ever
run when the specific keyword is actually used, not at `setup()` time. Handler
modules themselves are also lazily `require`d only for the keys listed in
`cfg.handlers` (`init.lua:66-80`), not unconditionally.

## Architektur-Checkliste — ✅
- Schichten/Module: clear separation — context (signals) → registry (dispatch)
  → handlers (OS integration); config/@types support both. Low coupling: no
  handler requires another handler; all cross-module reads go through
  `require("open.<mod>").get()`/`.gather()`, never reaching into another
  module's internal table.
- Abhängigkeiten: `ctx` (from `context.resolve`) and `cfg` (from `config.get`)
  are passed as parameters/return values into handler `run(ctx)` functions
  and `usrcmds.register(cfg)` rather than handlers pulling global state
  themselves beyond their own `require`s.
- Erweiterbarkeit: `registry.register`/`M.get`/`M.list_keys` is exactly the
  "central registry for tools/adapters" the checklist asks for; adding a
  handler means writing one file + one `HANDLER_MODULES` entry
  (`init.lua:24-30`).
- Testbarkeit: handlers are effectively pure `(ctx) -> boolean` given a fixed
  `platform.get()`; no test suite exists by project decision, but the shape
  would support one if added later.

## Anti-Pattern-Check — ✅
- Kein globaler State — ✅ (see Schnell-Check).
- API ohne Guards — ✅ avoided; every `require`d optional dependency and every
  `vim.system`/`jobstart` call is guarded (`pcall` or type/nil checks).
- String-Concat im Loop — ➖ N/A, no such loop exists.
- Closures im Loop — ➖ N/A, `make_named_handler`/`make_nvim_open_fn` build
  closures *outside* any loop, once per handler registration at setup time,
  not per-invocation — this is the correct factory pattern, not the anti-pattern.
- Viele kleine temporäre Tabellen — ➖ N/A, no such churn (each `cmd` table
  built once per dispatch, discarded immediately after spawning).

## Import- und Dateistruktur-Check — ✅
- Import-Reihenfolge — ✅ at plugin scope: `plugin/open.lua` is only a load
  guard; `init.lua` requires config → registry → handler modules → bindings.
- Datei-Header — ✅ on all files (see Dokumentation section).
- Typ-Ablage — ✅, dedicated `lua/open/@types/init.lua`, mirrored by
  `bindings/`, `config/`, `handlers/` as separate folders — one concern per
  directory, matching the checklist's ideal layout almost exactly.

## Performance-Spickzettel (Hotpaths) — ➖ N/A
There is no hot path in this plugin: `:Open` runs once per invocation,
touches a handful of small fixed-size tables, and immediately hands off to a
detached OS process. `t[i]` vs `table.insert`, table pre-reservation,
`table.concat`, weak caches, debounced writes — none of these apply at this
call frequency/data volume. The one cache that does exist, `platform.get()`
(`platform.lua:24-44`, module-local `_cache`, computed at most once per
session), is exactly the right amount of caching for this plugin's actual
hot-ish path (called from every handler on every dispatch).

## Cross-platform shell-out safety (project-specific, not a named checklist section but implied by "Sicherheit")
Checked every `run_detached`/`vim.fn.system` call site in `handlers/*.lua` and
`util.lua` for shell-injection risk:
- ✅ All commands are built as **argument vectors** (`{ "cmd.exe", "/c", ... }`,
  `{ "open", "-R", path }`, `{ mgr, path }`), never as a single interpolated
  shell string — this is exactly the safe pattern (`vim.system`/`jobstart`
  take argv tables, not a shell string, so `path`/`text` containing spaces or
  shell metacharacters cannot break out of their argument position).
- The one place a literal `'""'` empty-title token is spliced into the argv
  for `cmd.exe /c start` (`filemanager.lua:66,74`, `browser.lua:38,41`,
  `default.lua:44,49,53`) is the well-known `start`-quoting workaround (first
  quoted arg after `start` is treated as the window title) — not a shell
  string, still argv-safe, and needed on every platform's Windows path.
- `util.url_encode` (`util.lua:65-72`) percent-encodes text destined for a
  Google search query URL before concatenation — appropriate escaping for
  that sink.
- `wsl_to_win_path` (duplicated in `filemanager.lua:32-35` and
  `default.lua:31-34`) uses `vim.fn.system({ "wslpath", "-w", unix_path })` —
  also an argv call, safe; the duplication itself is a minor DRY note (see
  action items).

## Reviewer-Notizen

| Bereich          | Beobachtung                                                                 | Empfehlung |
| ---------------- | ---------------------------------------------------------------------------- | ---------- |
| Sicherheit        | All shell-outs use argv tables; pcall around dispatch and optional deps      | none |
| Modularität       | Clean layering, registry pattern, no globals                                | none |
| Neovim-API        | Minimal buffer/window surface; what exists is validity-checked              | none |
| Performance       | No hot paths; `platform.get()` cached correctly                             | none |
| Doku/Annotation   | Full `@module`/`@brief`/`@param`/`@return`/`@types` coverage                 | none |
| Tests             | None — explicit project decision, out of scope                              | ➖ N/A |
| `:checkhealth`    | Implemented (`health.lua`): core, lib.nvim, platform, executables, handlers  | none |

## Concentrated action items

1. **De-duplicate `wsl_to_win_path`** — identical private helper exists in
   both `lua/open/handlers/filemanager.lua:32-35` and
   `lua/open/handlers/default.lua:31-34`. Move to `util.lua` as
   `util.wsl_to_win_path(unix_path)` to keep the one WSL-path-conversion
   concern in one place.
2. **Add stylua/luacheck (+ optional CI workflow)** — no formatter/linter
   config exists in the repo. Low urgency for a solo/small plugin, but cheap
   to add and matches the tooling bar already set in the sibling
   filetree.nvim repo.
3. No other gaps found worth actioning beyond what `docs/ROADMAP.md` already
   tracks (custom handlers via `setup()`, `terminal` handler, keymap config,
   `git`-scope, picker integration, `reveal` option, debug mode, context
   cache). Everything else in the source checklist that doesn't reduce to
   ➖ N/A for a dispatcher plugin of this size is already ✅.
