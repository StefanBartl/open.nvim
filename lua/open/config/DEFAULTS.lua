---@module 'open.config.DEFAULTS'
---@brief Default configuration values for open.nvim.

---@type OpenNvim.Config
return {
  command             = "Open",
  default_filemanager = "filemanager",
  default_browser     = "browser",
  -- Handler module keys to load during setup().
  -- Valid values: "filemanager" | "browser" | "notepad" | "nvim_internal" |
  -- "default" | "terminal"
  handlers = {
    "filemanager", "browser", "notepad", "nvim_internal", "default", "terminal",
  },
  builtin_keywords = true,   -- set false to disable all built-in scope keywords
  keywords         = {},     -- user-defined keyword → path overrides / additions

  -- User-defined handlers, registered in addition to the `handlers` module
  -- list above. Each entry is an OpenNvim.Handler: { key, desc, run }.
  custom_handlers = {},

  -- Optional keymaps for common invocations. Empty by default — open.nvim
  -- ships with no default keymaps. Valid keys: "open_default" | "open_browser"
  -- | "open_manager". Values are the {lhs} passed to vim.keymap.set().
  keymaps = {},

  -- `filemanager` handler settings.
  filemanager = {
    -- true (default): reveal a file (select it in its parent directory).
    -- false: navigate to it (open its parent directory without selecting).
    -- Directories are always navigated into, regardless of this setting.
    reveal = true,
  },

  -- `:Open viewer [kind]` — list links in a scope.
  viewer = {
    -- Standalone wrapper commands, one per filter. Set a value to false to
    -- skip registering that command.
    commands = {
      urls    = "UrlView",      -- only browser-openable targets
      mdlinks = "MDLinksView",  -- only markdown-syntax links
      all     = false,          -- everything; use `:Open viewer` instead
    },
    sort           = "none",      -- "none" | "file" | "kind" | "alpha"
    output         = "picker",    -- "picker" | "table" | "clipboard" | "mdlinks" | "csv"
    mdlinks_output = "clipboard", -- sink for `out=mdlinks`
    open_file      = "split",     -- handler for a picked local file ("split"/"vsplit"/"tab")
  },
}
