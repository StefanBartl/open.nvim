-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil, duplicate-set-field
--
-- The stdlib and module fields replaced below are test doubles: each one is
-- swapped for the length of a single case and restored right after.
-- TESTS/usrcmds_spec.lua — command registration and argument routing.
--
-- The point of interest is that `:Open viewer` coexists with `:Open`'s flat
-- root route: composer's tree walk must consume the literal "viewer" token
-- rather than binding it as the root route's `target` argument.

return function(H)
  require("open").setup({})

  local function exists(name)
    return vim.fn.exists(":" .. name) == 2
  end

  H.ok(exists("Open"), ":Open registered")
  H.ok(exists("UrlView"), ":UrlView registered")
  H.ok(exists("MDLinksView"), ":MDLinksView registered")

  -- `:Open viewer` must reach viewer.run, not run_open ----------------------
  do
    local viewer = require("open.viewer")
    local orig = viewer.run
    -- Cleared before each case and refilled through the double below. The
    -- `assert` after every `vim.cmd` is what turns "the command never reached
    -- viewer.run" into a named failure instead of an "index a nil value" three
    -- lines further down -- and it is what lets the field reads resolve, since
    -- `got = nil` narrows the local to nil for everything after it.
    ---@type OpenNvim.Viewer.RunOpts|nil
    local got
    viewer.run = function(opts)
      got = opts
    end

    vim.cmd("Open viewer")
    H.ok(got, ":Open viewer routes to viewer.run")
    got = assert(got, ":Open viewer did not reach viewer.run")
    H.eq(got.kind, "all", "kind defaults to all")
    H.falsy(got.scope, "no scope token means no scope argument")

    -- A bare kind, with no scope.
    got = nil
    vim.cmd("Open viewer urls")
    got = assert(got, ":Open viewer urls did not reach viewer.run")
    H.eq(got.kind, "urls", "first positional bound as kind when it names one")
    H.falsy(got.scope, "kind alone leaves scope unset")

    -- A bare scope, with no kind. This is the ambiguity an `enum` on the kind
    -- arg would have rejected outright.
    got = nil
    vim.cmd("Open viewer cwd")
    got = assert(got, ":Open viewer cwd did not reach viewer.run")
    H.eq(got.kind, "all", "unrecognized first positional falls through to scope")
    H.eq(got.scope, "cwd", "scope bound from the first positional")

    -- Both.
    got = nil
    vim.cmd("Open viewer mdlinks cwd sort=file out=table --paths")
    got =
      assert(got, ":Open viewer mdlinks cwd sort=file out=table --paths did not reach viewer.run")
    H.eq(got.kind, "mdlinks", "kind bound")
    H.eq(got.scope, "cwd", "scope bound")
    H.eq(got.sort, "file", "sort= key bound")
    H.eq(got.out, "table", "out= key bound")
    H.eq(got.paths, true, "--paths flag bound")
    H.eq(got.unique, true, "unique defaults on")
    H.eq(got.recursive, true, "recursive defaults on")
    H.eq(got.anchors, false, "anchors default off")

    got = nil
    vim.cmd("Open viewer --dupes --flat --anchors")
    got = assert(got, ":Open viewer --dupes --flat --anchors did not reach viewer.run")
    H.eq(got.unique, false, "--dupes disables de-duplication")
    H.eq(got.recursive, false, "--flat disables recursion")
    H.eq(got.anchors, true, "--anchors includes in-document anchors")

    -- Order must not matter: flags and key=value pairs are parsed out of the
    -- token tail before positional binding.
    got = nil
    vim.cmd("Open viewer --paths out=csv urls cwd")
    got = assert(got, ":Open viewer --paths out=csv urls cwd did not reach viewer.run")
    H.eq(got.kind, "urls", "kind still binds when it follows flags")
    H.eq(got.scope, "cwd", "scope still binds when it follows flags")
    H.eq(got.out, "csv", "out= still binds when it precedes positionals")

    -- Wrapper commands pin the kind, so their single positional is the scope.
    got = nil
    vim.cmd("UrlView cwd sort=alpha")
    got = assert(got, ":UrlView cwd sort=alpha did not reach viewer.run")
    H.eq(got.kind, "urls", ":UrlView pins kind=urls")
    H.eq(got.scope, "cwd", ":UrlView binds its positional as scope, not kind")
    H.eq(got.sort, "alpha", ":UrlView binds the same sort key")

    got = nil
    vim.cmd("MDLinksView")
    got = assert(got, ":MDLinksView did not reach viewer.run")
    H.eq(got.kind, "mdlinks", ":MDLinksView pins kind=mdlinks")
    H.falsy(got.scope, "bare wrapper leaves scope unset")

    -- A scope that happens to spell a kind must still be a scope here.
    got = nil
    vim.cmd("UrlView urls")
    got = assert(got, ":UrlView urls did not reach viewer.run")
    H.eq(got.kind, "urls", ":UrlView kind stays pinned")
    H.eq(got.scope, "urls", "wrapper positional is never re-read as a kind")

    -- A range is only honored when one was actually typed.
    got = nil
    vim.cmd("UrlView")
    got = assert(got, ":UrlView did not reach viewer.run")
    H.falsy(got.range, "no range given means range=false")

    got = nil
    H.scratch({ "a", "b", "c", "d" })
    vim.cmd("2,3UrlView")
    got = assert(got, ":2,3UrlView did not reach viewer.run")
    H.ok(got.range, "an explicit range sets range=true")
    H.eq(got.line1, 2, "range start forwarded")
    H.eq(got.line2, 3, "range end forwarded")

    viewer.run = orig
  end

  -- `:Open <handler>` must still work — the new literal route must not have
  -- shadowed the flat grammar.
  do
    local registry = require("open.registry")
    local orig = registry.dispatch
    local seen
    registry.dispatch = function(handler, _ctx)
      seen = handler
      return true
    end

    vim.cmd("Open browser path=https://example.com")
    H.eq(seen, "browser", ":Open browser still routes to the handler")

    registry.dispatch = orig
  end

  -- No handler may be registered under "viewer", or `:Open viewer` would
  -- become unreachable as a handler target.
  do
    local registry = require("open.registry")
    for _, key in ipairs(registry.list_keys()) do
      if key == "viewer" then
        error("FAIL: a handler is registered under the reserved key 'viewer'")
      end
    end
  end
end
