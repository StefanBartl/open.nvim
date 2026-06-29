---@module 'open_nvim.keywords'
---@brief Built-in named scope aliases for common config and system files.
---@description
--- Each entry in the returned table maps a keyword string to either a static
--- expanded path (string) or a resolver function (fun(): string|nil).
---
--- Functions are called lazily at scope-resolution time so that blocking
--- calls (vim.system, git config …) only run when actually needed.
---
--- Users can override individual entries or disable all built-ins:
---   setup({ builtin_keywords = false })
---   setup({ keywords = { zshrc = "~/dotfiles/.zshrc" } })

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function expand(p)
  return vim.fn.expand(p)
end

---Run a command synchronously and return trimmed stdout, or nil on failure.
---@param argv string[]
---@return string|nil
local function capture(argv)
  if not vim.system then return nil end
  local res = vim.system(argv, { text = true }):wait()
  if res.code ~= 0 then return nil end
  local out = (res.stdout or ""):gsub("\n", ""):gsub("\r", "")
  return out ~= "" and out or nil
end

---Return the first path in `candidates` that exists on disk, else last entry.
---@param candidates string[]
---@return string
local function first_existing(candidates)
  for _, p in ipairs(candidates) do
    if vim.uv.fs_stat(p) then return p end
  end
  return candidates[#candidates]
end

-- ---------------------------------------------------------------------------
-- Dynamic resolvers
-- ---------------------------------------------------------------------------

local function resolve_pwsh_profile()
  local exe = vim.fn.executable("pwsh") == 1 and "pwsh"
    or (vim.fn.executable("powershell") == 1 and "powershell")
    or nil
  if not exe then return nil end
  return capture({ exe, "-NoProfile", "-Command", "[Console]::Write($PROFILE)" })
end

local function resolve_nvim_init()
  local platform = require("open_nvim.platform").get()
  local base = platform.is_win
    and expand("~/AppData/Local/nvim")
    or expand("~/.config/nvim")
  return first_existing({ base .. "/init.lua", base .. "/init.vim" })
end

local function resolve_tmux_conf()
  return first_existing({
    expand("~/.config/tmux/tmux.conf"),
    expand("~/.tmux.conf"),
  })
end

local function resolve_wezterm_conf()
  return first_existing({
    expand("~/.config/wezterm/wezterm.lua"),
    expand("~/.wezterm.lua"),
  })
end

local function resolve_alacritty_conf()
  return first_existing({
    expand("~/.config/alacritty/alacritty.toml"),
    expand("~/.config/alacritty/alacritty.yml"),
    expand("~/.alacritty.toml"),
    expand("~/.alacritty.yml"),
  })
end

local function resolve_gitignore_global()
  local from_cfg = capture({ "git", "config", "--global", "core.excludesFile" })
  return from_cfg or first_existing({
    expand("~/.config/git/ignore"),
    expand("~/.gitignore_global"),
    expand("~/.gitignore"),
  })
end

local function resolve_gitmessage()
  local from_cfg = capture({ "git", "config", "--global", "commit.template" })
  return from_cfg or expand("~/.gitmessage")
end

local function resolve_pip_conf()
  local platform = require("open_nvim.platform").get()
  if platform.is_win then
    local appdata = vim.fn.getenv("APPDATA") or ""
    return appdata .. "\\pip\\pip.ini"
  end
  return expand("~/.config/pip/pip.conf")
end

local function resolve_hosts()
  local platform = require("open_nvim.platform").get()
  if platform.is_win then
    return "C:\\Windows\\System32\\drivers\\etc\\hosts"
  end
  return "/etc/hosts"
end

local function resolve_docker_config()
  return expand("~/.docker/config.json")
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

---Return the built-in keyword table for the current platform.
---@return table<string, string|fun(): string|nil>
function M.builtin()
  local platform = require("open_nvim.platform").get()

  ---@type table<string, string|fun(): string|nil>
  local kw = {}

  -- ── Shell profiles ────────────────────────────────────────────────────────
  kw.pwsh_profile    = resolve_pwsh_profile         -- PowerShell $PROFILE (all platforms)
  kw.zshrc           = expand("~/.zshrc")
  kw.zprofile        = expand("~/.zprofile")
  kw.bashrc          = expand("~/.bashrc")
  kw.bash_profile    = expand("~/.bash_profile")
  kw.profile         = expand("~/.profile")         -- POSIX sh / many Linux distros
  kw.fish_config     = expand("~/.config/fish/config.fish")
  kw.nushell_config  = expand("~/.config/nushell/config.nu")

  -- ── Editor / IDE ──────────────────────────────────────────────────────────
  kw.nvim_init       = resolve_nvim_init             -- init.lua or init.vim
  kw.vimrc           = expand("~/.vimrc")

  -- ── Terminal emulators & multiplexers ─────────────────────────────────────
  kw.tmux_conf       = resolve_tmux_conf             -- ~/.config/tmux/tmux.conf or ~/.tmux.conf
  kw.wezterm_conf    = resolve_wezterm_conf           -- ~/.config/wezterm/wezterm.lua or ~/.wezterm.lua
  kw.kitty_conf      = expand("~/.config/kitty/kitty.conf")
  kw.alacritty_conf  = resolve_alacritty_conf        -- .toml preferred, .yml fallback
  kw.starship_conf   = expand("~/.config/starship.toml")

  -- ── Git ───────────────────────────────────────────────────────────────────
  kw.gitconfig       = expand("~/.gitconfig")
  kw.gitignore_global = resolve_gitignore_global     -- from git config or common fallbacks
  kw.gitmessage      = resolve_gitmessage            -- from git config or ~/.gitmessage

  -- ── SSH ───────────────────────────────────────────────────────────────────
  kw.ssh_config      = expand("~/.ssh/config")
  kw.ssh_known_hosts = expand("~/.ssh/known_hosts")
  kw.ssh_authorized_keys = expand("~/.ssh/authorized_keys")

  -- ── Package managers & runtimes ───────────────────────────────────────────
  kw.npmrc           = expand("~/.npmrc")
  kw.yarnrc          = expand("~/.yarnrc.yml")
  kw.cargo_config    = expand("~/.cargo/config.toml")
  kw.pip_conf        = resolve_pip_conf              -- platform path
  kw.gemrc           = expand("~/.gemrc")
  kw.curlrc          = expand("~/.curlrc")

  -- ── System / misc ─────────────────────────────────────────────────────────
  kw.inputrc         = expand("~/.inputrc")          -- Readline config
  kw.hosts           = resolve_hosts                 -- /etc/hosts or Windows equivalent
  kw.docker_config   = resolve_docker_config         -- ~/.docker/config.json

  -- Platform-specific --------------------------------------------------------
  if platform.is_wsl then
    kw.wsl_conf      = "/etc/wsl.conf"              -- WSL Linux-side settings
  end
  if platform.is_win then
    kw.wslconfig     = expand("~/.wslconfig")       -- WSL2 global settings (Windows side)
  end

  return kw
end

return M
