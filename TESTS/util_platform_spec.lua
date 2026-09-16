-- TESTS/util_platform_spec.lua — open.util (process/URL/path primitives)
-- and open.platform (cached OS detection). Both are small, cross-cutting
-- pieces every handler relies on, and neither had a dedicated spec before.

return function(H)
  local util = require("open.util")
  local platform = require("open.platform")

  -- util.run_detached: guard against a malformed cmd -------------------------
  do
    local ok, err = util.run_detached(nil, "label")
    H.falsy(ok, "nil cmd is rejected")
    H.contains(err, "label", "the error names the caller-supplied label")

    local ok2, err2 = util.run_detached({}, "empty")
    H.falsy(ok2, "an empty argv is rejected")
    H.contains(err2, "empty", "the error names the label for an empty argv too")

    local ok3 = util.run_detached("not-a-table", "x")
    H.falsy(ok3, "a non-table cmd is rejected")
  end

  -- util.run_detached: delegates to lib.nvim.cross.run and reports failure --
  do
    local run = require("lib.nvim.cross.run")
    local orig = run.run_detached
    run.run_detached = function()
      return false, "boom"
    end

    local ok, err = util.run_detached({ "x" }, "mylabel")
    H.falsy(ok, "a delegate failure is propagated")
    H.contains(err, "mylabel", "the wrapped error names the label")
    H.contains(err, "boom", "the wrapped error keeps the underlying reason")

    run.run_detached = orig
  end

  -- util.url_encode -----------------------------------------------------------
  do
    H.eq(util.url_encode("hello world"), "hello+world", "space becomes +")
    H.eq(util.url_encode("a&b=c"), "a%26b%3Dc", "reserved characters are percent-encoded")
    H.eq(util.url_encode("safe-._~"), "safe-._~", "unreserved characters pass through untouched")
    H.eq(util.url_encode(123), "123", "a non-string is stringified first")
  end

  -- util.find_exec --------------------------------------------------------------
  do
    local orig_exe = vim.fn.executable
    vim.fn.executable = function(name)
      return name == "second" and 1 or 0
    end

    H.eq(
      util.find_exec({ "first", "second", "third" }),
      "second",
      "first executable candidate wins"
    )
    H.falsy(util.find_exec({ "first", "third" }), "nil when nothing on the list is executable")
    H.falsy(util.find_exec({}), "an empty candidate list yields nil")

    vim.fn.executable = orig_exe
  end

  -- util.cmd_escape_unquoted -----------------------------------------------------
  do
    H.eq(util.cmd_escape_unquoted("a&b"), "a^&b", "ampersand escaped")
    H.eq(util.cmd_escape_unquoted("a|b<c>d^e"), "a^|b^<c^>d^^e", "every special character escaped")
    H.eq(util.cmd_escape_unquoted("plain"), "plain", "no escaping when nothing special is present")
  end

  -- platform.get: cached, shaped, boolean fields ---------------------------------
  do
    local p1 = platform.get()
    local p2 = platform.get()
    H.eq(p1, p2, "platform.get() caches and returns the identical table on a second call")

    for _, field in ipairs({ "is_win", "is_mac", "is_wsl", "is_linux" }) do
      H.eq(type(p1[field]), "boolean", field .. " is a boolean")
    end

    -- Exactly one desktop-OS flag should describe this runner (WSL counts as
    -- both is_wsl and is_linux, which is documented, not a bug).
    local count = 0
    for _, field in ipairs({ "is_win", "is_mac", "is_linux" }) do
      if p1[field] then count = count + 1 end
    end
    H.eq(count, 1, "exactly one of is_win/is_mac/is_linux is true")
  end
end
