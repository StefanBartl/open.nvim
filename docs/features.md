# open.nvim — Features

A single `:Open [target] [scope]` command that routes the thing under your
cursor — path, URL, or plain text — to the right destination: system file
manager, browser (with named-browser support), GUI text editor, or Neovim
split/tab. Context-aware: knows when you are in a Neo-tree, nvim-tree, or
netrw buffer and opens the node under the cursor directly.

See [README.md](../README.md) for a quickstart, and
[docs/commands.md](commands.md) for the full command reference.

## Table of content

- [Handlers](#handlers)
- [Smart context resolution](#smart-context-resolution)

## Handlers

| Handler | What it opens | Platform |
|---|---|---|
| `default` | Open in the system default app (like double-click) | all |
| `browser` | URL or text → system default browser (text → Google search) | all |
| `chrome` | Google Chrome | Linux / WSL / Windows / macOS |
| `chromium` | Chromium | Linux / WSL / Windows / macOS |
| `firefox` | Mozilla Firefox | Linux / WSL / Windows / macOS |
| `edge` | Microsoft Edge | Linux / WSL / Windows / macOS |
| `safari` | Safari | macOS only |
| `filemanager` | Path → system file manager (Explorer / Finder / xdg-open) | all |
| `notepad` | Text → temp file → GUI text editor | all |
| `editor` | Alias for `notepad` | all |
| `split` | File path → Neovim horizontal split | all |
| `vsplit` | File path → Neovim vertical split | all |
| `tab` | File path → Neovim new tab | all |

## Smart context resolution

- In a **Neo-tree / nvim-tree / netrw** buffer → opens the node under the cursor
- Cursor on a **URL** with no explicit target → falls back to `browser`
- Cursor on a **file path** → falls back to `filemanager`
- Visual selection → used as the target text
