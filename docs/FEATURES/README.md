# open.nvim — Features

This folder is the machine-readable catalog behind `documentation.nvim`'s
Features tab, following the shape documented in
[`FEATURES_FORMAT.md`](https://github.com/StefanBartl/documentation.nvim/blob/main/docs/FEATURES_FORMAT.md).
For prose written for a human reading top-to-bottom, see
[`docs/features.md`](../features.md) instead — this folder is the same
material regrouped into `## Feature` cards.

Three themes:

- [`CORE.md`](CORE.md) — dispatch, scope resolution, config surfaces that
  apply across every handler (picker, keymaps, keywords, debug mode, health
  check).
- [`HANDLERS.md`](HANDLERS.md) — the individual `:Open <target>` handlers.
- [`VIEWER.md`](VIEWER.md) — `:Open viewer` / `:UrlView` / `:MDLinksView`.
