---@module 'open.handlers.browser'
---@brief Handlers that open a URL or text in various browsers.
---@description
--- Registered handlers: browser, chrome, chromium, firefox, edge, safari.
--- Non-URL text is treated as a Google search query automatically.
--- Local file paths are opened with the file:// scheme.

local notify   = require("lib.nvim.notify").create("[open.browser]")
local platform = require("open.platform")
local util     = require("open.util")

local M = {}

local SEARCH_BASE = "https://www.google.com/search?q="

---Normalise context text to a URL.
---@param ctx OpenNvim.Context
---@return string url
local function to_url(ctx)
  local text = ctx.text

  if ctx.is_url then
    return text:match("^www%.") and ("https://" .. text) or text
  end

  if ctx.is_path then
    return "file://" .. vim.fn.expand(text)
  end

  return SEARCH_BASE .. util.url_encode(text)
end

---@param url  string
---@param plat OpenNvim.Platform
---@return string[]
local function default_browser_cmd(url, plat)
  if plat.is_win then
    -- explorer.exe hands the URL straight to the registered protocol handler,
    -- with no cmd.exe re-tokenizing in between — see util.cmd_escape_unquoted
    -- for why `cmd.exe /C start` silently truncates URLs containing `&`.
    return { "explorer.exe", url }
  elseif plat.is_wsl then
    if vim.fn.executable("wslview") == 1 then return { "wslview", url } end
    if vim.fn.executable("explorer.exe") == 1 then return { "explorer.exe", url } end
    return { "cmd.exe", "/C", "start", '""', util.cmd_escape_unquoted(url) }
  elseif plat.is_mac then
    return { "open", url }
  else
    return { "xdg-open", url }
  end
end

---Build the command vector for a specific browser.
---@param url              string
---@param plat             OpenNvim.Platform
---@param linux_candidates string[]
---@param mac_app          string
---@param win_token        string
---@return string[]|nil, string|nil
local function named_browser_cmd(url, plat, linux_candidates, mac_app, win_token)
  if plat.is_win then
    -- Selecting a SPECIFIC (non-default) browser requires cmd.exe's `start
    -- <token>` resolution — explorer.exe alone can't target a named app — so
    -- the URL must be shielded from cmd.exe's own tokenizer instead; see
    -- util.cmd_escape_unquoted.
    return { "cmd.exe", "/C", "start", win_token, util.cmd_escape_unquoted(url) }, nil
  elseif plat.is_wsl then
    local exec = util.find_exec(linux_candidates)
    if exec then return { exec, url }, nil end
    return { "cmd.exe", "/C", "start", win_token, util.cmd_escape_unquoted(url) }, nil
  elseif plat.is_mac then
    return { "open", "-a", mac_app, url }, nil
  else
    local exec = util.find_exec(linux_candidates)
    if not exec then
      return nil, "None of the candidates found on PATH: "
        .. table.concat(linux_candidates, ", ")
    end
    return { exec, url }, nil
  end
end

---@param key string  @param desc string
---@param linux_candidates string[]  @param mac_app string  @param win_token string
---@return OpenNvim.Handler
local function make_named_handler(key, desc, linux_candidates, mac_app, win_token)
  return {
    key  = key,
    desc = desc,
    run  = function(ctx)
      local url  = to_url(ctx)
      local plat = platform.get()
      local cmd, err = named_browser_cmd(url, plat, linux_candidates, mac_app, win_token)
      if not cmd then
        notify.error("[" .. key .. "] " .. (err or "unknown error"))
        return false
      end
      local ok, run_err = util.run_detached(cmd, key)
      if ok then
        notify.info("[" .. key .. "] " .. url)
      else
        notify.error(run_err)
      end
      return ok
    end,
  }
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  -- System default -------------------------------------------------------
  register_fn({
    key  = "browser",
    desc = "Open in the system default browser (plain text → Google search)",
    run  = function(ctx)
      local url  = to_url(ctx)
      local plat = platform.get()
      local cmd  = default_browser_cmd(url, plat)
      local ok, err = util.run_detached(cmd, "browser")
      if ok then
        notify.info(url)
      else
        notify.error(err)
      end
      return ok
    end,
  })

  -- Named browsers -------------------------------------------------------
  register_fn(make_named_handler(
    "chrome", "Open in Google Chrome",
    { "google-chrome", "google-chrome-stable", "chromium", "chromium-browser" },
    "Google Chrome", "chrome"
  ))

  register_fn(make_named_handler(
    "chromium", "Open in Chromium",
    { "chromium", "chromium-browser", "google-chrome" },
    "Chromium", "chrome"
  ))

  register_fn(make_named_handler(
    "firefox", "Open in Mozilla Firefox",
    { "firefox", "firefox-esr" },
    "Firefox", "firefox"
  ))

  register_fn(make_named_handler(
    "edge", "Open in Microsoft Edge",
    { "microsoft-edge", "microsoft-edge-stable", "microsoft-edge-dev" },
    "Microsoft Edge", "msedge"
  ))

  register_fn(make_named_handler(
    "brave", "Open in Brave",
    { "brave-browser", "brave" },
    "Brave Browser", "brave"
  ))

  register_fn(make_named_handler(
    "opera", "Open in Opera",
    { "opera" },
    "Opera", "opera"
  ))

  -- Safari (macOS only) --------------------------------------------------
  register_fn({
    key  = "safari",
    desc = "Open in Safari (macOS only)",
    run  = function(ctx)
      if not platform.get().is_mac then
        notify.warn("Safari is only available on macOS")
        return false
      end
      local url = to_url(ctx)
      local ok, err = util.run_detached({ "open", "-a", "Safari", url }, "safari")
      if ok then
        notify.info(url)
      else
        notify.error(err)
      end
      return ok
    end,
  })
end

return M
