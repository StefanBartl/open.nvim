# Quickstart

Put the cursor on a path or a URL and let it decide where that belongs:

```vim
:Open
```

With no arguments it resolves the context itself — a tree node opens in the
file manager, a URL in the browser, a path in the sensible place for a path.
Then, when you want to say where it goes:

```vim
:Open browser %       " the current file in the browser, as a file:// URL
:Open split cfile     " the path under the cursor, in a split
:Open terminal %      " a terminal split rooted in this file's directory
```

And the other direction — the links in a buffer or the whole project:

```vim
:UrlView                              " URLs in this buffer, pick one to open
:MDLinksView cwd                      " every Markdown link in the project
:Open viewer cwd sort=file out=table  " all of it, as a Markdown table
```

Verify your setup any time with:

```vim
:checkhealth open
```

The second argument is the scope: `%` for the current file, `cfile` for the
path under the cursor, `cwd` for the working directory, a
[named keyword](keywords.md) for a config file you open often, or nothing at
all for the heuristic. Both arguments complete with `<Tab>`; the full table of
handlers is [cheatsheet.md](cheatsheet.md).
