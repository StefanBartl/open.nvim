---@meta
---@module 'open_nvim.@types'
---@brief Shared type definitions for open.nvim.

-- ---------------------------------------------------------------------------
-- Handler keys
-- ---------------------------------------------------------------------------

---@alias OpenNvim.HandlerKey
---| '"default"'       # System default application (like a double-click)
---| '"browser"'       # System default browser
---| '"chrome"'        # Google Chrome / Chromium
---| '"chromium"'      # Chromium
---| '"edge"'          # Microsoft Edge
---| '"firefox"'       # Mozilla Firefox
---| '"safari"'        # Safari (macOS only)
---| '"filemanager"'   # System file manager
---| '"notepad"'       # System default GUI text editor
---| '"editor"'        # Alias for notepad
---| '"split"'         # Open file in Neovim horizontal split
---| '"vsplit"'        # Open file in Neovim vertical split
---| '"tab"'           # Open file in Neovim new tab
---| string            # User-registered extension key

-- ---------------------------------------------------------------------------
-- Platform
-- ---------------------------------------------------------------------------

---Platform flags, determined once at startup and cached for the session.
---@class OpenNvim.Platform
---@field is_win   boolean  True on native Windows (win32 / win64)
---@field is_mac   boolean  True on macOS
---@field is_wsl   boolean  True when running inside WSL
---@field is_linux boolean  True on any Linux (including WSL)

-- ---------------------------------------------------------------------------
-- Context
-- ---------------------------------------------------------------------------

---Resolved text and metadata passed to every handler's run() function.
---@class OpenNvim.Context
---@field text    string   The resolved text: path, URL, or plain text
---@field is_url  boolean  True when text looks like a URL (http/https/ftp/www)
---@field is_path boolean  True when text resolves to an existing filesystem path

-- ---------------------------------------------------------------------------
-- Signals
-- ---------------------------------------------------------------------------

---Raw, target-agnostic signals gathered from the current editor state.
---@class OpenNvim.Signals
---@field tree_path   string|nil  Node path when the cursor is in a tree buffer (neo-tree/nvim-tree/netrw)
---@field cfile       string|nil  Raw <cfile> text under the cursor, if any
---@field cfile_path  string|nil  cfile resolved to an existing path on disk, if any
---@field cword       string|nil  Raw <cWORD> text under the cursor, if any
---@field visual      string|nil  Visual selection text (only set while in Visual mode via <Cmd>)
---@field buffer_path string|nil  Path of the current buffer, if it has a name

-- ---------------------------------------------------------------------------
-- Handler
-- ---------------------------------------------------------------------------

---A handler registered in the Open registry.
---@class OpenNvim.Handler
---@field key  string                                  Unique completion key, e.g. "chrome"
---@field desc string                                  Human-readable one-line description
---@field run  fun(ctx: OpenNvim.Context): boolean     Returns true when dispatch succeeded

-- ---------------------------------------------------------------------------
-- UrlView
-- ---------------------------------------------------------------------------

---@alias OpenNvim.UrlView.Kind
---| '"url"'     # bare URL (scheme://… or www.…)
---| '"mdlink"'  # markdown inline link [text](target)
---| '"path"'    # filesystem path that exists on disk

---One link found by `:Open urlview`, with enough provenance to jump back to it.
---@class OpenNvim.UrlView.Link
---@field target  string                  The thing to open (URL or absolute path)
---@field kind    OpenNvim.UrlView.Kind   How it was recognized
---@field display string                  Text as it appeared in the source
---@field text    string|nil              Label, for markdown links only
---@field lnum    integer                 1-based line number in its file/buffer
---@field col     integer                 0-based byte column
---@field file    string|nil              Absolute source path, when known
---@field bufnr   integer|nil             Source buffer, when it came from one

---@class OpenNvim.UrlView.Config
---@field command string|nil  Standalone wrapper command name; false/nil disables it (default "UrlView")
---@field sort    string|nil  Default sort: "none"|"file"|"kind"|"alpha" (default "none")
---@field output  string|nil  Default output: "picker"|"table"|"clipboard"|"mdlinks"|"csv" (default "picker")
---@field mdlinks_output string|nil  Sink for `out=mdlinks` (default "clipboard")

-- ---------------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------------

---@class OpenNvim.Config
---@field command             string    User command name (default "Open")
---@field default_filemanager string    Handler key for path-default (default "filemanager")
---@field default_browser     string    Handler key for URL-default (default "browser")
---@field handlers            string[]  Handler module keys to load
---@field builtin_keywords    boolean   Load built-in scope keywords (default true)
---@field keywords            table<string, string|fun(): string|nil>  Named scope aliases: keyword → path or resolver
---@field urlview             OpenNvim.UrlView.Config  `:Open urlview` / `:UrlView` settings

return {}
