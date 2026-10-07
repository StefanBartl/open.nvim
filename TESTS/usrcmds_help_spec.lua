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
  end
end
