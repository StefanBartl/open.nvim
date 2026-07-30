-- luacheck configuration for open.nvim
std = "luajit"
read_globals = { "vim" }

-- The plugin-load guard in plugin/open.lua writes vim.g.loaded_open.
globals = { "vim.g" }

-- The codebase favours readability over an 80/120 column cap; stylua already
-- enforces a 100-column target where it can break lines safely.
max_line_length = false

-- Handler `run(ctx)` callbacks and the composer type `validate`/`complete`
-- signatures are fixed by their caller, so several legitimately ignore an
-- argument. Underscore-prefixed names are skipped by luacheck already; this
-- silences the remainder rather than renaming across a stable interface.
ignore = {
  "212", -- unused argument
}

-- The headless specs stub vim.ui.select / vim.api.* / vim.bo to observe what
-- the plugin would have done without actually opening anything. Assigning to
-- those fields is the entire point of a stub, so the read-only-field warning
-- is noise here rather than in lua/.
files["TESTS/"] = {
  ignore = {
    "122", -- setting a read-only field of an upvalue/global (vim.*)
  },
}
