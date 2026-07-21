# open.nvim — Built-in Keywords

Named scope aliases for commonly edited config files. Use them as the 2nd
argument to any handler: `:Open <handler> <keyword>`.

All keywords support tab-completion.

## Table of content

- [Shell profiles](#shell-profiles)
- [Editor / IDE](#editor--ide)
- [Terminal emulators & multiplexers](#terminal-emulators--multiplexers)
- [Git](#git)
- [SSH](#ssh)
- [Package managers & runtimes](#package-managers--runtimes)
- [System / misc](#system--misc)
- [User-defined keywords](#user-defined-keywords)

## Shell profiles

| Keyword | Path |
|---|---|
| `pwsh_profile` | PowerShell `$PROFILE` (all platforms, requires `pwsh` or `powershell`) |
| `zshrc` | `~/.zshrc` |
| `zprofile` | `~/.zprofile` |
| `bashrc` | `~/.bashrc` |
| `bash_profile` | `~/.bash_profile` |
| `profile` | `~/.profile` |
| `fish_config` | `~/.config/fish/config.fish` |
| `nushell_config` | `~/.config/nushell/config.nu` |

## Editor / IDE

| Keyword | Path |
|---|---|
| `nvim_init` | `~/AppData/Local/nvim/init.lua` (Win) · `~/.config/nvim/init.lua` (Unix) |
| `vimrc` | `~/.vimrc` |

## Terminal emulators & multiplexers

| Keyword | Path |
|---|---|
| `tmux_conf` | `~/.config/tmux/tmux.conf` or `~/.tmux.conf` |
| `wezterm_conf` | `~/.config/wezterm/wezterm.lua` or `~/.wezterm.lua` |
| `kitty_conf` | `~/.config/kitty/kitty.conf` |
| `alacritty_conf` | `.toml` preferred, `.yml` fallback |
| `starship_conf` | `~/.config/starship.toml` |

## Git

| Keyword | Path |
|---|---|
| `gitconfig` | `~/.gitconfig` |
| `gitignore_global` | `core.excludesFile` from git config, or `~/.gitignore_global` |
| `gitmessage` | `commit.template` from git config, or `~/.gitmessage` |

## SSH

| Keyword | Path |
|---|---|
| `ssh_config` | `~/.ssh/config` |
| `ssh_known_hosts` | `~/.ssh/known_hosts` |
| `ssh_authorized_keys` | `~/.ssh/authorized_keys` |

## Package managers & runtimes

| Keyword | Path |
|---|---|
| `npmrc` | `~/.npmrc` |
| `yarnrc` | `~/.yarnrc.yml` |
| `cargo_config` | `~/.cargo/config.toml` |
| `pip_conf` | `~/.config/pip/pip.conf` (Unix) · `%APPDATA%\pip\pip.ini` (Win) |
| `gemrc` | `~/.gemrc` |
| `curlrc` | `~/.curlrc` |

## System / misc

| Keyword | Path / Platform |
|---|---|
| `inputrc` | `~/.inputrc` (Readline config) |
| `hosts` | `/etc/hosts` (Unix) · `C:\Windows\System32\drivers\etc\hosts` (Win) |
| `docker_config` | `~/.docker/config.json` |
| `wsl_conf` | `/etc/wsl.conf` (WSL only) |
| `wslconfig` | `~/.wslconfig` (Windows only) |

## User-defined keywords

Add your own in `setup()`:

```lua
require("open").setup({
  keywords = {
    MY_ROADMAP = "E:\\projects\\ROADMAP.md",
    MY_LOGO    = "E:\\assets\\logo.png",
    -- dynamic resolver:
    MY_DATE_LOG = function()
      return vim.fn.expand("~/logs/") .. os.date("%Y-%m-%d") .. ".md"
    end,
  },
})
```

Then use them like any built-in: `:Open split MY_ROADMAP`, `:Open default MY_LOGO`.

To override a built-in, use the same key: `keywords = { zshrc = "~/dotfiles/.zshrc" }`.
To disable all built-ins: `builtin_keywords = false`.
