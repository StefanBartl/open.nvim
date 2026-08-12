# open.nvim — Features

`:Open [target] [scope]` routes the thing under your cursor — path, URL, or
plain text — to a handler. `:Open viewer` (with `:UrlView` / `:MDLinksView`
shortcuts) goes the other way: it finds links and hands you a picker. See
[README.md](../README.md) for a quickstart and [docs/commands.md](commands.md)
for the exhaustive command/flag reference — this file is "what exists and
why", not "every flag".

## Context-aware dispatch

`:Open` with no explicit target figures out what you mean from where your
cursor is, without a subcommand. In a Neo-tree, nvim-tree, or netrw buffer it
takes the node under the cursor. Otherwise it looks at `<cfile>`, `<cWORD>`,
a visual selection, and the buffer path, in that priority order, and decides
between the configured file-manager handler and the configured browser
handler based on whether the candidate text looks like a URL.

- **Module:** `open/context.lua` (`gather`, `resolve`, `default_target`), `open/init.lua` (`open`)
- **Usercmds:** `../BINDINGS.md#usrcmds`
- **Config:** `opts.default_filemanager` (default `"filemanager"`), `opts.default_browser` (default `"browser"`)

Explicit scope tokens (`%`, `cfile`, `cwd`, `git`, `path=<path>`, or a named
keyword) bypass the heuristic entirely — see
[docs/commands.md](commands.md#scope-2nd-argument).

## Handler-choice picker

Opt-in `vim.ui.select` prompt for a no-target `:Open` when more than one
handler would plausibly apply to the current context (e.g. cursor on a URL:
browser or notepad; cursor on an existing file path: file manager, split,
vsplit, tab). Off by default, so existing muscle memory ("`:Open` always just
picks filemanager") does not change under anyone who hasn't opted in. Any
`vim.ui.select` override (telescope-ui-select, fzf-lua, dressing.nvim) is
picked up automatically through `respect_override = true`; the built-in
selector is used otherwise.

- **Module:** `open/picker.lua` (`select`), `open/context.lua` (`candidate_targets`)
- **Config:** `opts.picker.enabled` (default `false`)

An explicit target (`:Open browser`, `open.open("browser")`) always bypasses
the picker.

## System default app handler

`:Open default` hands the target to the OS the way a double-click would —
extension/scheme-based dispatch, so a PDF opens in your PDF viewer and a
`.docx` in Word. The cross-platform dispatch (including WSL→Windows path
translation) lives in `lib.nvim.cross.open_default`, shared rather than
duplicated in this plugin.

- **Module:** `open/handlers/default.lua`
- **Usercmds:** `:Open default`

## Browser handlers

`:Open browser` opens the target in the system default browser; plain text
that isn't a URL becomes a Google search query instead of failing. Six named
handlers (`chrome`, `chromium`, `firefox`, `edge`, `brave`, `opera`) target a
specific browser instead of whatever's set as default, and `safari` is
registered but refuses to run outside macOS. A local file path is opened
with the `file://` scheme rather than handed to the OS default-app dispatch.

- **Module:** `open/handlers/browser.lua`
- **Usercmds:** `:Open browser` · `:Open chrome` · `:Open chromium` · `:Open firefox` · `:Open edge` · `:Open brave` · `:Open opera` · `:Open safari`

Platform dispatch differs by target: Windows routes the system default
through `explorer.exe` directly (registered protocol handler, no `cmd.exe`
re-tokenizing), but a *named* browser needs `cmd.exe /C start <token>` since
`explorer.exe` alone can't target a specific app — the URL is shielded from
`cmd.exe`'s tokenizer for that path. WSL prefers `wslview`, then
`explorer.exe`, then falls back to the same `cmd.exe start` route. See
`open/handlers/browser.lua`'s own comments for exactly why URLs containing
`&` need the escaping they get.

## File manager reveal

`:Open filemanager` opens a path in the system file manager. With the
default `reveal = true`, a *file* target is selected inside its parent
directory (Explorer `/select,`, Finder `open -R`, or a select-capable Linux
manager); with `reveal = false`, or when no select-capable manager is found,
it opens the parent directory instead. A *directory* target is always
navigated into regardless of `reveal` — there's nothing to select for a
directory. `xdg-open` is deliberately never handed a file when revealing, because
that launches the file's default *application*, not a file manager.

- **Module:** `open/handlers/filemanager.lua`, `lib.nvim.cross.reveal_in_fm` (shared with filetree.nvim's `<leader>fm`)
- **Usercmds:** `:Open filemanager`
- **Config:** `opts.filemanager.reveal` (default `true`), `opts.filemanager.command` (launcher override, default `nil`)

On Windows, `explorer.exe` spawned from a terminal-hosted Neovim creates its
window *behind* the editor — Windows only grants `SetForegroundWindow` to
the process that owns the current foreground window, which is the terminal
host, not `nvim.exe`. `reveal_in_fm` raises the new window explicitly to
work around this; as of this writing that fix is still unverified on a real
Windows host per [docs/ROADMAP.md](ROADMAP.md).

## Notepad / scratch text editor

`:Open notepad` (alias: `:Open editor`) writes the target text to a
temporary file and opens it in the platform's GUI text editor — Notepad on
Windows, TextEdit on macOS, the first of `xdg-open`/gedit/kate/mousepad/
leafpad/pluma/xed found on PATH on Linux.

- **Module:** `open/handlers/notepad.lua`
- **Usercmds:** `:Open notepad` · `:Open editor`

**WSL gets a real fix, not just a fallback.** `notepad.exe` is a Windows
binary — it cannot open a Linux-side path like `/tmp/nvimXXX/0`, and would
report the file as not found even though it exists. On WSL the handler
converts the temp file's path through `lib.nvim.cross.fs.wslpath`'s
`to_win()` (the `\\wsl$\...` form) *before* handing it to `notepad.exe`, and
aborts with an error notification if that conversion itself fails, rather
than launching Notepad against a path it can't read.

## Neovim split / vsplit / tab handlers

`:Open split`, `:Open vsplit`, and `:Open tab` open a file path inside the
current Neovim session via `:split`, `:vsplit`, and `:tabedit` respectively,
instead of handing it to any external program. All three reject URL targets
outright and validate the path exists on disk before running the ex-command.

- **Module:** `open/handlers/nvim_internal.lua`
- **Usercmds:** `:Open split` · `:Open vsplit` · `:Open tab`

## Terminal-in-directory handler

`:Open terminal` opens a terminal split (`botright split` + `:terminal`,
already in insert mode) rooted in the target's directory via `:lcd`. A
directory target is used as-is; a file target resolves to its parent
directory, so `:Open terminal cfile` on a file path drops you into a shell
next to that file rather than trying to `cd` into it.

- **Module:** `open/handlers/terminal.lua`
- **Usercmds:** `:Open terminal`

## Image handler

`:Open image` renders the target image inside the terminal via
[images.nvim](https://github.com/StefanBartl/images.nvim) instead of
launching an external viewer that steals window focus. images.nvim is a
soft dependency: when it isn't installed, or its `show()` call reports
failure, the handler falls back to the system default application handler
so `:Open image` never dead-ends into an error with nothing happening.

- **Module:** `open/handlers/image.lua`
- **Usercmds:** `:Open image`
- **Config:** included in `opts.handlers` by default (`"image"`)

## Built-in scope keywords

Named shortcuts to commonly edited config files, usable as the scope
argument to any handler (`:Open split zshrc`, `:Open default MY_ROADMAP`).
Covers shell profiles (`zshrc`, `bashrc`, `pwsh_profile`, …), editor configs
(`nvim_init`, `vimrc`), terminal emulators (`tmux_conf`, `kitty_conf`, …),
git (`gitconfig`, `gitignore_global` resolved from `git config`), SSH,
package-manager RC files, and system files (`hosts`, `wsl_conf`). Several
resolve dynamically rather than being static paths — `pwsh_profile` shells
out to `pwsh`/`powershell` to read the real `$PROFILE`, `gitignore_global`
and `gitmessage` read actual `git config` values before falling back to
conventional paths — and those dynamic resolvers only run when the keyword
is actually used, not at startup.

- **Module:** `open/keywords.lua` (`builtin`)
- **Config:** `opts.builtin_keywords` (default `true`), `opts.keywords` (user overrides/additions, default `{}`)

User keywords in `opts.keywords` override a built-in of the same name; set
`builtin_keywords = false` to start from an empty table. See
[docs/keywords.md](keywords.md) for the full list.

## Custom handlers

`opts.custom_handlers` registers additional `OpenNvim.Handler` entries
(`key`, `desc`, `run(ctx)`) straight from `setup()`, without calling
`require("open.registry").register()` directly. They're registered after
the built-in handler modules, so a `key` reused here overwrites a built-in
handler of the same name (with a warning, not silently).

- **Module:** `open/registry.lua` (`register`), `open/init.lua` (`setup`)
- **Config:** `opts.custom_handlers` (default `{}`)

## Keymaps

`setup()` accepts an optional `keymaps` table with exactly three recognized
keys — `open_default`, `open_browser`, `open_manager` — that register a
normal-mode keymap for a fixed `:Open` / `:Open browser` / `:Open
filemanager` invocation. No default keymaps are registered; an unrecognized
key warns and registers nothing.

- **Module:** `open/bindings/keymaps.lua`
- **Keymaps:** `../BINDINGS.md#keymaps`
- **Config:** `opts.keymaps` (default `{}`)

## Health check

`:checkhealth open` reports the Neovim version, `vim.system` availability,
`lib.nvim` presence (the `:Open` command itself is built on
`lib.nvim.usercmd.composer`), detected platform, per-platform tool
availability (`explorer.exe`, `wslpath`, `xdg-open`, candidate file managers
and text editors, any browser on PATH), and the full list of currently
registered handlers with their descriptions.

- **Module:** `open/health.lua` (`check`)
- **Usercmds:** `:checkhealth open`

## Link viewer — `:Open viewer` / `:UrlView` / `:MDLinksView`

- **Tab:** true
- **Module:** `open/viewer/init.lua`, `open/viewer/scan.lua`
- **Usercmds:** `:Open viewer [kind] [scope] [options]` · `:UrlView [scope] [options]` · `:MDLinksView [scope] [options]`
- **Config:** `opts.viewer` (`commands`, `sort`, `output`, `mdlinks_output`, `open_file`)

`:Open viewer` scans a scope for links and either hands you a picker or
exports the result. It replaces the former
[urlview.nvim](https://github.com/axieax/urlview.nvim) dependency with a
native implementation built on `lib.nvim.harvest`, and covers more ground
than that plugin did: files, whole directories, every listed buffer, and a
visual range, not just the current buffer.

### Kind vs scope

The scan recognizes three syntactic shapes — bare URLs (`https://…`,
`www.…`), markdown links (`[text](target)`, reported by target with the
label preserved), and, opt-in via `--paths`, bare filesystem paths that
actually exist on disk. `kind` filters on top of that:

- `urls` keeps links whose **target** is browser-openable — including a
  markdown link to `https://…`
- `mdlinks` keeps links written with markdown **syntax**, whatever they
  point at — including one to a local file
- `files` keeps local (non-URL) targets
- `paths` keeps bare filesystem paths
- `all` (default) keeps everything

The two "URL" senses deliberately overlap: `urls` asks "can a browser open
this", `mdlinks` asks "was this written with brackets". A
`[docs](https://x.dev)` satisfies both. That distinction is what lets
`:UrlView` mean "things I can open in a browser" instead of merely "things
without brackets" — see `open/viewer/init.lua`'s `FILTERS` table.

Scope is the current buffer by default; `cwd` scans every file under the
working directory recursively (skipping `.git`, `node_modules`, and other
conventional junk via `lib.nvim`'s shared ignore list, plus binary/oversized
files), `buffers` scans every listed buffer, a bare path scans one file or
directory, and a visual/line range (`:'<,'>UrlView`, `:10,20UrlView`) scans
only those lines. Links inside fenced code blocks are skipped. A URL already
consumed by a markdown link isn't reported a second time as a bare URL — the
markdown pass records the byte spans it matched and the bare-URL pass skips
anything inside one.

Relative markdown targets resolve against the directory of the file they
were found in, not the process cwd, so a `[x](../../lua/init.lua)` written
in a deeply nested doc still opens correctly from a results list gathered
elsewhere.

### Output

Default output is the interactive picker (`lib.nvim.ui.kit.chooser`): the
whole current line is highlighted, the cursor only moves up/down (`j`/`k`
and arrows — `h`/`l`/`0`/`$`/`w`/`b` are mapped to `<Nop>`), and `<CR>` is
**kind-aware**: a URL goes to the configured browser handler, a local file
opens through the handler named by `opts.viewer.open_file` (`"split"` by
default — this is what makes following a markdown link land you in an
editable buffer instead of the system file manager), and a directory goes
to the file manager. A `file.md#heading` target does a best-effort jump to
that heading after opening.

Non-picker outputs (`out=table`, `csv`, `mdlinks`, `clipboard`, `echo`,
`file:<path>`) render the whole result set instead of opening anything —
`mdlinks` reuses an existing markdown label when there is one and otherwise
labels a bare URL/path with its host/basename, since `[](target)` would
render as an invisible link.

### Lua API

Every step — `collect`, `filter`, `sort`, `labels`/`rows`/`as_markdown`,
`open`, and the all-in-one `run` — is exposed on `require("open.viewer")`
for callers that want one piece without going through a user command. See
[docs/api.md](api.md#link-listing) for signatures and
[docs/commands.md](commands.md#open-viewer--urlview--mdlinksview) for every
flag and its default.
