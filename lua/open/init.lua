---@module 'open'
---@brief Entry point for open.nvim — :Open command and public Lua API.
---@description
--- Registers the :Open [target] [scope] user command with tab-completion
--- over the registered handler names (1st arg) and explicit scope tokens
--- (2nd arg).
---
--- Target resolution (1st arg):
---   Explicit handler key (e.g. "filemanager") or, if omitted, an automatic
---   choice based on context: tree buffer → configured filemanager handler,
---   URL-like cfile/cword → configured browser handler, otherwise filemanager.
---
--- Scope resolution (2nd arg):
---   "%"           → current buffer path
---   "cfile"       → <cfile> under the cursor
---   "path=<path>" → literal path given after "path="
---   (omitted)     → target-aware heuristic (see open.context)
---@see open.context
---@see open.registry

local M = {}

-- Map of handler-module keys (used in cfg.handlers) to require paths.
local HANDLER_MODULES = {
  filemanager   = "open.handlers.filemanager",
  browser       = "open.handlers.browser",
  notepad       = "open.handlers.notepad",
  nvim_internal = "open.handlers.nvim_internal",
  default       = "open.handlers.default",
  terminal      = "open.handlers.terminal",
}

-- ---------------------------------------------------------------------------
-- Public Lua API
-- ---------------------------------------------------------------------------

---Open a target programmatically.
---@param target string|nil  Handler key; nil → context-aware default.
---@param scope  string|nil  Scope token: "%", "cfile", "path=…", or literal.
function M.open(target, scope)
  local context  = require("open.context")
  local registry = require("open.registry")
  local signals  = context.gather()

  local t   = target and target:lower() or context.default_target(signals)
  local ctx = context.resolve(scope, t, signals)

  if not ctx then
    require("lib.nvim.notify").create("[open]").warn("Nothing to open")
    return
  end

  registry.dispatch(t, ctx)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

---Configure open.nvim and register the :Open user command.
---@param opts OpenNvim.Config|nil
function M.setup(opts)
  local cfg_mod = require("open.config")
  cfg_mod.setup(opts)
  local cfg = cfg_mod.get()

  -- Load & register handler modules
  local registry = require("open.registry")
  for _, key in ipairs(cfg.handlers) do
    local mod_path = HANDLER_MODULES[key]
    if mod_path then
      local ok, mod = pcall(require, mod_path)
      if ok and type(mod) == "table" and type(mod.register_all) == "function" then
        pcall(mod.register_all, registry.register)
      end
    else
      require("lib.nvim.notify").create("[open]").warn(
        "Unknown handler module key: '" .. key .. "'"
      )
    end
  end

  -- Register user-defined handlers from `custom_handlers`.
  for _, handler in ipairs(cfg.custom_handlers or {}) do
    registry.register(handler)
  end

  -- Register :Open command
  require("open.bindings.usrcmds").register(cfg)

  -- Register optional keymaps (none by default).
  require("open.bindings.keymaps").register(cfg)
end

return M
