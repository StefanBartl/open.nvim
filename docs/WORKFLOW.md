# Workflow — getting real use out of open.nvim day to day

Every feature here is documented on its own elsewhere (docs/commands.md,
docs/FEATURES/CORE.md, docs/FEATURES/HANDLERS.md, docs/FEATURES/VIEWER.md).
This is the different question: once `:Open` has a dozen handlers and three
ways to pick a scope, *how do they actually combine* into something you
reach for without thinking, rather than a command you re-read the docs for
every time.

## What bare `:Open` actually resolves to

There is no single "default behavior" — the target and the scope are
resolved by two independent, ordered fallback chains, and it pays to know
the order because it explains the surprises.

**Target** (1st arg, when omitted) — `open/context.lua`'s `default_target()`:
1. Current buffer is a neo-tree / nvim-tree / netrw buffer → `default_filemanager`.
2. Otherwise, whichever of `<cfile>` / `<cWORD>` / buffer path is non-empty
   is checked for a URL-ish prefix (`http(s)://`, `ftp://`, `www.`) → `default_browser`.
3. Anything else → `default_filemanager`.

**Scope** (2nd arg, when omitted) — `M.resolve()`, and it's target-aware, not
a single universal fallback:
- Tree node under the cursor always wins if present, regardless of target.
- For *path-oriented* targets (`filemanager`, `split`, `vsplit`, `tab`,
  `terminal` — the `PATH_TARGETS` set in `context.lua`): a `<cfile>` that
  actually resolves to something on disk, else the buffer path.
- For everything else (`browser`, `notepad`, custom handlers, …): visual
  selection, else `<cWORD>`, else buffer path.

The practical upshot: sitting on a bare word that happens to look like a URL
and running `:Open` sends you to the browser, even mid-sentence in a
markdown file, because step 2 above only checks the *shape* of the text, not
whether you meant to open it. If that's not what you wanted, `:Open notepad`
or `:Open filemanager` with an explicit target overrides the guess entirely
— explicit target always short-circuits `default_target()`.

## Explicit scope beats the heuristic, every time

The moment you pass a 2nd argument, all of the above heuristics are skipped
— `M.resolve()` branches into the explicit path (`%`, `cfile`, `cwd`, `git`,
`path=<path>`, a keyword, or literal text) before it ever looks at gathered
signals. Practical reasons to reach for it instead of trusting context:

| Situation | What to type |
|---|---|
| Cursor is on prose, not on the path you want | `:Open filemanager %` (buffer, ignore cursor) |
| You want the *repo root*, not the current file | `:Open filemanager git` |
| You want Neovim's cwd, which may differ from the buffer's directory | `:Open terminal cwd` |
| You want a config file by name, from anywhere | `:Open split zshrc`, `:Open tab pwsh_profile` |
| You know the exact path already | `:Open browser path=/tmp/report.md` |

`git` deliberately does not fall back to a guess outside a repo — it shells
out to `git rev-parse --show-toplevel` and resolves to nothing if that
fails, so `:Open filemanager git` in a non-repo buffer is a clean no-op
("Nothing to open"), not a wrong directory.

Keywords (`zshrc`, `nvim_init`, `pwsh_profile`, …) work as the scope
argument to *any* target, not just `split`/`tab` — `:Open browser
gitignore_global` is as valid as `:Open split zshrc`. A couple of built-ins
(`pwsh_profile`, `gitignore_global`) resolve dynamically by shelling out, so
expect a small delay only the first time you use one, not a hardcoded path
that can go stale.

## `:Open viewer` vs a direct handler

These solve different problems and it's easy to reach for the wrong one:

- You already know *which* file/URL you want, and roughly where it is →
  a direct handler (`:Open browser`, `:Open split zshrc`, …). One target,
  resolved and dispatched immediately.
