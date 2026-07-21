# open.nvim — Integrations

## urlview.nvim (superseded)

> **open.nvim now has this built in.** Use
> [`:Open viewer` / `:UrlView`](commands.md#open-viewer--urlview--mdlinksview) instead —
> it needs no third-party plugin, scans more scopes (files, directories, all
> buffers, a visual range — not just the current buffer), and can export to a
> table, markdown links, the clipboard, or a file in addition to opening a
> pick.

The `open.integrations.urlview` module remains for anyone still running
[urlview.nvim](https://github.com/axieax/urlview.nvim). It is opt-in and is
not loaded by `open.setup()`.

It registers a custom `open_in_browser` action so picked URLs are routed
through the `browser` handler (or whichever handler `default_browser` is set
to) instead of duplicating cross-platform browser-launch logic in a second
place.

```lua
{
  "axieax/urlview.nvim",
  lazy = true,
  cmd = { "UrlView" },
  dependencies = { "StefanBartl/open.nvim" },
  config = function()
    require("open.integrations.urlview").setup()
  end,
}
```

`setup(opts)` registers the `open_in_browser` action, then calls
`urlview.setup(opts)` with `default_action = "open_in_browser"` (and
`default_picker` set to telescope/fzf-lua if available) unless you already
set those yourself. Pass `false` instead of a table to only register the
action without calling `urlview.setup()`.

### Migrating off it

Drop the `axieax/urlview.nvim` spec entirely. `:UrlView` is then provided by
open.nvim itself under the same command name, so existing keymaps and muscle
memory keep working.

Note that both cannot own `:UrlView` at once — whichever registers last wins.
If you want a different name for open.nvim's wrapper, or none at all, set
`viewer.commands.urls` (see [configuration.md](configuration.md)).
