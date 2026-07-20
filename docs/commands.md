# open.nvim — Command Reference

Two command families, both built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim) with
`<Tab>` completion:

- `:Open [target] [scope]` — route one thing to a handler
- `:Open viewer [kind] [scope] [options]` (wrappers `:UrlView`,
  `:MDLinksView`) — list links in a scope, then open or export them

## Table of content

- [Commands](#commands)
- [Scope (2nd argument)](#scope-2nd-argument)
- [Tab completion](#tab-completion)
- [`:Open viewer` / `:UrlView` / `:MDLinksView`](#open-viewer--urlview--mdlinksview)

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

## `:Open viewer` / `:UrlView` / `:MDLinksView`

Collect links in a scope, then pick one to open — or export the whole list as
a table, as markdown links, to the clipboard, or to a file.

```
:Open viewer [kind] [scope] [options]
```

`:UrlView` and `:MDLinksView` are shallow wrappers that pin the kind, so their
first argument is the *scope*. They replace the former
[urlview.nvim](https://github.com/axieax/urlview.nvim) dependency (see
[integrations.md](integrations.md)).

```
:UrlView                          URLs in the current buffer → picker
:MDLinksView cwd                  markdown links in every file under the cwd
:Open viewer                      every link in the current buffer
:Open viewer urls cwd             same as `:UrlView cwd`
:'<,'>UrlView                     URLs in the visual selection only
```

### Kind (1st argument of `:Open viewer`)

| Kind | Keeps |
|---|---|
| `all` *(default)* | Everything |
| `urls` | Links whose **target** is a URL — including `[text](https://…)` |
| `mdlinks` | Links written with markdown **syntax**, whatever they point at |
| `files` | Links whose target is a local file or directory |
| `paths` | Bare filesystem paths (requires `--paths`) |

`urls` and `mdlinks` deliberately overlap: `urls` asks "can a browser open
this?", `mdlinks` asks "was this written with brackets?". A
`[docs](https://x.dev)` is in both. That split is what makes `:UrlView` mean
"things I can open in a browser" instead of "things without brackets".

The kind argument is optional and may be omitted entirely — `:Open viewer cwd`
is read as "all kinds, cwd scope", because `cwd` does not name a kind.

### Scope

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
| `--anchors` | Include bare in-document anchors (`[Kontext](#kontext)`), which are dropped by default. |
| `--dupes` | Keep duplicate targets (the default de-duplicates). |
| `--flat` | Do not recurse into subdirectories. |

Flags and `key=value` options may appear in any order, before or after the
positional arguments.

### The picker

The results list is lib.nvim's
[`ui.kit.chooser`](https://github.com/StefanBartl/lib.nvim), which means:

- the **whole current line** is highlighted (`CursorLine:KitSelection`)
- the cursor moves **only up and down** — `j`/`k` and the arrow keys; `h`,
  `l`, `0`, `$`, `w`, `b` and friends are mapped to `<Nop>`
- `<CR>` opens the entry, `<Esc>` or `q` closes

**`<CR>` is kind-aware:**

| Entry | Opens in |
|---|---|
| A URL | Your browser, via the `default_browser` handler |
| A local file | A **Neovim split** (configurable — see `viewer.open_file`) |
| A directory | The system file manager |

Following a markdown link lands you in an editable buffer, not in Explorer.
A `file.md#heading` target jumps to that heading after opening.

Columns are aligned across the whole result set and shortened to fit the
window: local targets are shown relative to the cwd, and long paths are
elided in the middle rather than pushing the target off the right edge.

### Outputs

| `out=` | Result |
|---|---|
| `picker` | Interactive list (see above) |
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
:UrlView cwd sort=file out=table         a table of every URL in the project
:MDLinksView cwd                         every markdown link, as a picker
:Open viewer files cwd --paths           local targets, incl. bare paths
:UrlView cwd match=%.md$ out=mdlinks     doc URLs as markdown, to clipboard
:UrlView % out=file:/tmp/links.md        current buffer's URLs, to a file
:Open viewer cwd --flat --dupes          top level only, duplicates kept
:MDLinksView % --anchors                 include TOC anchors too
```

### Tab completion

```
:Open viewer <Tab>                all  urls  mdlinks  files  paths  %  cwd  buffers  <files>
:Open viewer urls <Tab>           %  cwd  buffers  <file completion>
:UrlView <Tab>                    %  cwd  buffers  <file completion>
:UrlView cwd sort=<Tab>           none  file  kind  alpha
:UrlView cwd out=<Tab>            picker  table  clipboard  mdlinks  csv  echo  file:
```

### Defaults

The sort, the default output, the handler used for local files, and the
wrapper command names are all configurable — see
[configuration.md](configuration.md).