- You don't know what links exist in a file/buffer/directory yet, and want
  to *discover* them before picking one → `:Open viewer` / `:UrlView` /
  `:MDLinksView`. It scans first, then hands you a picker (or a table/CSV/
  clipboard export if you're not planning to open anything at all).

In practice: `:UrlView` on a README before opening any of its links,
`:MDLinksView cwd out=table` to audit every markdown link in a project for a
link-rot pass, then a plain `:Open browser <url>` once you already know
where you're going. Don't use the viewer as a fancy `:Open browser` — for a
single known target it's strictly more typing for the same result, since the
picker's `<CR>` just dispatches to `default_browser` for a URL entry anyway.

One overlap worth knowing: the viewer's picker opens a picked *file* through
whatever `opts.viewer.open_file` is set to (`"split"` by default) — not
through `default_filemanager`. If you've set `filemanager.reveal = true` and
expect a picked markdown link to reveal in Explorer/Finder, it won't; it
lands in a Neovim split. Change `opts.viewer.open_file` if you want that
consistent with your filemanager habits.

## The WSL notepad gotcha

`:Open notepad` writes the target text to a temp file, then hands that path
to a GUI text editor. On plain Linux or macOS this is a single `xdg-open`/
`open -e` call and the path just works. On WSL it doesn't, for a reason
worth internalizing rather than just trusting the fix:

`vim.fn.tempname()` inside WSL Neovim returns a *Linux-side* path, something
like `/tmp/nvimXXXXXX/0`. `notepad.exe` is a native Windows binary — it has
no concept of the WSL filesystem namespace and will report that path as "not
found" even though the file is right there from Neovim's point of view. The
fix in `open/handlers/notepad.lua` is `lib.nvim.cross.fs.wslpath.to_win()`,
which converts the Linux path to its `\\wsl$\...` (or drive-letter, if it's
already under `/mnt/c/...`) Windows-visible form *before* the path is handed
to `notepad.exe`. Skip that conversion and `:Open notepad` on WSL fails
100% of the time, not intermittently — it's not a race condition, it's two
processes with genuinely disjoint filesystem views.

Two consequences worth knowing if this ever breaks for you:
- If `wslpath` itself fails (not on PATH, or the conversion call errors),
  the handler reports the error and stops — it does not silently fall back
  to the unconverted path, because that would just reproduce the same
  "not found" failure one layer down.
- This is specific to `notepad` — `:Open default` and `:Open filemanager`
  route through `lib.nvim.cross.open_default` / `reveal_in_fm`, which do
  their own WSL→Windows translation internally. If you're chasing a
  "path not found" bug on WSL, check which code path you're actually in
  before assuming it's this one.

## `split` / `vsplit` / `tab` are handlers, not modifiers

It's tempting to think of split/vsplit/tab as options you layer onto another
handler ("open this in filemanager, but as a split"). They aren't — they are
three independent handlers in `open/handlers/nvim_internal.lua`, each a thin
wrapper around `:split` / `:vsplit` / `:tabedit` for a validated on-disk
path. That means:

- They only accept path contexts — a URL context is rejected outright
  (`"Text looks like a URL, not a local path"`), so `:Open split
  https://…` fails by design, not by accident.
- The path is validated to exist on disk *before* the ex-command runs, so a
  typo'd scope fails with a clear error instead of `:split`ting into an
  empty unnamed buffer.
- Because they're `PATH_TARGETS`, they get the same `<cfile>`-first scope
  heuristic as `filemanager` — sit on any path-looking text and `:Open
  split` with no scope argument opens *that*, not the current buffer again.

Where they get genuinely useful is combined with scope keywords and `git`/
`cwd`, since those are just text resolution and don't care which of the
three ex-commands consumes the result: `:Open vsplit zshrc` next to your
current file, `:Open tab nvim_init` to review config without disturbing your
layout, `:Open split git` to open a repo root path (rare, but valid — most
repo roots are directories, and `:split` on a directory opens Neovim's
built-in directory listing, not an error).

## The terminal handler resolves to a *directory*, always

`:Open terminal` deliberately never tries to open a terminal "on" a file —
`resolve_dir()` in `open/handlers/terminal.lua` takes whatever path the
scope resolves to and, if it's a file, walks up to its parent with
`fnamemodify(path, ":h")` before ever touching `:lcd`. So `:Open terminal
cfile` on a file path drops you into a shell *next to* that file, not an
error about `cd`-ing into a non-directory. Combined with the scope table
above: `:Open terminal git` is a fast way to get a shell at the repo root
regardless of how deep the current buffer is nested inside it.

Also worth knowing: it always opens via `botright split` + `:terminal` +
`startinsert` — there's no vsplit/tab variant of the terminal handler the
way there is for file opening. If you want it elsewhere, move the resulting
terminal window afterward.

## The picker is opt-in, and only fires on real ambiguity

`opts.picker.enabled` is `false` by default, meaning `:Open` with no target
always picks exactly one handler deterministically via `default_target()` —
no prompt, ever. Turning it on doesn't add a prompt to *every* invocation
either: `candidate_targets()` only returns more than one candidate when the
context is genuinely ambiguous — cursor on a URL (`browser` or `notepad`),
or cursor on an existing file path (`filemanager`, `split`, `vsplit`, `tab`).
A tree-buffer node or a non-path, non-URL buffer still resolves to a single
candidate and dispatches immediately even with the picker on. An *explicit*
target (`:Open browser`, or `open.open("browser")` from Lua) always bypasses
the picker entirely, since there's nothing to disambiguate.

If you want the picker's convenience but find it firing more (or less) often
than expected, the fix is almost always in `candidate_targets()`'s notion of
"ambiguous," not a config knob — there isn't one to tune the sensitivity.

## Debug mode as the actual troubleshooting tool

`setup({ debug = true })` is the fastest way to answer "why did `:Open` pick
*that*" instead of reading source. Both `context.lua`'s gather/resolve steps
and `registry.lua`'s dispatch step log to `:messages` when it's on: the raw
signals collected (tree path, cfile, cword, visual, buffer path), what
`resolve()` decided the final text/is_url/is_path were, and which handler
actually got the dispatch call. Leave it off day-to-day — the logging call
itself is gated behind `is_debug()` so there's no cost when disabled — but
flip it on before filing a bug report or before assuming a keyword resolved
to the wrong path; the log line shows the exact `arg`/`target`/`text` triple
that produced the result.

## Wiring in your own habits

If you find yourself typing the same `:Open <target> <scope>` combination
repeatedly, two config surfaces exist specifically so you don't have to
retype it:

- `opts.keymaps` for a *fixed* invocation (`open_default` plus
  `open_<handler key>` for any registered handler — no per-scope keymap
  generation, so a keymap for `:Open split zshrc` specifically still needs a
  plain `vim.keymap.set` yourself).
- `opts.keywords` for a scope you use across *multiple* targets — a keyword
  defined once works as the scope argument to `browser`, `filemanager`,
  `split`, `terminal`, anything, rather than hardcoding the path into one
  keymap.

Reach for `custom_handlers` only when neither covers it — a genuinely new
target, not a shortcut for an existing one with a fixed scope.
