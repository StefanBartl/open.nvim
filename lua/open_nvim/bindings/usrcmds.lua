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
--- `:Open viewer …` coexists with that root route because `tree.walk`
--- consumes literal children greedily: the token "viewer" matches the
--- literal child and never reaches the root route's OPEN_TARGET arg. This is
--- only safe as long as no handler is registered under the key "viewer" —
--- such a handler would become unreachable via `:Open viewer`.
---
--- `:UrlView` / `:MDLinksView` are shallow standalone wrappers that pin the
--- kind filter, following replacer.nvim's `:Replace` / `:Replacer` precedent.

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
-- viewer
-- ---------------------------------------------------------------------------

local SCOPE_TOKENS = { "%", "cwd", "buffers" }

---@param arg_lead string
---@return string[]
local function complete_scope(arg_lead)
  local out = {}
  for _, s in ipairs(SCOPE_TOKENS) do
    if s:sub(1, #arg_lead) == arg_lead then
      out[#out + 1] = s
    end
  end
  for _, f in ipairs(vim.fn.getcompletion(arg_lead, "file")) do
    out[#out + 1] = f
  end
  return out
end

-- Scope token for the wrapper commands: the literal scope keywords plus
-- ordinary file/directory completion.
composer.register_type("VIEWER_SCOPE", {
  validate = function(raw) return true, raw, nil end,
  complete = complete_scope,
})

-- First positional of `:Open viewer`, which may be either a kind or a scope.
-- Validation stays soft and the handler disambiguates (see run_viewer): an
-- `enum` here would reject `:Open viewer cwd` outright rather than reading it
-- as "all kinds, cwd scope", which is the more useful interpretation.
composer.register_type("VIEWER_KIND", {
  validate = function(raw) return true, raw, nil end,
  complete = function(arg_lead)
    local out = {}
    local ok, viewer = pcall(require, "open_nvim.viewer")
    if ok then
      for _, k in ipairs(viewer.kinds()) do
        if k:sub(1, #arg_lead) == arg_lead then
          out[#out + 1] = k
        end
      end
    end
    for _, s in ipairs(complete_scope(arg_lead)) do
      out[#out + 1] = s
    end
    return out
  end,
})

--- Translate a composer ctx into `viewer.run` options.
---
--- `fixed_kind` is set by the wrapper commands (`:UrlView` → "urls"), in which
--- case the first positional is unambiguously the scope. For `:Open viewer`
--- the first positional may be either, so a value that names a known kind is
--- read as one and everything else falls through to the scope slot.
---@param ctx Lib.UserCmd.Composer.Ctx
---@param fixed_kind string|nil
local function run_viewer(ctx, fixed_kind)
  local flags = ctx.flags or {}
  local kv = ctx.kv or {}
  local viewer = require("open_nvim.viewer")

  local kind, scope
  if fixed_kind then
    kind, scope = fixed_kind, ctx.args.kind
  else
    local first, second = ctx.args.kind, ctx.args.scope
    local known = {}
    for _, k in ipairs(viewer.kinds()) do
      known[k] = true
    end
    if first and known[first] then
      kind, scope = first, second
    else
      kind, scope = "all", first
      if second then
        -- Two positionals where the first is not a kind: the user most likely
        -- mistyped it, and silently ignoring the extra token would hide that.
        require("lib.nvim.notify")
          .create("[open_nvim.viewer]")
          .warn(("ignoring unrecognized kind '%s'"):format(tostring(first)))
        scope = second
      end
    end
  end

  viewer.run({
    kind = kind,
    scope = scope,
    sort = kv.sort,
    out = kv.out,
    match = kv.match,
    paths = flags.paths == true,
    anchors = flags.anchors == true,
    -- `--dupes` keeps duplicate targets; the default de-duplicates, since the
    -- same URL repeated across a repo is noise in a list you are picking from.
    unique = flags.dupes ~= true,
    recursive = flags.flat ~= true,
    -- A range only counts when one was actually typed (`ctx.range.range > 0`);
    -- nvim reports line1/line2 as the cursor line otherwise, which would
    -- silently shrink a plain `:UrlView` to a single line.
    range = (ctx.range and ctx.range.range or 0) > 0,
    line1 = ctx.range and ctx.range.line1,
    line2 = ctx.range and ctx.range.line2,
  })
end

---@return Lib.UserCmd.Composer.KvSpec[]
local function viewer_kv()
  return {
    { key = "sort", enum = { "none", "file", "kind", "alpha" } },
    { key = "out", values = { "picker", "table", "clipboard", "mdlinks", "csv", "echo", "file:" } },
    { key = "match" },
  }
end

---@return Lib.UserCmd.Composer.FlagSpec[]
local function viewer_flags()
  return {
    { name = "paths", bool = true },
    { name = "anchors", bool = true },
    { name = "dupes", bool = true },
    { name = "flat", bool = true },
  }
end

--- Route body for `:Open viewer [kind] [scope]`.
---@param path string[]
---@return Lib.UserCmd.Composer.Route
local function viewer_route(path)
  return {
    path = path,
    desc = "List links in a scope, then open / export them",
    range = true,
    args = {
      { name = "kind", type = "VIEWER_KIND", optional = true },
      { name = "scope", type = "VIEWER_SCOPE", optional = true },
    },
    kv = viewer_kv(),
    flags = viewer_flags(),
    run = function(ctx) run_viewer(ctx, nil) end,
  }
end

--- Route body for a fixed-kind wrapper command (`:UrlView [scope]`).
---@param kind string
---@return Lib.UserCmd.Composer.Route
local function viewer_fixed_route(kind)
  return {
    path = {},
    desc = ("List %s in a scope, then open / export them"):format(kind),
    range = true,
    args = {
      -- Named `kind` so run_viewer can read the single positional from one
      -- place regardless of which route shape it came from.
      { name = "kind", type = "VIEWER_SCOPE", optional = true },
    },
    kv = viewer_kv(),
    flags = viewer_flags(),
    run = function(ctx) run_viewer(ctx, kind) end,
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

      viewer_route({ "viewer" }),
    },
  })

  -- Standalone wrappers, one per filter. Each is its own verb rather than a
  -- `:cmd` alias so it keeps its own completion and usage listing — the same
  -- precedent as replacer.nvim's :Replace / :Replacer.
  local commands = (cfg.viewer and cfg.viewer.commands) or {}
  for _, spec in ipairs({
    { kind = "urls", name = commands.urls },
    { kind = "mdlinks", name = commands.mdlinks },
    { kind = "all", name = commands.all },
  }) do
    if type(spec.name) == "string" and spec.name ~= "" then
      composer.verb(spec.name, {
        desc = (":%s — list %s in a scope, then open / export them"):format(spec.name, spec.kind),
        range = true,
        routes = { viewer_fixed_route(spec.kind) },
      })
    end
  end
end

return M
