---@module 'open_nvim'
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
---   (omitted)     → target-aware heuristic (see open_nvim.context)
---@see open_nvim.context
---@see open_nvim.registry

local M = {}

-- Map of handler-module keys (used in cfg.handlers) to require paths.
local HANDLER_MODULES = {
  filemanager   = "open_nvim.handlers.filemanager",
  browser       = "open_nvim.handlers.browser",
  notepad       = "open_nvim.handlers.notepad",
  nvim_internal = "open_nvim.handlers.nvim_internal",
  default       = "open_nvim.handlers.default",
}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

---Dispatch to a registered handler.
---@param target string
---@param ctx    OpenNvim.Context
local function dispatch(target, ctx)
  local ok_reg, registry = pcall(require, "open_nvim.registry")
  if not ok_reg then
    require("lib.nvim.notify").create("[open_nvim]").error("Registry not available")
    return
  end

  local handler = registry.get(target)
  if not handler then
    require("lib.nvim.notify").create("[open_nvim]").error(
      string.format("Unknown target: '%s'  (available: %s)",
        target, table.concat(registry.list_keys(), ", "))
    )
    return
  end

  local ok, err = pcall(handler.run, ctx)
  if not ok then
    require("lib.nvim.notify").create("[open_nvim]").error(
      string.format("Handler '%s' failed: %s", target, tostring(err))
    )
  end
end

---Choose a handler key when the user gives no explicit target.
---@param signals OpenNvim.Signals
---@return string
local function default_target(signals)
  local cfg = require("open_nvim.config").get()

  if signals.tree_path then
    return cfg.default_filemanager
  end

  local probe = signals.cfile or signals.cword or signals.buffer_path or ""
  if probe:match("^https?://") or probe:match("^ftp://") or probe:match("^www%.") then
    return cfg.default_browser
  end

  return cfg.default_filemanager
end

-- ---------------------------------------------------------------------------
-- Public Lua API
-- ---------------------------------------------------------------------------

---Open a target programmatically.
---@param target string|nil  Handler key; nil → context-aware default.
---@param scope  string|nil  Scope token: "%", "cfile", "path=…", or literal.
function M.open(target, scope)
  local context = require("open_nvim.context")
  local signals = context.gather()

  local t = target and target:lower() or default_target(signals)
  local ctx = context.resolve(scope, t, signals)

  if not ctx then
    require("lib.nvim.notify").create("[open_nvim]").warn("Nothing to open")
    return
  end

  dispatch(t, ctx)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------

---Configure open.nvim and register the :Open user command.
---@param opts OpenNvim.Config|nil
function M.setup(opts)
  local cfg_mod = require("open_nvim.config")
  cfg_mod.setup(opts)
  local cfg = cfg_mod.get()

  -- Load & register handler modules
  local registry = require("open_nvim.registry")
  for _, key in ipairs(cfg.handlers) do
    local mod_path = HANDLER_MODULES[key]
    if mod_path then
      local ok, mod = pcall(require, mod_path)
      if ok and type(mod) == "table" and type(mod.register_all) == "function" then
        pcall(mod.register_all, registry.register)
      end
    else
      require("lib.nvim.notify").create("[open_nvim]").warn(
        "Unknown handler module key: '" .. key .. "'"
      )
    end
  end

  -- Register :Open command
  vim.api.nvim_create_user_command(cfg.command, function(opts_cmd)
    local context = require("open_nvim.context")
    local signals = context.gather()

    local target = (opts_cmd.fargs and opts_cmd.fargs[1])
      or default_target(signals)
    target = target:lower()

    local scope = opts_cmd.fargs and opts_cmd.fargs[2]
    local ctx   = context.resolve(scope, target, signals)

    if not ctx then
      require("lib.nvim.notify").create("[open_nvim]").warn("Nothing to open")
      return
    end

    dispatch(target, ctx)
  end, {
    nargs = "*",
    desc  = ":Open — open path/URL with the specified handler",

    complete = function(arg_lead, cmd_line, cursor_pos)
      local before = cmd_line:sub(1, cursor_pos)
      local tokens = {}
      for tok in before:gmatch("%S+") do tokens[#tokens + 1] = tok end

      local starting_new = before:match("%s$") ~= nil
      local arg_index    = #tokens - 1 + (starting_new and 1 or 0)

      -- 1st arg: handler key
      if arg_index <= 1 then
        local ok_r, reg = pcall(require, "open_nvim.registry")
        if not ok_r then return {} end
        local names, out = reg.list_keys(), {}
        for i = 1, #names do
          if names[i]:sub(1, #arg_lead) == arg_lead then
            out[#out + 1] = names[i]
          end
        end
        return out
      end

      -- 2nd arg: scope token or file path
      if arg_lead:sub(1, 5) == "path=" then
        local rest = arg_lead:sub(6)
        local candidates = {}
        for _, f in ipairs(vim.fn.getcompletion(rest, "file")) do
          candidates[#candidates + 1] = "path=" .. f
        end
        return candidates
      end

      local out    = {}
      local scopes = { "%", "cfile", "path=" }
      for i = 1, #scopes do
        if scopes[i]:sub(1, #arg_lead) == arg_lead then
          out[#out + 1] = scopes[i]
        end
      end

      -- Named scope keywords
      local ok_cfg, kw_cfg = pcall(require, "open_nvim.config")
      if ok_cfg then
        local kw_names = {}
        for name in pairs(kw_cfg.get().keywords or {}) do
          if name:sub(1, #arg_lead) == arg_lead then
            kw_names[#kw_names + 1] = name
          end
        end
        table.sort(kw_names)
        for _, n in ipairs(kw_names) do
          out[#out + 1] = n
        end
      end

      for _, f in ipairs(vim.fn.getcompletion(arg_lead, "file")) do
        out[#out + 1] = f
      end
      return out
    end,
  })
end

return M
