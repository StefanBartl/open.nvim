---@module 'open_nvim.bindings.usrcmds'
---@brief Registers the :Open user command and its tab-completion.

local M = {}

---Register the :Open [target] [scope] user command for the given config.
---@param cfg OpenNvim.Config
function M.register(cfg)
  vim.api.nvim_create_user_command(cfg.command, function(opts_cmd)
    local context  = require("open_nvim.context")
    local registry = require("open_nvim.registry")
    local signals  = context.gather()

    local target = (opts_cmd.fargs and opts_cmd.fargs[1])
      or context.default_target(signals)
    target = target:lower()

    local scope = opts_cmd.fargs and opts_cmd.fargs[2]
    local ctx   = context.resolve(scope, target, signals)

    if not ctx then
      require("lib.nvim.notify").create("[open_nvim]").warn("Nothing to open")
      return
    end

    registry.dispatch(target, ctx)
  end, {
    nargs = "*",
    desc  = ":Open — open path/URL with the specified handler",

    complete = function(arg_lead, cmd_line, cursor_pos)
      local before = cmd_line:sub(1, cursor_pos)
      local tokens = {}
      for tok in before:gmatch("%S+") do tokens[#tokens + 1] = tok end

      local starting_new = before:match("%s$") ~= nil
      local arg_index    = #tokens - 1 + (starting_new and 1 or 0)

      -- 1st arg: handler key
      if arg_index <= 1 then
        local ok_r, reg = pcall(require, "open_nvim.registry")
        if not ok_r then return {} end
        local names, out = reg.list_keys(), {}
        for i = 1, #names do
          if names[i]:sub(1, #arg_lead) == arg_lead then
            out[#out + 1] = names[i]
          end
        end
        return out
      end

      -- 2nd arg: scope token or file path
      if arg_lead:sub(1, 5) == "path=" then
        local rest = arg_lead:sub(6)
        local candidates = {}
        for _, f in ipairs(vim.fn.getcompletion(rest, "file")) do
          candidates[#candidates + 1] = "path=" .. f
        end
        return candidates
      end

      local out    = {}
      local scopes = { "%", "cfile", "path=" }
      for i = 1, #scopes do
        if scopes[i]:sub(1, #arg_lead) == arg_lead then
          out[#out + 1] = scopes[i]
        end
      end

      -- Named scope keywords
      local ok_cfg, kw_cfg = pcall(require, "open_nvim.config")
      if ok_cfg then
        local kw_names = {}
        for name in pairs(kw_cfg.get().keywords or {}) do
          if name:sub(1, #arg_lead) == arg_lead then
            kw_names[#kw_names + 1] = name
          end
        end
        table.sort(kw_names)
        for _, n in ipairs(kw_names) do
          out[#out + 1] = n
        end
      end

      for _, f in ipairs(vim.fn.getcompletion(arg_lead, "file")) do
        out[#out + 1] = f
      end
      return out
    end,
  })
end

return M
