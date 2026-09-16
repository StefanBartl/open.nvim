-- Test code: when something here comes back nil this file must crash and
-- name it, not silently pass.
---@diagnostic disable: need-check-nil, duplicate-set-field
-- TESTS/keywords_spec.lua — open.keywords: the built-in scope-keyword table
-- and its resolver functions. features_spec.lua only exercises the override
-- path (a user function returning nil); this spec covers M.builtin()'s own
-- shape and the capture() memoization the dynamic resolvers share, without
-- ever spawning a real subprocess (vim.system is stubbed throughout).

return function(H)
  local keywords = require("open.keywords")
  local platform = require("open.platform").get()

  -- builtin(): static entries are expanded strings ----------------------------
  do
    local kw = keywords.builtin()
    H.eq(type(kw.zshrc), "string", "zshrc is a plain expanded path")
    H.contains(kw.zshrc:gsub("\\", "/"), ".zshrc", "zshrc points at the right filename")
    H.eq(type(kw.vimrc), "string", "vimrc is a plain expanded path")
    H.eq(type(kw.gitconfig), "string", "gitconfig is a plain expanded path")
  end

  -- builtin(): dynamic entries are resolver functions -------------------------
  do
    local kw = keywords.builtin()
    H.eq(type(kw.pwsh_profile), "function", "pwsh_profile is a lazily-called resolver")
    H.eq(type(kw.nvim_init), "function", "nvim_init is a lazily-called resolver")
    H.eq(type(kw.hosts), "function", "hosts is a lazily-called resolver")
  end

  -- builtin(): platform-gated entries only appear on their platform ----------
  do
    local kw = keywords.builtin()
    if platform.is_win then
      H.eq(type(kw.wslconfig), "string", "wslconfig appears on native Windows")
    else
      H.falsy(kw.wslconfig, "wslconfig absent off Windows")
    end
    if platform.is_wsl then
      H.eq(kw.wsl_conf, "/etc/wsl.conf", "wsl_conf appears under WSL")
    else
      H.falsy(kw.wsl_conf, "wsl_conf absent outside WSL")
    end
  end

  -- pwsh_profile: no subprocess is spawned when neither exe is on PATH -------
  do
    local orig_exe = vim.fn.executable
    vim.fn.executable = function()
      return 0
    end
    local orig_system = vim.system
    local spawned = false
    vim.system = function(...)
      spawned = true
      return orig_system(...)
    end

    H.falsy(keywords.builtin().pwsh_profile(), "no pwsh/powershell on PATH resolves to nil")
    H.falsy(spawned, "the resolver returns before ever touching vim.system")

    vim.fn.executable = orig_exe
    vim.system = orig_system
  end

  -- resolve_gitmessage: capture() memoizes a successful lookup ----------------
  do
    local orig_system = vim.system
    local calls = 0
    vim.system = function()
      calls = calls + 1
      return {
        wait = function()
          return { code = 0, stdout = "tmpl-path\n" }
        end,
      }
    end

    local kw = keywords.builtin()
    local first = kw.gitmessage()
    local second = kw.gitmessage()

    H.eq(first, "tmpl-path", "capture() trims the subprocess stdout")
    H.eq(first, second, "the memoized result is stable across repeated calls")
    H.eq(calls, 1, "the underlying command runs exactly once, not once per call")

    vim.system = orig_system
  end

  -- resolve_gitignore_global: a failed lookup is memoized too, then falls
  -- back to the first existing candidate path instead of erroring ------------
  do
    local orig_system = vim.system
    local calls = 0
    vim.system = function()
      calls = calls + 1
      return {
        wait = function()
          return { code = 1, stdout = "" }
        end,
      }
    end

    local kw = keywords.builtin()
    local first = kw.gitignore_global()
    local second = kw.gitignore_global()

    H.eq(type(first), "string", "a failed git-config lookup still falls back to a plain path")
    H.eq(first, second, "the memoized failure is stable across repeated calls")
    H.eq(calls, 1, "a failed lookup is cached too, not retried on every call")

    vim.system = orig_system
  end

  -- setup() wires builtin() into config.get().keywords ------------------------
  do
    require("open").setup({})
    local cfg_kw = require("open.config").get().keywords
    H.eq(type(cfg_kw.zshrc), "string", "config.setup() pulls in the built-in keyword table")
  end
end
