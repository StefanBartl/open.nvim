# open.nvim — Roadmap

Empty by design, not by neglect: every feature this file used to track
(custom handlers via `setup()`, the `terminal` handler, keymap config, the
`git` scope, picker integration, the `reveal` option, debug mode, the
per-invocation context cache, `:Open viewer` / `:UrlView` / `:MDLinksView`)
has shipped.

When a new feature is planned, it goes here as a checklist entry until it
ships.

## Open

- [ ] **Windows: the file-manager window opens without focus.** `:Open
      filemanager` reports `Opening in file manager: <path>` and a window is
      genuinely created (verified by enumerating `Shell.Application.Windows()`
      right after an invocation) — it just stays behind Neovim, so it reads as
      "nothing happened". Not a spawn failure: a direct
      `jobstart({ "explorer.exe", "/select,<file>" }, { detach = true })`
      returns a valid job id and produces a window too (explorer.exe exiting 1
      is normal). Suspected cause is Windows' foreground lock. Candidates, in
      order: `AllowSetForegroundWindow` before the spawn, a `SetForegroundWindow`
      follow-up on the new window (filetree.nvim's `open_in_fm/reuse_win.lua`
      already has that call), or launching via
      `Shell.Application.Explore(path)`. The fix belongs in
      `lib.nvim.cross.reveal_in_fm` so filetree.nvim's `<leader>fm` gets it too.
- [ ] **Verify the non-Windows reveal paths on a real host.** The Linux branch
      now picks a select-capable manager (nautilus, nemo, `dolphin --select`,
      thunar, caja) and keeps `xdg-open` away from files — handing it a file
      launches that file's default application instead of a file manager. That
      ordering is derived from the managers' documented flags, not executed.
      macOS `open -R` is unverified in the same way.
