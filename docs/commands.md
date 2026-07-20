# open.nvim — Command Reference

Two commands, both built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim) with
`<Tab>` completion:

- `:Open [target] [scope]` — route one thing to a handler
- `:Open urlview [scope] [options]` (alias `:UrlView`) — list every link in a
  scope, then open or export them

## Table of content

- [Commands](#commands)
- [Scope (2nd argument)](#scope-2nd-argument)
- [Tab completion](#tab-completion)
- [`:Open urlview` / `:UrlView`](#open-urlview--urlview)

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

## `:Open urlview` / `:UrlView`

Collect every link in a scope, then pick one to open — or export the whole
list as a table, as markdown links, to the clipboard, or to a file.

`:UrlView` is a shallow wrapper around `:Open urlview`; both take exactly the
same arguments. It replaces the former
[urlview.nvim](https://github.com/axieax/urlview.nvim) dependency (see
[integrations.md](integrations.md)).

```
:UrlView                          links in the current buffer → picker
:UrlView cwd                      links in every file under the cwd
:UrlView buffers                  links in every listed, loaded buffer
:UrlView ~/notes                  links in a file or directory (recursive)
:'<,'>UrlView                     links in the visual selection only
```

### Scope (1st argument)

| Scope | What is scanned |
|---|---|
| *(omitted)* or `%` | Current buffer |
| `cwd` | Every file under `getcwd()`, recursively |
| `buffers` | Every listed, loaded buffer |
| `<path>` | A file, or a directory (recursively) |
| *(a range)* | `:'<,'>UrlView` or `:10,20UrlView` scans only those lines |

Directory scans skip the conventional junk (`.git`, `node_modules`, …) via
lib.nvim's shared ignore list, and skip binary or oversized files.

### Options

| Option | Meaning |
|---|---|
| `sort=none\|file\|kind\|alpha` | Ordering. Default `none` (source order). |
| `out=picker\|table\|clipboard\|mdlinks\|csv\|echo` | Where results go. Default `picker`. |
| `out=file:<path>` | Write the rendered table to a file. |
| `match=<lua pattern>` | Only scan files whose basename matches, e.g. `match=%.md$`. |
| `--paths` | Also report filesystem paths, not just URLs (only ones that exist). |
| `--all` | Keep duplicate targets (the default de-duplicates). |
| `--flat` | Do not recurse into subdirectories. |

Flags and `key=value` options may appear in any order, before or after the
scope.

### Outputs

| `out=` | Result |
|---|---|
| `picker` | Interactive list; the pick is opened through the configured handler |
| `table` | GFM table (Kind / Location / Text / Target) in a scratch buffer |
| `csv` | Same columns as CSV in a scratch buffer |
| `mdlinks` | `[label](target)` per line, copied to the clipboard |
| `clipboard` | The rendered table, copied to the clipboard |
| `echo` | Printed to the message area |
| `file:<path>` | The rendered table, written to `<path>` |

`mdlinks` reuses an existing markdown label when there is one, and otherwise
labels a URL with its host and a path with its basename — `[](…)` would
render as an invisible link.

### Examples

```
:UrlView cwd sort=file out=table         a table of every link in the project
:UrlView cwd match=%.md$ out=mdlinks     markdown links from the docs, to clipboard
:UrlView ~/notes --paths sort=kind       URLs and existing paths, grouped by kind
:UrlView % out=file:/tmp/links.md        current buffer's links, written to a file
:UrlView cwd --flat --all                top level only, duplicates kept
```

### Tab completion

```
:UrlView <Tab>                    %  cwd  buffers  <file completion>
:UrlView cwd sort=<Tab>           none  file  kind  alpha
:UrlView cwd out=<Tab>            picker  table  clipboard  mdlinks  csv  echo  file:
```

### Defaults

`sort`, the default output, and the wrapper command's name are configurable —
see [configuration.md](configuration.md).
