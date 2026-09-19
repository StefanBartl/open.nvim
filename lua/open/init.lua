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
---   "cwd"         → Neovim's current working directory
---   "git"         → nearest Git root (walks up from the cwd for a `.git` marker)
---   "path=<path>" → literal path given after "path="
---   (omitted)     → target-aware heuristic (see open.context)
---@see open.context
---@see open.registry

local M = {}

-- Map of handler-module keys (used in cfg.handlers) to require paths.
local HANDLER_MODULES = {
  filemanager = "open.handlers.filemanager",
  browser = "open.handlers.browser",
  notepad = "open.handlers.notepad",
  nvim_internal = "open.handlers.nvim_internal",
  default = "open.handlers.default",
  terminal = "open.handlers.terminal",
  image = "open.handlers.image",
}

-- ---------------------------------------------------------------------------
-- Public Lua API
-- ---------------------------------------------------------------------------

---Open a target programmatically.
---@param target string|nil  Handler key; nil → context-aware default.
---@param scope  string|nil  Scope token: "%", "cfile", "path=…", or literal.
---@return boolean|nil ok   true/false once a handler ran synchronously;
---                         nil when the opt-in picker deferred the choice
---                         (dispatch then happens later, inside its own
---                         on_select callback).
---@return string|nil err
function M.open(target, scope)
  local context = require("open.context")
  local registry = require("open.registry")

  local ok, err

  context.with_cache(function()
    local signals = context.gather()
    local cfg = require("open.config").get()

    if not target and cfg.picker and cfg.picker.enabled then
      local candidates = context.candidate_targets(signals)
      if #candidates > 1 then
        require("open.picker").select(candidates, scope, signals)
        return
      end
    end

    local t = target and target:lower() or context.default_target(signals)
    local ctx = context.resolve(scope, t, signals)

    if not ctx then
      require("lib.nvim.notify").create("[open]").warn("Nothing to open")
      ok, err = false, "Nothing to open"
      return
    end

    ok, err = registry.dispatch(t, ctx)
  end)

  return ok, err
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

  -- Load & register handler modules. A failure at any of the three stages
  -- below (require, shape check, register_all itself) is reported rather
  -- than swallowed (PRIN-20): setup() still does not abort over one broken
  -- handler module, matching how an unknown config value degrades (ERR-22),
  -- but the gap in the registry is no longer silent the way a wrong-typed
  -- config value used to be too loud.
  local notify = require("lib.nvim.notify").create("[open]")
  local registry = require("open.registry")
  for _, key in ipairs(cfg.handlers) do
    local mod_path = HANDLER_MODULES[key]
    if mod_path then
      local ok, mod = pcall(require, mod_path)
      if not ok then
        notify.error("Handler module '" .. key .. "' failed to load: " .. tostring(mod))
      elseif type(mod) ~= "table" or type(mod.register_all) ~= "function" then
        notify.error("Handler module '" .. key .. "' has no register_all(register_fn)")
      else
        local ok_reg, reg_err = pcall(mod.register_all, registry.register)
        if not ok_reg then
          notify.error(
            "Handler module '" .. key .. "' register_all() failed: " .. tostring(reg_err)
          )
        end
      end
    else
      notify.warn("Unknown handler module key: '" .. key .. "'")
    end
  end

  -- Register user-defined handlers from `custom_handlers`.
  for _, handler in ipairs(cfg.custom_handlers or {}) do
    registry.register(handler)
  end

  -- Auto-redirect MS Office documents (BufReadCmd), independent of handlers.
  require("open.office_open").setup(cfg.office_open)

  -- Register :Open command
  require("open.bindings.usrcmds").register(cfg)

  -- Register optional keymaps (none by default).
  require("open.bindings.keymaps").register(cfg)

  -- Report the declared external tools (docs/install.json) once, ever, on
  -- the first setup after installation. Both the require and the call are
  -- pcall'd (ERR-01): an older lib.nvim without lib.nvim.deps, or a failure
  -- inside show_once itself (an API-signature change, a malformed
  -- docs/install.json, a failure while drawing the popup), must not break
  -- setup() over an informational popup; `:Lib deps show open.nvim` stays
  -- available either way. Turn it off with
  -- `vim.g.lib_nvim_deps_disable_first_run` (or the per-plugin
  -- `vim.g.lib_nvim_deps_disabled_plugins`).
  local ok_deps, deps = pcall(require, "lib.nvim.deps")
  if ok_deps then pcall(deps.show_once, "open.nvim") end
end

return M
