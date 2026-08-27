---@module 'open.office_open'
---@brief Auto-redirect MS Office (and compatible) documents to the system
---       default application instead of loading them as a text buffer.
---@description
--- `.docx`, `.xlsx`, `.pptx` and friends are binary containers — there is
--- nothing useful Neovim can show by reading them as text. This installs a
--- `BufReadCmd` autocmd for the configured extensions that hands the path
--- straight to `lib.nvim.cross.open_default` (the same dispatch the
--- "default" handler uses: `explorer.exe` / `open` / `xdg-open`) and then
--- wipes the placeholder buffer Neovim created for the read.
---
--- `BufReadCmd` is Neovim's own read hook, so this fires no matter how the
--- path was reached — `:e`, `gf`, a picker, or a tree plugin's `<CR>` —
--- unlike the "default" handler, which only runs when `:Open default` is
--- invoked explicitly.

local notify = require("lib.nvim.notify").create("[open.office_open]")

local M = {}

local AUGROUP = "OpenNvimOfficeOpen"

---Build the autocmd `pattern` string from a list of bare extensions.
---@internal
---@param extensions string[]
---@return string
local function build_pattern(extensions)
  local parts = {}
  for _, ext in ipairs(extensions) do
    parts[#parts + 1] = "*." .. ext
  end
  return table.concat(parts, ",")
end

---`BufReadCmd` callback: open externally, then wipe the placeholder buffer.
---@internal
---@param args table  autocmd callback args (`{ buf, file, match, ... }`)
local function on_read(args)
  local path = vim.fn.fnamemodify(args.file, ":p")
  local ok, err = require("lib.nvim.cross.open_default")(path)
  if ok then
    notify.info("Opened externally: " .. path)
  else
    notify.error(err or ("Cannot determine how to open: " .. path))
  end

  -- BufReadCmd suppressed Neovim's own read, so the buffer is an empty
  -- placeholder. Wipe it so it doesn't linger as a fake "file" in the
  -- buffer/arglist; Neovim falls back to an empty [No Name] buffer if this
  -- was the only one open (e.g. `nvim report.docx` from a shell).
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(args.buf) then
      pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
    end
  end)
end

---Install (or, called again, replace) the `BufReadCmd` redirect.
---Idempotent: always clears the augroup first, so re-running `setup()` with
---`enabled = false` or an empty `extensions` list turns the redirect off
---instead of stacking duplicate autocmds.
---@param cfg OpenNvim.OfficeOpen.Config|nil
function M.setup(cfg)
  local autocmd = require("lib.nvim.bindings.autocmd")
  -- Clearing goes through lib as well, not just the creation: it drops the
  -- old records along with the old autocmds, so a re-run does not leave
  -- stale rows in the generated `bindings/autocmd` docs.
  local group = autocmd.group(AUGROUP, true)

  if not cfg or not cfg.enabled then return end
  local extensions = cfg.extensions or {}
  if #extensions == 0 then return end

  autocmd.create("BufReadCmd", on_read, {
    group = group,
    pattern = build_pattern(extensions),
    desc = "open.nvim: redirect MS Office documents to the system app",
  })
end

return M
