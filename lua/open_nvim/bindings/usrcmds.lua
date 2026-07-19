---@module 'open_nvim.bindings.usrcmds'
---@brief Registers the :Open user command via lib.nvim.usercmd.composer.
---@description
--- `:Open [target] [scope]` is a flat, no-subcommand grammar, so it uses
--- composer's `path = {}` root-route trick rather than a subcommand tree.
--- Target (1st arg) and scope (2nd arg) completion is meaningfully smarter
--- than the built-in STRING/PATH types (dynamic handler-registry lookup,
--- "path=" pseudo-flag file completion, named-keyword prefix matching), so
--- both get their own registered composer types.

local composer = require("lib.nvim.usercmd.composer")

local M = {}

---Resolve and dispatch an :Open invocation.
---@param target_raw string|nil
---@param scope       string|nil
local function run_open(target_raw, scope)
  local context  = require("open_nvim.context")
  local registry = require("open_nvim.registry")
  local signals  = context.gather()

  local target = target_raw and target_raw:lower() or context.default_target(signals)
  local ctx    = context.resolve(scope, target, signals)

  if not ctx then
    require("lib.nvim.notify").create("[open_nvim]").warn("Nothing to open")
    return
  end

  registry.dispatch(target, ctx)
end

-- 1st positional: handler key. Validation stays soft (registry.dispatch
-- reports unknown targets itself); completion lists live registry keys.
composer.register_type("OPEN_TARGET", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    local ok_r, reg = pcall(require, "open_nvim.registry")
    if not ok_r then return {} end
    local names, out = reg.list_keys(), {}
    for i = 1, #names do
      if names[i]:sub(1, #arg_lead) == arg_lead then
        out[#out + 1] = names[i]
      end
    end
    return out
  end,
})

-- 2nd positional: scope token or file path. "%"/"cfile"/"path=" literals,
-- named scope keywords, and general file completion — "path=<lead>" gets
-- file completion on the part after the prefix, re-prefixed on return.
composer.register_type("OPEN_SCOPE", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
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

---Register the :Open [target] [scope] user command for the given config.
---@param cfg OpenNvim.Config
function M.register(cfg)
  composer.verb(cfg.command, {
    desc = ":Open — open path/URL with the specified handler",

    -- Bare `:Open` (zero args) never reaches the routes table below.
    default = function() run_open(nil, nil) end,

    routes = {
      -- `path = {}` is the root route: it matches with no literal
      -- subcommand, reproducing the flat `:Open [target] [scope]` grammar.
      { path = {},
        args = {
          { name = "target", type = "OPEN_TARGET", optional = true },
          { name = "scope",  type = "OPEN_SCOPE",   optional = true },
        },
        desc = "Open path/URL with the specified handler",
        run  = function(ctx) run_open(ctx.args.target, ctx.args.scope) end },
    },
  })
end

return M
