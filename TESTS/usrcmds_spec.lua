-- TESTS/usrcmds_spec.lua — command registration and argument routing.
--
-- The point of interest is that `:Open viewer` coexists with `:Open`'s flat
-- root route: composer's tree walk must consume the literal "viewer" token
-- rather than binding it as the root route's `target` argument.

return function(H)
  require("open_nvim").setup({})

  local function exists(name)
    return vim.fn.exists(":" .. name) == 2
  end

  H.ok(exists("Open"), ":Open registered")
  H.ok(exists("UrlView"), ":UrlView registered")
  H.ok(exists("MDLinksView"), ":MDLinksView registered")

  -- `:Open viewer` must reach viewer.run, not run_open ----------------------
  do
    local viewer = require("open_nvim.viewer")
    local orig = viewer.run
    local got
    viewer.run = function(opts) got = opts end

    vim.cmd("Open viewer")
    H.ok(got, ":Open viewer routes to viewer.run")
    H.eq(got.kind, "all", "kind defaults to all")
    H.falsy(got.scope, "no scope token means no scope argument")

    -- A bare kind, with no scope.
    got = nil
    vim.cmd("Open viewer urls")
    H.eq(got.kind, "urls", "first positional bound as kind when it names one")
    H.falsy(got.scope, "kind alone leaves scope unset")

    -- A bare scope, with no kind. This is the ambiguity an `enum` on the kind
    -- arg would have rejected outright.
    got = nil
    vim.cmd("Open viewer cwd")
    H.eq(got.kind, "all", "unrecognized first positional falls through to scope")
    H.eq(got.scope, "cwd", "scope bound from the first positional")

    -- Both.
    got = nil
    vim.cmd("Open viewer mdlinks cwd sort=file out=table --paths")
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
    H.eq(got.unique, false, "--dupes disables de-duplication")
    H.eq(got.recursive, false, "--flat disables recursion")
    H.eq(got.anchors, true, "--anchors includes in-document anchors")

    -- Order must not matter: flags and key=value pairs are parsed out of the
    -- token tail before positional binding.
    got = nil
    vim.cmd("Open viewer --paths out=csv urls cwd")
    H.eq(got.kind, "urls", "kind still binds when it follows flags")
    H.eq(got.scope, "cwd", "scope still binds when it follows flags")
    H.eq(got.out, "csv", "out= still binds when it precedes positionals")

    -- Wrapper commands pin the kind, so their single positional is the scope.
    got = nil
    vim.cmd("UrlView cwd sort=alpha")
    H.eq(got.kind, "urls", ":UrlView pins kind=urls")
    H.eq(got.scope, "cwd", ":UrlView binds its positional as scope, not kind")
    H.eq(got.sort, "alpha", ":UrlView binds the same sort key")

    got = nil
    vim.cmd("MDLinksView")
    H.eq(got.kind, "mdlinks", ":MDLinksView pins kind=mdlinks")
    H.falsy(got.scope, "bare wrapper leaves scope unset")

    -- A scope that happens to spell a kind must still be a scope here.
    got = nil
    vim.cmd("UrlView urls")
    H.eq(got.kind, "urls", ":UrlView kind stays pinned")
    H.eq(got.scope, "urls", "wrapper positional is never re-read as a kind")

    -- A range is only honored when one was actually typed.
    got = nil
    vim.cmd("UrlView")
    H.falsy(got.range, "no range given means range=false")

    got = nil
    H.scratch({ "a", "b", "c", "d" })
    vim.cmd("2,3UrlView")
    H.ok(got.range, "an explicit range sets range=true")
    H.eq(got.line1, 2, "range start forwarded")
    H.eq(got.line2, 3, "range end forwarded")

    viewer.run = orig
  end

  -- `:Open <handler>` must still work — the new literal route must not have
  -- shadowed the flat grammar.
  do
    local registry = require("open_nvim.registry")
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
    local registry = require("open_nvim.registry")
    for _, key in ipairs(registry.list_keys()) do
      if key == "viewer" then
        error("FAIL: a handler is registered under the reserved key 'viewer'")
      end
    end
  end
end
