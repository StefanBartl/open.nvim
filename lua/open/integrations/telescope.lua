---@module 'open.integrations.telescope'
---@brief Telescope source listing registered open.nvim handlers.
---@description
--- Opt-in: not loaded by open.setup(). Lists every registered handler with
--- a live preview of what it would open for the current context (same
--- context.gather() signals the actual :Open invocation would use), and
--- dispatches the handler chosen at <CR> exactly like :Open <key> would.
---
--- require("open.integrations.telescope").picker(opts)

local M = {}

---Open the picker. `opts` is forwarded to telescope's pickers.new().
---@param opts table|nil
function M.picker(opts)
  local ok_pickers, pickers = pcall(require, "telescope.pickers")
  if not ok_pickers then
    require("lib.nvim.notify").create("[open.integrations.telescope]").error(
      "telescope.nvim is not installed/loaded")
    return
  end

  local finders        = require("telescope.finders")
  local conf           = require("telescope.config").values
  local actions        = require("telescope.actions")
  local action_state    = require("telescope.actions.state")
  local previewers     = require("telescope.previewers")

  local context  = require("open.context")
  local registry = require("open.registry")

  context.with_cache(function()
    local signals  = context.gather()
    local handlers = registry.list()

    ---Best-effort preview of what `key` would open for the current context.
    ---@param key string
    ---@return string
    local function preview_line(key)
      local ok, ctx = pcall(context.resolve, nil, key, signals)
      if ok and ctx then return ctx.text end
      return "(nothing to open in the current context)"
    end

    pickers.new(opts or {}, {
      prompt_title = "open.nvim handlers",
      finder = finders.new_table({
        results = handlers,
        entry_maker = function(h)
          return {
            value   = h,
            display = string.format("%-14s  %s", h.key, h.desc),
            ordinal = h.key .. " " .. h.desc,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts or {}),
      previewer = previewers.new_buffer_previewer({
        title = "Would open",
        define_preview = function(self, entry)
          local lines = {
            "Handler: " .. entry.value.key,
            "",
            entry.value.desc,
            "",
            "Would open: " .. preview_line(entry.value.key),
          }
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if not entry then return end

          local ctx = context.resolve(nil, entry.value.key, signals)
          if not ctx then
            require("lib.nvim.notify").create("[open.integrations.telescope]").warn(
              "Nothing to open for handler '" .. entry.value.key .. "'")
            return
          end
          registry.dispatch(entry.value.key, ctx)
        end)
        return true
      end,
    }):find()
  end)
end

---Extension table for `telescope.register_extension()`, so the picker can
---also be invoked as `:Telescope open`.
---
---   require("telescope").register_extension(
---     require("open.integrations.telescope").extension()
---   )
---
---@return table
function M.extension()
  return { exports = { open = M.picker } }
end

return M
