-- TESTS/harvest_render_spec.lua — lib.nvim.harvest.render output shapes.

return function(H)
  local render = require("lib.nvim.harvest.render")

  -- markdown_table -----------------------------------------------------------
  do
    local out = render.markdown_table({ "A", "B" }, { { "1", "2" }, { "333", "4" } })
    local lines = vim.split(out, "\n", { plain = true })
    H.eq(#lines, 4, "header + delimiter + 2 rows")
    H.contains(lines[1], "| A", "header row present")
    H.contains(lines[2], "---", "delimiter row present")

    -- Every row must be padded to the same display width, or the table looks
    -- ragged in a fixed-width terminal.
    local w = vim.fn.strdisplaywidth(lines[1])
    for i, l in ipairs(lines) do
      H.eq(vim.fn.strdisplaywidth(l), w, "row " .. i .. " has uniform width")
    end
  end

  -- an embedded pipe must not split a cell -----------------------------------
  do
    local out = render.markdown_table({ "A" }, { { "x|y" } })
    H.contains(out, "x\\|y", "pipe inside a cell is escaped")
  end

  -- embedded newlines are flattened ------------------------------------------
  do
    local out = render.markdown_table({ "A" }, { { "x\ny" } })
    H.eq(#vim.split(out, "\n", { plain = true }), 3, "newline in a cell does not add a row")
  end

  -- ragged rows are padded to the widest row ---------------------------------
  do
    local out = render.markdown_table({ "A" }, { { "1", "2", "3" } })
    local lines = vim.split(out, "\n", { plain = true })
    local _, count = lines[1]:gsub("|", "")
    H.eq(count, 4, "column count grows to the widest row")
  end

  -- alignment markers --------------------------------------------------------
  do
    local out = render.markdown_table({ "A", "B", "C" }, { { "1", "2", "3" } }, {
      align = { "l", "c", "r" },
    })
    local delim = vim.split(out, "\n", { plain = true })[2]
    H.contains(delim, ":-", "centre/right alignment emits a leading colon")
    H.contains(delim, "-:", "right alignment emits a trailing colon")
  end

  -- empty input --------------------------------------------------------------
  H.eq(render.markdown_table({}, {}), "", "no columns renders as empty string")

  -- csv ----------------------------------------------------------------------
  do
    local out = render.csv({ "a", "b" }, { { "1", "2" } })
    H.eq(out, "a,b\n1,2", "plain csv round-trips")

    local quoted = render.csv(nil, { { 'has,comma', 'has"quote' } })
    H.contains(quoted, '"has,comma"', "a field containing the separator is quoted")
    H.contains(quoted, '"has""quote"', "an embedded quote is doubled")

    H.eq(render.csv({ "a" }, { { "1" } }, "\t"), "a\n1", "custom separator honored")
  end

  -- lines --------------------------------------------------------------------
  do
    H.eq(render.lines({ { "a", "b" }, { "c", "d" } }, "-"), "a-b\nc-d", "lines joins cells and rows")
    H.eq(render.lines({}), "", "no rows renders as empty string")
  end
end
