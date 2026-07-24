---@module 'open.handlers.filemanager'
---@brief Handler that opens a path in the system file manager.
---@description
--- Platform dispatch (`filemanager.reveal = true`, the default):
---   Windows  → explorer.exe /select,<path>  (reveals file in Explorer)
---   WSL      → explorer.exe via wslpath conversion
---   macOS    → open -R <file>  /  open <dir>  (Finder)
---   Linux    → xdg-open, then common managers as fallback
---
--- With `filemanager.reveal = false`, a file target navigates to its parent
--- directory instead of being selected there. Directory targets are always
--- navigated into, regardless of `reveal`.

local notify   = require("lib.nvim.notify").create("[open.filemanager]")
local platform = require("open.platform")
local util     = require("open.util")

local M = {}

---@param text string
---@return string|nil
local function resolve_path(text)
  local expanded = vim.fn.expand(text)
  return (expanded ~= "" and expanded) or nil
end

---@param path string
---@return boolean
local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

---@param unix_path string
---@return string|nil
local function wsl_to_win_path(unix_path)
  local out = vim.fn.system({ "wslpath", "-w", unix_path }):gsub("\n", "")
  return (out ~= "" and out) or nil
end

---@return string|nil
local function linux_file_manager()
  return util.find_exec({
    "xdg-open", "nautilus", "thunar",
    "nemo", "dolphin", "pcmanfm", "caja",
  })
end

---@param register_fn fun(h: OpenNvim.Handler): boolean
function M.register_all(register_fn)
  register_fn({
    key  = "filemanager",
    desc = "Open path in the system file manager",
    run  = function(ctx)
      if ctx.is_url then
        notify.warn("Text looks like a URL, not a path")
        return false
      end

      local path = resolve_path(ctx.text)
      if not path then
        notify.error("Cannot resolve path: " .. ctx.text)
        return false
      end

      local plat = platform.get()
      local cfg  = require("open.config").get()
      local reveal = cfg.filemanager == nil or cfg.filemanager.reveal ~= false
      local file = is_file(path)
      local cmd

      if plat.is_win then
        if file and reveal then
          cmd = { "cmd.exe", "/c", "start", '""', "explorer.exe", "/select," .. path }
        else
          local target = file and vim.fn.fnamemodify(path, ":h") or path
          cmd = { "cmd.exe", "/c", "start", '""', "explorer.exe", target }
        end

      elseif plat.is_wsl then
        local unix_target = (file and not reveal) and vim.fn.fnamemodify(path, ":h") or path
        local win_target  = wsl_to_win_path(unix_target)
        if not win_target then
          notify.error("wslpath conversion failed for: " .. unix_target)
          return false
        end
        if file and reveal then
          cmd = { "cmd.exe", "/c", "start", '""', "explorer.exe", "/select," .. win_target }
        else
          cmd = { "cmd.exe", "/c", "start", '""', "explorer.exe", win_target }
        end

      elseif plat.is_mac then
        if file and reveal then
          cmd = { "open", "-R", path }
        elseif file then
          cmd = { "open", vim.fn.fnamemodify(path, ":h") }
        else
          cmd = { "open", path }
        end

      else
        local mgr = linux_file_manager()
        if not mgr then
          notify.error("No file manager found on PATH")
          return false
        end
        local target = (file and not reveal) and vim.fn.fnamemodify(path, ":h") or path
        cmd = { mgr, target }
      end

      local ok, err = util.run_detached(cmd, "filemanager")
      if ok then
        notify.info(path)
      else
        notify.error(err)
      end
      return ok
    end,
  })
end

return M
