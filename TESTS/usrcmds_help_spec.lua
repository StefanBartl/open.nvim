-- TESTS/usrcmds_help_spec.lua -- every flag and key=value pair of the viewer commands has a line in
-- lib.nvim's option float.
--
-- The text comes from `viewer_flags()` / `viewer_kv()` in bindings/usrcmds.lua, which `:Open viewer`,
-- `:UrlView`, `:MDLinksView` and the optional all-links wrapper share. A new option without a `desc`
-- shows up as a bare row in the cheatsheet, so this fails until it is described.

return function(H)
  local ok, composer = pcall(require, "lib.nvim.bindings.usercmd.composer")
  H.ok(ok, "the composer loads")

  -- A lib.nvim older than `help.undocumented` cannot answer the question; that is a missing
  -- feature of the dependency, not a defect of this plugin.
  if type(composer.help.undocumented) ~= "function" then return end

  -- `all` is off by default; switching it on registers the fourth viewer verb.
  require("open").setup({ viewer = { commands = { all = "OpenViewAll" } } })

  for _, name in ipairs({ "Open", "UrlView", "MDLinksView", "OpenViewAll" }) do
    H.ok(composer.registry()[name] ~= nil, ":" .. name .. " is registered through the composer")

    local missing = {}
    for _, m in ipairs(composer.help.undocumented(name)) do
      missing[#missing + 1] = m.name
    end
    H.eq(
      #missing,
      0,
      ":" .. name .. " options without a help text: " .. table.concat(missing, ", ")
    )

    -- The positional arguments too: their text comes from the argument types registered in
    -- bindings/usrcmds.lua (OPEN_TARGET, OPEN_SCOPE, VIEWER_KIND, VIEWER_SCOPE).
    local missing_args = {}
    for _, m in ipairs(composer.help.undocumented(name, { args = true })) do
      missing_args[#missing_args + 1] = m.kind .. ":" .. m.name
    end
    H.eq(
      #missing_args,
      0,
      ":" .. name .. " arguments without a help text: " .. table.concat(missing_args, ", ")
    )
  end

  -- The type texts follow the house style: one line, no trailing period, at most 80 characters.
  local argtypes = require("lib.nvim.bindings.usercmd.composer.argtypes")
  for _, type_name in ipairs({ "OPEN_TARGET", "OPEN_SCOPE", "VIEWER_KIND", "VIEWER_SCOPE" }) do
    local def = argtypes.get(type_name)
    H.ok(def ~= nil, type_name .. " is a registered argument type")
    local text = def and def.desc or ""
    H.ok(text ~= "", type_name .. " has a help text")
    H.ok(
      not text:find("\n", 1, true) and text:sub(-1) ~= "." and #text <= 80,
      type_name .. " text is one line, without a trailing period, <= 80 characters: " .. text
    )
  end
end
