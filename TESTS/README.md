# TESTS/

Headless, framework-free spec suite for open.nvim. Every spec drives a module
directly — no picker interaction, no real network, no real subprocess left
running.

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile TESTS/run.lua" -c "qa!"
```

`run.lua` prints one line per spec and exits non-zero if any spec failed
(`OPEN_TESTS_OK` on success). CI (`.github/workflows/ci.yml`) runs exactly
this command.

## lib.nvim and ui.nvim

open.nvim depends on `lib.nvim` hard (notify, `usercmd.composer`,
`cross.platform`, `cross.fs.wslpath`, `cross.run`, `harvest`) and on
`ui.nvim` for its opt-in picker (`open.picker`, `ui.kit.select`) and the
`open.integrations.menu` item builders (`ui.contextmenu`). `run.lua` resolves
each of them in this order:

1. `$LIB_NVIM_PATH` / `$UI_NVIM_PATH`
2. a sibling checkout, `../lib.nvim` / `../ui.nvim`
3. the lazy.nvim-managed copy under `stdpath("data")/lazy/<name>`

CI checks out both as siblings (see `ci.yml`), which is why this suite can
drive `open.picker.select()` and `open.integrations.menu` for real instead of
stubbing either dependency away.

## The specs

| | |
| --- | --- |
| `harvest_scope_spec.lua` | `lib.nvim.harvest.scope` resolution (buffer/range/path scopes, ignore list, binary/oversized skip, CRLF normalization) |
| `harvest_render_spec.lua` | `lib.nvim.harvest.render` output shapes (markdown table, csv, lines) |
| `viewer_scan_spec.lua` | `open.viewer.scan`: link extraction — bare URLs, markdown links, code-fence skipping, path resolution, anchors |
| `viewer_spec.lua` | `open.viewer`: collect/filter/sort/labels/rows/as_markdown/open(), end to end against real buffers and temp files |
| `usrcmds_spec.lua` | `open.bindings.usrcmds`: `:Open [target] [scope]` grammar, the `:Open viewer` kind/scope disambiguation, `:UrlView`/`:MDLinksView` wrappers, and the "viewer" reserved-key guard |
| `features_spec.lua` | roadmap features layered on after the initial suite: `custom_handlers`, the terminal handler, keymap registration, brave/opera handlers, `filemanager.reveal`, debug mode, the picker feature end to end, the telescope integration's no-telescope guard, the context cache, `git`/`cwd` scopes, a keyword resolver returning nil, and `office_open`'s `BufReadCmd` redirect |
| `config_spec.lua` | `open.config`'s `setup()` merge: the built-in/user keyword split (which cannot go through `tbl_deep_extend` because values may be functions), `builtin_keywords=false`, nested-table merges, and that `config/DEFAULTS.lua` survives repeated `setup()` calls unmutated |
| `util_platform_spec.lua` | `open.util` (`run_detached`'s guard and delegate-failure path, `url_encode`, `find_exec`, `cmd_escape_unquoted`) and `open.platform` (cached detection, exactly one OS flag set) |
| `registry_spec.lua` | `open.registry`: every `register()` validation branch, the overwrite warning, `get`/`list_keys`/`list` sorting, `dispatch`'s unknown-target and caught-handler-error paths, and the debug-mode dispatch log |
| `keywords_spec.lua` | `open.keywords`: `builtin()`'s static vs. resolver-function entries, the platform-gated entries, and `capture()`'s subprocess memoization (success and failure), with `vim.system` stubbed throughout — no real subprocess is ever spawned |
| `context_spec.lua` | `open.context`: the full `resolve()` branch matrix (`%`/`cfile`/`path=`, the `PATH_TARGETS` split, the visual/cword/buffer_path fallback chain, the tree_path override) driven with hand-built signals tables, `default_target()`'s three branches, the netrw tree-buffer resolver against a real buffer, the neo-tree soft-dependency guard, `with_cache()`'s error-path cache reset, and a real-cursor regression pinning `gather()`'s visual-signal bug (see Bugs below) |
| `bindings_keymaps_spec.lua` | `open.bindings.keymaps`: the registry-driven `open_<key>` name space (including a handler registered after the fact), the `open_manager`/`open_default` special cases, and the unknown-name warning |
| `handlers_spec.lua` | the handlers with no coverage before this pass: `default`, `image` (with and without a fake `images.nvim`), `browser` (`to_url`'s three branches, `default_browser_cmd`/`named_browser_cmd`'s per-platform dispatch, the no-candidate-on-PATH failure, the macOS-only Safari guard), `notepad` (per-platform command, the WSL `wslpath` conversion and its failure path, the no-GUI-editor-on-Linux failure), and `nvim_internal` (split/vsplit/tab against a real temp file, the URL-rejection and nonexistent-path guards) |
| `integrations_spec.lua` | `open.integrations.urlview` (URL sanitizing, the registry dispatch, the blank-match warning, `setup()`'s opt-out and picker-detection gating) and `open.integrations.menu` (the `menu.enable` gate, the always-on "List Links Here" entry, the context-gated "Open in Browser" entry, `submenu()`) |
| `picker_spec.lua` | `open.picker.select()`'s own branches driven directly: a cancelled prompt, a choice that resolves to nothing, a real dispatch, and the `format_item` fallback for an unregistered key |
| `health_spec.lua` | `open.health`: one baseline "runs to completion" smoke check, plus a regression pinning the composer-crash bug (see Bugs below) — `health.lua` otherwise stays deliberately untested |
| `harness.lua` | shared assertions (`eq`, `ok`, `falsy`, `contains`) plus `scratch()`/`tmpdir()`/`write()` fixture helpers |
| `run.lua` | runner: resolves lib.nvim/ui.nvim, loads each spec, reports results, sets the exit code |

Adding one: write `TESTS/<name>_spec.lua` returning `function(H) ... end`
(use `H.eq`/`H.ok`/`H.falsy`/`H.contains`/`H.scratch`/`H.tmpdir`/`H.write`),
then list its filename in the `specs` table in `run.lua`.

## Coverage

Every `lua/open/**/*.lua` file with real logic or branching now has a
dedicated real-assertion spec (or a section of one): the config merge, the
handler registry, `open.util`/`open.platform`, the built-in scope-keyword
table and its memoized resolvers, `open.context`'s full resolution matrix,
every handler (`default`, `browser`, `filemanager`, `notepad`,
`nvim_internal`, `terminal`, `image`), the `:Open`/`:UrlView`/`:MDLinksView`
command grammar, the optional-keymap generator, the viewer subsystem
(scan/collect/filter/sort/render), the opt-in picker, and the opt-in
integrations (`urlview`, `menu`; `telescope`'s own no-telescope guard and
extension shape).

### Deliberately left untested

- **`health.lua`** — a declarative `:checkhealth` reporter: each branch maps
  a runtime probe (an external binary on PATH, an optional plugin, the
  detected platform) straight to one `vim.health.*` call with no computed
  value to assert on. Exercising every branch would mean mocking every
  external it probes and mostly asserting "the right `vim.health.*` method
  got called," which tests the mocks more than the code — the same call this
  repo's siblings (`debugging.nvim`, `language.nvim`) made for their own
  `health.lua`. `health_spec.lua` is the one exception: a targeted regression
  for the composer-crash bug below, not a branch-by-branch audit.
- **`@types/init.lua`** — a `---@meta` type-anchor file (`return {}`); no
  runtime behavior to test.
- **`integrations/telescope.lua`'s actual picker internals** (the
  `finders`/`previewers`/`attach_mappings` wiring inside `M.picker()`) —
  telescope.nvim itself is not checked out in this repo's CI (only
  `lib.nvim` and `ui.nvim` are, per `ci.yml`), so a spec exercising the real
  finder/previewer would pass locally wherever telescope happens to be
  installed and fail in CI. `features_spec.lua` and `integrations_spec.lua`
  cover what is reachable without it: `M.picker()`'s clean no-telescope
  guard and `M.extension()`'s returned shape.

Nothing in this suite spawns a real subprocess or touches the network:
`open.util.run_detached`, `vim.system`, and `lib.nvim.cross.run.run_detached`
are stubbed at their call sites in every handler/keyword spec that would
otherwise shell out.

## Bugs found here

Two defects came out of a coverage re-audit. The first is **fixed** and its
assertion stayed on as a regression guard; the second is still pinned with a
`BUG:`-marked assertion, so the suite fails the day that behavior changes,
and the comment above it explains what "fixed" would look like:

1. **`health.lua`'s final call into `lib.nvim.bindings.usercmd.composer`**
   (`health_spec.lua`) — **fixed.** `check_lib_nvim()` already reported a
   missing composer as a `vim.health.error()`, but `M.check()` then called
   `require("lib.nvim.bindings.usercmd.composer").checkhealth("Open")`
   unconditionally at the very end, with no `pcall`. On the one machine that
   needed that error message most, the require threw right after emitting
   it, and `:checkhealth` raised instead of finishing the report. The call
   is guarded now, like every other optional dependency the same check
   probes.
2. **`context.lua`'s visual signal, `gather()`** (`context_spec.lua`) — the
   branch reads the `'<`/`'>` marks, which Neovim commits only once Visual
   mode is *left*, guarded by a check that `mode()` is *still* `"v"`/`"V"`/
   CTRL-V. Those two conditions never hold for the same selection: `:Open`
   itself only ever runs from `:'<,'>Open`, which leaves Visual mode (and
   sets the marks) *before* the command runs, so the branch is always
   skipped there; the only path where `mode()` is still `"v"` during the
   callback — a user's own Visual-mode keymap calling `open()` directly — is
   exactly the path where the current selection is not finished yet, so the
   marks still name whichever selection was last left (or nothing at all).
   In practice `signals.visual` is either `nil` or a stale, unrelated
   string, never the selection the user is actually making. Fixing it means
   reading `vim.fn.getpos("v")` (the live selection's anchor) plus the
   cursor instead of `'<`/`'>`, which this re-audit left as a pinned `BUG:`
   rather than changing quietly.
