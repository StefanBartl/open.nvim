# Handlers

Each `:Open <target>` handler, and the pieces around handler dispatch that
aren't specific to any one of them.

## System default app handler

`:Open default` hands the target to the OS the way a double-click would —
extension/scheme-based dispatch, so a PDF opens in your PDF viewer and a
`.docx` in Word. The cross-platform dispatch (including WSL→Windows path
translation) lives in `lib.nvim.cross.open_default`, shared rather than
duplicated in this plugin.

- **Module:** `open/handlers/default.lua`
- **Usercmds:** `:Open default`

## Office document auto-redirect

`.docx`, `.xlsx`, `.pptx` (and their legacy/OpenDocument counterparts) are
binary containers — Neovim reading one as text just shows garbage. A
`BufReadCmd` autocmd intercepts a read of any configured extension, hands
the path to the same `lib.nvim.cross.open_default` dispatch the `default`
handler uses, and wipes the placeholder buffer Neovim created for the read.
Fires on any read of a matching path — `:e`, `gf`, a picker, a tree
plugin's `<CR>` — not only `:Open default`.

- **Module:** `open/office_open.lua`
- **Autocmds:** [`../BINDINGS.md#autocmds`](../BINDINGS.md#autocmds)
- **Config:** `opts.office_open.enabled` (default `true`),
  `opts.office_open.extensions` (default
  `{"doc","docx","xls","xlsx","ppt","pptx"}`)

## Browser handlers

`:Open browser` opens the target in the system default browser; plain text
that isn't a URL becomes a Google search query instead of failing. Six
named handlers (`chrome`, `chromium`, `firefox`, `edge`, `brave`, `opera`)
target a specific browser instead of whatever's set as default, and
`safari` is registered but refuses to run outside macOS. A local file path
is opened with the `file://` scheme. Platform dispatch differs by target:
Windows routes the system default straight through `explorer.exe`
(registered protocol handler, no `cmd.exe` re-tokenizing), while a *named*
browser needs `cmd.exe /C start <token>` since `explorer.exe` alone can't
target a specific app.

- **Module:** `open/handlers/browser.lua`
- **Usercmds:** `:Open browser` · `:Open chrome` · `:Open chromium` ·
  `:Open firefox` · `:Open edge` · `:Open brave` · `:Open opera` ·
  `:Open safari`

## File manager reveal

`:Open filemanager` opens a path in the system file manager. With the
default `reveal = true`, a *file* target is selected inside its parent
directory (Explorer `/select,`, Finder `open -R`, or a select-capable Linux
manager); with `reveal = false`, or when no select-capable manager is
found, it opens the parent directory instead. A *directory* target is
always navigated into regardless of `reveal`. `xdg-open` is deliberately
never handed a file when revealing, since that launches the file's default
*application*, not a file manager.

- **Module:** `open/handlers/filemanager.lua`, `lib.nvim.cross.reveal_in_fm`
  (shared with filetree.nvim's `<leader>fm`)
- **Usercmds:** `:Open filemanager`
- **Config:** `opts.filemanager.reveal` (default `true`),
  `opts.filemanager.command` (launcher override, default `nil`)

## Notepad / scratch text editor

`:Open notepad` (alias: `:Open editor`) writes the target text to a
temporary file and opens it in the platform's GUI text editor — Notepad on
Windows, TextEdit on macOS, the first of `xdg-open`/gedit/kate/mousepad/
leafpad/pluma/xed found on PATH on Linux. On WSL the temp file's path is
converted through `lib.nvim.cross.fs.wslpath`'s `to_win()` before being
handed to `notepad.exe`, since a Windows binary cannot open a Linux-side
path.

- **Module:** `open/handlers/notepad.lua`
- **Usercmds:** `:Open notepad` · `:Open editor`

## Neovim split / vsplit / tab handlers

`:Open split`, `:Open vsplit`, and `:Open tab` open a file path inside the
current Neovim session via `:split`, `:vsplit`, and `:tabedit`
respectively, instead of handing it to any external program. All three
reject URL targets outright and validate the path exists on disk before
running the ex-command.

- **Module:** `open/handlers/nvim_internal.lua`
- **Usercmds:** `:Open split` · `:Open vsplit` · `:Open tab`

## Terminal-in-directory handler

`:Open terminal` opens a terminal split (`botright split` + `:terminal`,
already in insert mode) rooted in the target's directory via `:lcd`. A
directory target is used as-is; a file target resolves to its parent
directory, so `:Open terminal cfile` on a file path drops you into a shell
next to that file rather than trying to `cd` into it.

- **Module:** `open/handlers/terminal.lua` (`resolve_dir`, `M.register_all`)
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
