---@module 'open.util'
---@brief Shared low-level utilities for open.nvim.
---@description
--- Provides:
---   run_detached        — spawn a detached process (vim.system or jobstart fallback)
---   url_encode          — percent-encode a string for URL usage
---   find_exec           — return the first executable found from a candidate list
---   cmd_escape_unquoted — shield a cmd.exe argument from its unquoted-context
---                         special characters (see function doc)

local M = {}

-- ---------------------------------------------------------------------------
-- Process spawning
-- ---------------------------------------------------------------------------

---Spawn a detached process. The parent Neovim session does not wait for it.
---Low-level: reports failure via the second return value instead of
---notifying directly — callers decide whether/how to surface it to the user.
---@param cmd   string[]  Argument vector; first element is the executable.
---@param label string    Human-readable name used in error messages.
---@return boolean success
---@return string|nil err
function M.run_detached(cmd, label)
  if type(cmd) ~= "table" or #cmd == 0 then
    return false, "run_detached: invalid cmd for '" .. label .. "'"
  end

  -- Delegates the Windows/WSL-jobstart vs vim.system(detach) vs
  -- Neovim<0.10-jobstart fallback chain to lib.nvim.cross.run.run_detached
  -- (this module's own version was upstreamed into it).
  local ok, err = require("lib.nvim.cross.run").run_detached(cmd)
  if not ok then return false, "Failed to launch '" .. label .. "': " .. tostring(err) end
  return true
end

-- ---------------------------------------------------------------------------
-- URL encoding
-- ---------------------------------------------------------------------------

---Percent-encode a string so it is safe for use in a URL query.
---@param s string  Raw text
---@return string   URL-encoded text
function M.url_encode(s)
  s = tostring(s)
  s = s:gsub("([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  local encoded = s:gsub(" ", "+")
  return encoded
end

-- ---------------------------------------------------------------------------
-- Executable resolution
-- ---------------------------------------------------------------------------

---Return the first executable name from the candidate list, or nil.
---@param candidates string[]
---@return string|nil
function M.find_exec(candidates)
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then return name end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- cmd.exe argument safety
-- ---------------------------------------------------------------------------

--- cmd.exe variables that are not in the environment block.
local CMD_DYNAMIC_VARS = {
  CD = true,
  DATE = true,
  TIME = true,
  RANDOM = true,
  ERRORLEVEL = true,
  CMDEXTVERSION = true,
  CMDCMDLINE = true,
  HIGHESTNUMANODENUMBER = true,
}

---@param name string  # text between two `%`, possibly `VAR:~0,5` / `VAR:a=b`
---@return boolean
local function is_cmd_variable(name)
  name = name:match("^([^:]*)")
  if name == "" then return false end
  return CMD_DYNAMIC_VARS[name:upper()] == true or vim.uv.os_getenv(name) ~= nil
end

---`%` cannot be caret-escaped in a cmd.exe command line, so a `%NAME%` would
---be expanded from the environment. Percent-encode every `%` that is not the
---start of a `%XX` escape; a `%XX` is kept too only when the text up to the
---next `%` is not a variable (`%CD%`, `%DATE%`, `%ABCD%` start with hex
---digits, so they would otherwise survive as `%CD%25`).
---@param s string
---@return string
local function neutralise_percent(s)
  local out, i, n = {}, 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c ~= "%" then
      out[#out + 1] = c
      i = i + 1
    else
      local hex = s:match("^%x%x", i + 1)
      if not hex then
        out[#out + 1] = "%25"
        i = i + 1
      else
        local j = s:find("%", i + 1, true)
        local is_var = j ~= nil and is_cmd_variable(s:sub(i + 1, j - 1))
        out[#out + 1] = (is_var and "%25" or "%") .. hex
        i = i + 3
      end
    end
  end
  return table.concat(out)
end

--- Escape cmd.exe's unquoted-context special characters (`& | < > ^`) with a
--- caret so an argument (typically a URL) survives `cmd.exe /C start ...`.
--- Needed whenever a `cmd.exe /C start` argv is launched via jobstart()/
--- vim.system(): those build the Win32 command line through libuv's own argv
--- quoting, which only wraps an argument in quotes when it contains
--- whitespace. A URL with no spaces but an unescaped `&` (any link with 2+
--- query params, e.g. "...?id=x&y=z") therefore reaches cmd.exe unquoted, and
--- cmd.exe's own tokenizer treats the bare `&` as a command separator —
--- silently truncating the URL at that point (no error, just the wrong page).
---@param s string
---@return string
function M.cmd_escape_unquoted(s)
  -- A `"` would flip cmd.exe into quoted mode, where the carets below are
  -- taken literally and `&` runs a command; it is a plain `%22` in a URL.
  s = s:gsub('"', "%%22")
  s = neutralise_percent(s)
  return (s:gsub("([&|<>^])", "^%1"))
end

--- Install locations of the named browsers below a Program Files / local
--- app-data root, keyed by the token `cmd.exe /C start` knows them by.
local WIN_BROWSER_PATHS = {
  chrome = { "Google\\Chrome\\Application\\chrome.exe" },
  firefox = { "Mozilla Firefox\\firefox.exe" },
  msedge = { "Microsoft\\Edge\\Application\\msedge.exe" },
  brave = { "BraveSoftware\\Brave-Browser\\Application\\brave.exe" },
  opera = { "Programs\\Opera\\opera.exe", "Opera\\opera.exe" },
}

--- Resolve a named browser to its executable on Windows (PATH first, then the
--- default install locations), so it can be launched with the URL as a plain
--- argv element -- no cmd.exe in between that would re-tokenize it or expand
--- `%VAR%` in it.
---@param token string  "chrome"|"firefox"|"msedge"|"brave"|"opera"
---@return string|nil exe  # absolute path, or nil when not found
function M.find_windows_browser(token)
  -- only a real .exe: a .cmd/.bat shim cannot be spawned without a shell
  local on_path = vim.fn.exepath(token)
  if on_path:lower():sub(-4) == ".exe" then return on_path end

  local rels = WIN_BROWSER_PATHS[token]
  if not rels then return nil end
  for _, var in ipairs({ "ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA" }) do
    local root = vim.uv.os_getenv(var)
    if root and root ~= "" then
      for _, rel in ipairs(rels) do
        local candidate = root .. "\\" .. rel
        if vim.fn.executable(candidate) == 1 then return candidate end
      end
    end
  end
  return nil
end

return M
