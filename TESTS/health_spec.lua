-- TESTS/health_spec.lua — :checkhealth open.
--
-- health.lua stays otherwise untested (see TESTS/README.md: it is a
-- declarative reporter, one runtime probe per vim.health.* call, with no
-- computed value to assert on beyond "did the right level get called").
-- This spec exists for exactly one thing found in a coverage re-audit: the
-- report used to crash instead of finishing when its one hard dependency
-- was missing. `vim.health` is replaced with a recorder so the fix can be
-- asserted on the level it reports at, not on rendered text.
---@diagnostic disable: duplicate-set-field

return function(H)
  local eq, ok = H.eq, H.ok
  local health = require("open.health")

  --- Run `:checkhealth open` against a recorder.
  ---@return {start: string[], ok: string[], warn: string[], error: string[], info: string[], raised: string|nil}
  local function report()
    local rec = { start = {}, ok = {}, warn = {}, error = {}, info = {} }
    local real = vim.health
    vim.health = {
      start = function(name)
        rec.start[#rec.start + 1] = name
      end,
      ok = function(msg)
        rec.ok[#rec.ok + 1] = msg
      end,
      warn = function(msg)
        rec.warn[#rec.warn + 1] = msg
      end,
      error = function(msg)
        rec.error[#rec.error + 1] = msg
      end,
      info = function(msg)
        rec.info[#rec.info + 1] = msg
      end,
    }
    local called_ok, err = pcall(health.check)
    vim.health = real
    if not called_ok then rec.raised = tostring(err) end
    return rec
  end

  --- True when any recorded message at `level` contains `needle`.
  ---@param rec table
  ---@param level string
  ---@param needle string
  ---@return boolean
  local function said(rec, level, needle)
    for _, msg in ipairs(rec[level]) do
      if tostring(msg):find(needle, 1, true) then return true end
    end
    return false
  end

  -- The baseline run, composer present (the real lib.nvim sibling checkout
  -- this suite runs against) -- completes cleanly and opens its sections.
  do
    local rec = report()
    eq(rec.raised, nil, "check: runs to completion with the real dependency present")
    ok(said(rec, "start", "open: core"), "check: opens the core section")
    ok(said(rec, "ok", "usercmd.composer available"), "check: the composer is reported present")
  end

  -- Regression: composer missing used to crash the whole report right after
  -- check_lib_nvim() had already logged the one vim.health.error() line that
  -- explains why -- the unconditional call at the end of M.check() reached
  -- into the exact module it had just been told was absent. It is guarded
  -- now, like every other optional dependency this same check probes.
  do
    local name = "lib.nvim.bindings.usercmd.composer"
    local loaded, preload = package.loaded[name], package.preload[name]
    package.loaded[name] = nil
    package.preload[name] = function()
      error("lib.nvim not installed (test stub)")
    end

    local rec = report()

    package.loaded[name], package.preload[name] = loaded, preload

    ok(
      said(rec, "error", "usercmd.composer not found"),
      "check: a missing composer is reported as an error"
    )
    eq(
      rec.raised,
      nil,
      "check: ...and the report completes instead of raising on that same missing module"
    )
  end
end
