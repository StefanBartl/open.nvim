---@module 'open_nvim.health'
---@brief :checkhealth open_nvim

local M = {}

local function exe(bin) return vim.fn.executable(bin) == 1 end

local function check_neovim()
  vim.health.start("open_nvim: core")
  if vim.fn.has("nvim-0.9") == 1 then
    vim.health.ok("Neovim >= 0.9")
  else
    vim.health.error("Neovim 0.9+ required")
  end
  if vim.system then
    vim.health.ok("vim.system available (Neovim 0.10+ — clean detach on Unix)")
  else
    vim.health.info("vim.system not available — falling back to jobstart (Neovim < 0.10)")
  end
end

local function check_lib_nvim()
  vim.health.start("open_nvim: lib.nvim")
  if pcall(require, "lib.nvim.notify") then
    vim.health.ok("lib.nvim.notify available")
  else
    vim.health.error("lib.nvim.notify not found — install StefanBartl/lib.nvim")
  end
end

local function check_platform()
  vim.health.start("open_nvim: platform")
  local ok, platform = pcall(require, "open_nvim.platform")
  if not ok then
    vim.health.error("cannot load open_nvim.platform")
    return
  end
  local p = platform.get()
  local detected = p.is_win   and "Windows (native)"
               or  p.is_wsl   and "WSL (Windows host, Linux kernel)"
               or  p.is_mac   and "macOS"
               or               "Linux"
  vim.health.ok("Detected: " .. detected)
end

local function check_executables()
  vim.health.start("open_nvim: executables")
  local ok, platform = pcall(require, "open_nvim.platform")
  if not ok then return end
  local p = platform.get()

  if p.is_win then
    -- Windows always has these, but let's confirm PATH is sane
    if exe("explorer.exe") then
      vim.health.ok("explorer.exe available (filemanager)")
    else
      vim.health.warn("explorer.exe not on PATH — filemanager handler may fail")
    end
    if exe("notepad.exe") then
      vim.health.ok("notepad.exe available (notepad/editor handler)")
    else
      vim.health.warn("notepad.exe not on PATH")
    end

  elseif p.is_wsl then
    if exe("wslview")  then vim.health.ok("wslview available (browser fallback)")
    else                    vim.health.info("wslview not found — will use cmd.exe /C start") end
    if exe("wslpath")  then vim.health.ok("wslpath available (filemanager path conversion)")
    else                    vim.health.warn("wslpath not found — filemanager handler will fail in WSL") end
    if exe("cmd.exe")  then vim.health.ok("cmd.exe available")
    else                    vim.health.warn("cmd.exe not on PATH") end

  elseif p.is_mac then
    if exe("open") then vim.health.ok("open available (filemanager + browser + notepad/editor)")
    else                vim.health.error("open not found — most handlers will fail on macOS") end

  else
    -- Linux
    if exe("xdg-open") then
      vim.health.ok("xdg-open available (filemanager + browser fallback)")
    else
      vim.health.warn("xdg-open not found — install xdg-utils")
    end
    for _, mgr in ipairs({ "nautilus", "thunar", "dolphin", "nemo", "pcmanfm", "caja" }) do
      if exe(mgr) then
        vim.health.ok("file manager: " .. mgr)
        break
      end
    end
    for _, ed in ipairs({ "gedit", "kate", "mousepad", "leafpad", "pluma", "xed" }) do
      if exe(ed) then
        vim.health.ok("GUI text editor: " .. ed)
        break
      end
    end
  end

  -- Browser candidates (all platforms)
  local found_browser = false
  for _, b in ipairs({ "google-chrome", "google-chrome-stable", "chromium", "firefox", "firefox-esr", "microsoft-edge" }) do
    if exe(b) then
      vim.health.ok("browser on PATH: " .. b)
      found_browser = true
      break
    end
  end
  if not found_browser and not p.is_win and not p.is_mac and not p.is_wsl then
    vim.health.info("no named browser found on PATH — system default (xdg-open) will be used")
  end
end

local function check_handlers()
  vim.health.start("open_nvim: registered handlers")
  local ok, reg = pcall(require, "open_nvim.registry")
  if not ok then
    vim.health.warn("registry not available — run setup() first")
    return
  end
  local keys = reg.list_keys()
  if #keys == 0 then
    vim.health.warn("no handlers registered — call require('open_nvim').setup()")
    return
  end
  for _, h in ipairs(reg.list()) do
    vim.health.ok(string.format("%-14s  %s", h.key, h.desc))
  end
end

function M.check()
  check_neovim()
  check_lib_nvim()
  check_platform()
  check_executables()
  check_handlers()
end

return M
