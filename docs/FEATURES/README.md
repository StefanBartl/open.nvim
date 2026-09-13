# open.nvim — Features

Opening something outside the editor is a small problem that fragments into
many small answers: `gx` for URLs, `netrw` for a directory, a shell command for
the file manager, and nothing at all for "the thing under my cursor, in the
right application". This plugin is the one dispatcher over all of them.

| Area | Does |
| --- | --- |
| **One command** | `:Open [target] [scope]` — the target names the destination, the scope names what to send there; both complete with `<Tab>` |
| **Destinations** | System default app, the browser (including named browsers), a GUI text editor, a terminal split rooted in the target's directory, an inline image viewer, or a Neovim split, vsplit or tab |
| **Context awareness** | It knows when you are in a Neo-tree, nvim-tree or netrw buffer and opens the node under the cursor directly, with no scope argument |
| **Office redirect** | Reading a `.docx` / `.xlsx` / `.pptx` — or a legacy or OpenDocument counterpart — opens the system app instead of loading garbled text into a buffer |
| **The viewer** | `:Open viewer`, with `:UrlView` and `:MDLinksView` as shortcuts, lists the links in a buffer, a selection, a directory or the project, then hands you a picker |
| **Export** | The same list as a Markdown table, as Markdown links, to the clipboard, or to a file |

Pick a URL in the viewer and it opens in your browser; pick a Markdown link and
the document opens in a Neovim split.

This folder is the machine-readable catalog behind `documentation.nvim`'s
Features tab, following the shape documented in
[`FEATURES_FORMAT.md`](https://github.com/StefanBartl/documentation.nvim/blob/main/docs/FEATURES_FORMAT.md).

Three themes:

- [`CORE.md`](CORE.md) — dispatch, scope resolution, config surfaces that
  apply across every handler (picker, keymaps, keywords, debug mode, health
  check).
- [`HANDLERS.md`](HANDLERS.md) — the individual `:Open <target>` handlers.
- [`VIEWER.md`](VIEWER.md) — `:Open viewer` / `:UrlView` / `:MDLinksView`.
