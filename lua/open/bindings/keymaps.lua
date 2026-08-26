---@module 'open.bindings.keymaps'
---@brief Optional keymaps for common :Open invocations, configured via setup().
---@description
--- open.nvim ships with no default keymaps. Setting `cfg.keymaps.<name>` to
--- an lhs string registers a normal-mode keymap for that fixed invocation:
---
---   open_default  = "<leader>oo"  -- :Open
---   open_browser  = "<leader>ob"  -- :Open browser
---   open_manager  = "<leader>of"  -- :Open filemanager
---   open_split    = "<leader>os"  -- :Open split
---   open_terminal = "<leader>ot"  -- :Open terminal
---
--- **The accepted names come from the handler registry, not from a list kept
--- here.** They used to be a hardcoded three, which is why `split`, `vsplit`,
--- `tab`, `terminal`, `image` and `notepad` had no keymap option despite being
--- perfectly ordinary `:Open <target>` values -- the list simply had not grown
--- with the handlers. Now every registered handler `key` is available as
--- `open_<key>`, and adding a handler (including a `custom_handlers` one)
--- brings its keymap option along for free.
---
--- Because the source is the *live* registry rather than a static list, a
--- target the user switched off via `cfg.handlers` is correctly rejected here
--- too, instead of mapping a key to a command that would fail at press time.

local keymap = require("lib.nvim.bindings.keymap")
local notify = require("lib.nvim.notify").create("[open.keymaps]")
local registry = require("open.registry")

local M = {}

---The bare `:Open`, with no target argument.
---
---This name collides with the registry's own `default` handler, which
---`open_<key>` would otherwise claim. The collision is harmless -- `:Open`
---and `:Open default` both end up at the context-aware default handler -- and
---resolving it in favor of the bare command keeps the historical meaning of
---this key exactly as it was.
local DEFAULT_NAME = "open_default"

---Historical name that does not follow `open_<handler key>`: it predates the
---registry-driven scheme and maps to the `filemanager` handler. Kept because
---renaming it would silently break every existing config that sets it.
---@type table<string, string>
local ALIASES = { open_manager = "filemanager" }

---Every `keymaps.<name>` this setup would accept, for an error message that
---names the alternatives instead of only rejecting.
---@internal
---@return string
local function accepted_names()
  local seen = { [DEFAULT_NAME] = true }
  local names = { DEFAULT_NAME }

  local function add(name)
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end

  -- `open_default` is already in, so the registry's own `default` handler
  -- does not produce a second copy of it.
  for _, key in ipairs(registry.list_keys()) do
    add("open_" .. key)
  end
  for alias in pairs(ALIASES) do
    add(alias)
  end

  table.sort(names)
  return table.concat(names, ", ")
end

---Declare and bind the keymaps from `cfg.keymaps`.
---
--- Runs after handler registration in `setup()`, which is what lets it read
--- the registry rather than duplicate it.
---
--- Declared through `lib.nvim.bindings.keymap`'s registry, with one departure:
--- unknown names are still rejected *here*, not by the registry. This name
--- space is generated from the live handler set, so naming every accepted
--- alternative is worth more than the registry's nearest-match guess -- and a
--- name is filtered out before it reaches the registry, so nothing warns
--- twice.
---@param cfg OpenNvim.Config
---@return Lib.Keymap.Registered[]|nil
function M.register(cfg)
  local keymaps = cfg.keymaps
  if type(keymaps) ~= "table" then return end

  ---@type table<string, Lib.Keymap.Action>
  local actions = {}
  ---@type string[]
  local order = {}

  ---@param name string
  ---@param target string|nil
  local function declare(name, target)
    if actions[name] then return end
    local cmd = target and (cfg.command .. " " .. target) or cfg.command
    actions[name] = { rhs = ("<Cmd>%s<CR>"):format(cmd), desc = ":" .. cmd }
    order[#order + 1] = name
  end

  -- The bare `:Open` first, so the registry's own `default` handler cannot
  -- claim `open_default` and change what that historical key means.
  declare(DEFAULT_NAME, nil)
  for _, key in ipairs(registry.list_keys()) do
    if key ~= "default" then declare("open_" .. key, key) end
  end
  for alias, target in pairs(ALIASES) do
    if registry.get(target) then declare(alias, target) end
  end
  table.sort(order)

  ---@type table<string, string|false>
  local user = {}
  for name, lhs in pairs(keymaps) do
    if actions[name] then
      user[name] = lhs
    else
      notify.warn(
        ("Unknown keymaps.%s — ignoring. Accepted: %s"):format(tostring(name), accepted_names())
      )
    end
  end

  return keymap.register("open.nvim", { order = order, actions = actions }, user)
end

return M
