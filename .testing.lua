-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "open",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  isolated = "file",
  -- Guards (docs/GUARDS.md of testing.nvim): every one passes cleanly on this suite, so all run as errors.
  -- The state guard is clean because every spec file runs in its own editor (isolated = "file"); in a
  -- shared editor the specs leave buffers, autocmds and user commands behind.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
  },
  -- What the guards let through on purpose.
  guard_allow = {
    -- features_spec deliberately runs the reveal-in-file-manager security test, which starts
    -- powershell (win_reveal.ps1 -Path "`echo sec34`") to prove the path is never interpreted.
    spawn = { "powershell" },
  },
}
