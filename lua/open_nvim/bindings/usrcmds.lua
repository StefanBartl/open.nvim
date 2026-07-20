---@module 'open_nvim.bindings.usrcmds'
---@brief Registers the :Open (and :UrlView) user commands via lib.nvim.usercmd.composer.
---@description
--- `:Open [target] [scope]` is a flat, no-subcommand grammar, so it uses
--- composer's `path = {}` root-route trick rather than a subcommand tree.
--- Target (1st arg) and scope (2nd arg) completion is meaningfully smarter
--- than the built-in STRING/PATH types (dynamic handler-registry lookup,
--- "path=" pseudo-flag file completion, named-keyword prefix matching), so
--- both get their own registered composer types.
---
--- `:Open urlview …` coexists with that root route because `tree.walk`
--- consumes literal children greedily: the token "urlview" matches the
--- literal child and never reaches the root route's OPEN_TARGET arg. This is
--- only safe as long as no handler is registered under the key "urlview" —
--- such a handler would become unreachable via `:Open urlview`.
---
--- `:UrlView` is the shallow standalone wrapper over the same route body,
--- following replacer.nvim's `:Replace` / `:Replacer` precedent.

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

-- ---------------------------------------------------------------------------
-- urlview
-- ---------------------------------------------------------------------------

-- Scope token for `:Open urlview` / `:UrlView`: the literal scope keywords
-- plus ordinary file/directory completion.
composer.register_type("URLVIEW_SCOPE", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    local out = {}
    for _, s in ipairs({ "%", "cwd", "buffers" }) do
      if s:sub(1, #arg_lead) == arg_lead then
        out[#out + 1] = s
      end
    end
    for _, f in ipairs(vim.fn.getcompletion(arg_lead, "file")) do
      out[#out + 1] = f
    end
    return out
  end,
})

--- Translate a composer ctx into `urlview.run` options.
---@param ctx Lib.UserCmd.Composer.Ctx
local function run_urlview(ctx)
  local flags = ctx.flags or {}
  local kv = ctx.kv or {}

  require("open_nvim.urlview").run({
    scope = ctx.args.scope,
    sort = kv.sort,
    out = kv.out,
    match = kv.match,
    paths = flags.paths == true,
    -- `--all` keeps duplicate targets; the default de-duplicates, since the
    -- same URL repeated across a repo is noise in a list you are picking from.
    unique = flags.all ~= true,
    recursive = flags.flat ~= true,
    -- A range only counts when one was actually typed (`ctx.range.range > 0`);
    -- nvim reports line1/line2 as the cursor line otherwise, which would
    -- silently shrink a plain `:UrlView` to a single line.
    range = (ctx.range and ctx.range.range or 0) > 0,
    line1 = ctx.range and ctx.range.line1,
    line2 = ctx.range and ctx.range.line2,
  })
end

--- The shared route body for `:Open urlview` and the standalone `:UrlView`.
---@param path string[]
---@return Lib.UserCmd.Composer.Route
local function urlview_route(path)
  return {
    path = path,
    desc = "List links in a scope, then open / export them",
    range = true,
    args = {
      { name = "scope", type = "URLVIEW_SCOPE", optional = true },
    },
    kv = {
      { key = "sort", enum = { "none", "file", "kind", "alpha" } },
      { key = "out", values = { "picker", "table", "clipboard", "mdlinks", "csv", "echo", "file:" } },
      { key = "match" },
    },
    flags = {
      { name = "paths", bool = true },
      { name = "all", bool = true },
      { name = "flat", bool = true },
    },
    run = run_urlview,
  }
end

-- ---------------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------------

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

      urlview_route({ "urlview" }),
    },
  })

  -- Standalone wrapper. Same route body, registered as its own verb so it
  -- keeps its own completion and usage listing.
  local uv_cmd = cfg.urlview and cfg.urlview.command
  if uv_cmd and uv_cmd ~= "" then
    composer.verb(uv_cmd, {
      desc = ":UrlView — list links in a scope, then open / export them",
      range = true,
      routes = { urlview_route({}) },
    })
  end
end

return M
