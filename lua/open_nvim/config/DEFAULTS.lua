---@module 'open_nvim.config.DEFAULTS'
---@brief Default configuration values for open.nvim.

---@type OpenNvim.Config
return {
  command             = "Open",
  default_filemanager = "filemanager",
  default_browser     = "browser",
  -- Handler module keys to load during setup().
  -- Valid values: "filemanager" | "browser" | "notepad" | "nvim_internal" | "default"
  handlers         = { "filemanager", "browser", "notepad", "nvim_internal", "default" },
  builtin_keywords = true,   -- set false to disable all built-in scope keywords
  keywords         = {},     -- user-defined keyword → path overrides / additions

  -- `:Open urlview` / `:UrlView` — list links in a scope.
  urlview = {
    command        = "UrlView",  -- standalone wrapper command; set false to skip it
    sort           = "none",     -- "none" | "file" | "kind" | "alpha"
    output         = "picker",   -- "picker" | "table" | "clipboard" | "mdlinks" | "csv"
    mdlinks_output = "clipboard",
  },
}
