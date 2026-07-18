# open.nvim — Integrations

## urlview.nvim

[urlview.nvim](https://github.com/axieax/urlview.nvim) lists URLs found in
the current buffer and lets you pick one. open.nvim provides a custom
`open_in_browser` action so picked URLs are routed through the `browser`
handler above (or whichever handler `default_browser` is set to) instead of
duplicating cross-platform browser-launch logic in a second place.

```lua
{
  "axieax/urlview.nvim",
  lazy = true,
  cmd = { "UrlView" },
  dependencies = { "StefanBartl/open.nvim" },
  config = function()
    require("open_nvim.integrations.urlview").setup()
  end,
}
```

`setup(opts)` registers the `open_in_browser` action, then calls
`urlview.setup(opts)` with `default_action = "open_in_browser"` (and
`default_picker` set to telescope/fzf-lua if available) unless you already
set those yourself. Pass `false` instead of a table to only register the
action without calling `urlview.setup()`.
