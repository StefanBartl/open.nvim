---@module 'open.config.DEFAULTS'
---@brief Default configuration values for open.nvim.

---@type OpenNvim.Config
return {
  command = "Open",
  default_filemanager = "filemanager",
  default_browser = "browser",
  -- Handler module keys to load during setup().
  -- Valid values: "filemanager" | "browser" | "notepad" | "nvim_internal" |
  -- "default" | "terminal" | "image"
  handlers = {
    "filemanager",
    "browser",
    "notepad",
    "nvim_internal",
    "default",
    "terminal",
    "image",
  },
  builtin_keywords = true, -- set false to disable all built-in scope keywords
  keywords = {}, -- user-defined keyword → path overrides / additions

  -- User-defined handlers, registered in addition to the `handlers` module
  -- list above. Each entry is an OpenNvim.Handler: { key, desc, run }.
  custom_handlers = {},

  -- Optional keymaps for common invocations. Empty by default — open.nvim
  -- ships with no default keymaps. Keys are "open_default" (bare `:Open`),
  -- "open_<handler key>" for any registered handler — open_browser,
  -- open_filemanager, open_split, open_vsplit, open_tab, open_terminal,
  -- open_image, open_notepad — plus the historical alias "open_manager"
  -- (= open_filemanager). Values are the {lhs}.
  keymaps = {},

  -- `filemanager` handler settings.
  filemanager = {
    -- true (default): reveal a file (select it in its parent directory).
    -- false: navigate to it (open its parent directory without selecting).
    -- Directories are always navigated into, regardless of this setting.
    reveal = true,

    -- Launcher override: a string ("thunar") or an argv list
    -- ({ "dolphin", "--select" }). The resolved path is appended as the last
    -- argument and the built-in platform dispatch is skipped entirely.
    -- nil (default) → detect per platform.
    command = nil,
  },

  -- Redirect MS Office documents (and compatible formats) to the system
  -- default application instead of loading them as a text buffer. Fires on
  -- ANY read of a matching path — :e, gf, a picker, filetree.nvim's <CR> —
  -- via a BufReadCmd autocmd, not just `:Open default`.
  office_open = {
    enabled = true,
    extensions = { "doc", "docx", "xls", "xlsx", "ppt", "pptx" },
  },

  -- When true, logs every context-gather and dispatch step to :messages.
  debug = false,

  -- When called with no explicit target and more than one handler is a
  -- meaningful choice for the current context, show a vim.ui.select picker
  -- instead of silently picking one. Off by default (unchanged behavior).
  picker = { enabled = false },

  -- nvzone/menu integration (opt-in on the host side; entries provided by
  -- open.integrations.menu). open.nvim never opens nvzone/menu itself — this
  -- only gates whether M.items()/M.submenu() return entries at all.
  menu = {
    enable = true,
  },

  -- `:Open viewer [kind]` — list links in a scope.
  viewer = {
    -- Standalone wrapper commands, one per filter. Set a value to false to
    -- skip registering that command.
    commands = {
      urls = "UrlView", -- only browser-openable targets
      mdlinks = "MDLinksView", -- only markdown-syntax links
      all = false, -- everything; use `:Open viewer` instead
    },
    sort = "none", -- "none" | "file" | "kind" | "alpha"
    output = "picker", -- "picker" | "table" | "clipboard" | "mdlinks" | "csv"
    mdlinks_output = "clipboard", -- sink for `out=mdlinks`
    open_file = "split", -- handler for a picked local file ("split"/"vsplit"/"tab")
  },
}
