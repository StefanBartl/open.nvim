-- TESTS/usrcmds_spec.lua — command registration and argument routing.
--
-- The point of interest is that `:Open urlview` coexists with `:Open`'s flat
-- root route: composer's tree walk must consume the literal "urlview" token
-- rather than binding it as the root route's `target` argument.

return function(H)
  require("open_nvim").setup({})

  local function exists(name)
    return vim.fn.exists(":" .. name) == 2
  end

  H.ok(exists("Open"), ":Open registered")
  H.ok(exists("UrlView"), ":UrlView registered")

  -- `:Open urlview` must reach urlview.run, not run_open --------------------
  do
    local urlview = require("open_nvim.urlview")
    local orig = urlview.run
    local got
    urlview.run = function(opts) got = opts end

    vim.cmd("Open urlview")
    H.ok(got, ":Open urlview routes to urlview.run")
    H.falsy(got.scope, "no scope token means no scope argument")

    got = nil
    vim.cmd("Open urlview cwd sort=file out=table --paths")
    H.eq(got.scope, "cwd", "scope positional bound")
    H.eq(got.sort, "file", "sort= key bound")
    H.eq(got.out, "table", "out= key bound")
    H.eq(got.paths, true, "--paths flag bound")
    H.eq(got.unique, true, "unique defaults on")
    H.eq(got.recursive, true, "recursive defaults on")

    got = nil
    vim.cmd("Open urlview --all --flat")
    H.eq(got.unique, false, "--all disables de-duplication")
    H.eq(got.recursive, false, "--flat disables recursion")

    -- Order must not matter: flags and key=value pairs are parsed out of the
    -- token tail before positional binding.
    got = nil
    vim.cmd("Open urlview --paths out=csv cwd")
    H.eq(got.scope, "cwd", "positional still binds when it follows flags")
    H.eq(got.out, "csv", "out= still binds when it precedes the positional")

    -- The standalone wrapper shares the same route body.
    got = nil
    vim.cmd("UrlView cwd sort=alpha")
    H.eq(got.scope, "cwd", ":UrlView binds the same scope positional")
    H.eq(got.sort, "alpha", ":UrlView binds the same sort key")

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

    urlview.run = orig
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

  -- No handler may be registered under "urlview", or `:Open urlview` would
  -- become unreachable as a handler target.
  do
    local registry = require("open_nvim.registry")
    for _, key in ipairs(registry.list_keys()) do
      if key == "urlview" then
        error("FAIL: a handler is registered under the reserved key 'urlview'")
      end
    end
  end
end
