# open.nvim — Health Check

```
:checkhealth open
```

Reports:
- Neovim version and `vim.system` availability
- `lib.nvim.notify` and `lib.nvim.bindings.usercmd.composer` presence (the `:Open`
  command is built on the composer)
- Detected platform (Windows / WSL / macOS / Linux)
- Per-platform tool availability (explorer.exe, xdg-open, wslview, …)
- `setup()` options: unrecognized keys (with a "did you mean" hint) and
  values that did not fit their option — each falls back to its default
  instead of aborting `setup()` or being silently ignored
- `office_open` auto-redirect status and its configured extensions
- All registered handlers and their descriptions
