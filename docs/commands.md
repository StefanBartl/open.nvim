# open.nvim — Command Reference

## Table of content

- [Commands](#commands)
- [Scope (2nd argument)](#scope-2nd-argument)
- [Tab completion](#tab-completion)

## Commands

```
:Open                          context-aware default (tree → filemanager, URL → browser)
:Open default                  open in the system default application (like double-click)
:Open filemanager              open current path/node in the system file manager
:Open browser                  open URL or text in the system default browser
:Open chrome                   open in Google Chrome
:Open firefox                  open in Mozilla Firefox
:Open edge                     open in Microsoft Edge
:Open safari                   open in Safari (macOS only)
:Open notepad                  copy text to a temp file and open in GUI editor
:Open editor                   alias for notepad
:Open split                    open file in a horizontal split
:Open vsplit                   open file in a vertical split
:Open tab                      open file in a new tab
```

## Scope (2nd argument)

| Scope | What is opened |
|---|---|
| *(omitted)* | Target-aware heuristic (tree node → cfile → buffer path or cWORD) |
| `%` | Current buffer's file path |
| `cfile` | `<cfile>` text under the cursor |
| `path=<path>` | Literal path (supports file completion after `path=`) |
| `<keyword>` | Named scope keyword (see [docs/keywords.md](keywords.md)) |
| `<text>` | Any other text is used verbatim |

Examples:
```
:Open browser %                   open current file in browser (file:// URL)
:Open filemanager cfile           open <cfile> path in file manager
:Open browser path=/tmp/x.md      open a specific file in browser
:Open split nvim_init             open your Neovim init.lua in a split
:Open tab zshrc                   open ~/.zshrc in a new tab
:Open split pwsh_profile          open PowerShell $PROFILE in a split
:Open default MY_ROADMAP          open a user keyword with the default app
```

## Tab completion

```
:Open <Tab>                      all registered handler names
:Open browser <Tab>              %  cfile  path=  <keywords>  <file completion>
:Open split <Tab>                %  cfile  path=  <keywords>  <file completion>
:Open filemanager path=<Tab>     file/directory completion after path=
:Open split zsh<Tab>             → zshrc  zprofile  (keyword prefix filter)
```
