-- Test code: when something here comes back nil this file must crash and
-- name it, not silently pass.
---@diagnostic disable: need-check-nil, duplicate-set-field
--
-- The stdlib and module fields replaced below are test doubles: each one is
-- swapped for the length of a single case and restored right after.
-- TESTS/handlers_spec.lua — the handlers with no coverage yet: default,
-- browser, notepad, nvim_internal, image. `terminal` and `filemanager` are
-- already covered in features_spec.lua.

return function(H)
  ---@param mod table
  local function register(mod)
    local registered = {}
    mod.register_all(function(h)
      registered[h.key] = h
      return true
    end)
    return registered
  end

  -- open.handlers.default -------------------------------------------------------
  do
    local handlers = register(require("open.handlers.default"))
    local mod_name = "lib.nvim.cross.open_default"
    local orig = package.loaded[mod_name]
    local seen

    package.loaded[mod_name] = function(target)
      seen = target
      return true
    end
    H.ok(
      handlers.default.run({ text = "/some/file" }),
      "default handler succeeds when open_default succeeds"
    )
    H.eq(seen, "/some/file", "default handler passes the context text through unchanged")

    package.loaded[mod_name] = function()
      return false, "no association"
    end
    H.falsy(
      handlers.default.run({ text = "/x" }),
      "default handler reports failure from open_default"
    )

    package.loaded[mod_name] = orig
  end

  -- open.handlers.image: falls back to open_default without images.nvim -----
  do
    local handlers = register(require("open.handlers.image"))
    local mod_name = "lib.nvim.cross.open_default"
    local orig = package.loaded[mod_name]
    local orig_images = package.loaded["images"]
    package.loaded["images"] = nil -- ensure absent for this case

    local seen
    package.loaded[mod_name] = function(target)
      seen = target
      return true
    end
    H.ok(handlers.image.run({ text = "/pic.png" }), "image handler falls back to open_default")
    H.eq(seen, "/pic.png", "the fallback receives the same target")

    package.loaded[mod_name] = orig
    package.loaded["images"] = orig_images
  end

  -- open.handlers.image: prefers images.nvim when it is present --------------
  do
    local handlers = register(require("open.handlers.image"))
    local orig_images = package.loaded["images"]
    local shown_with
    package.loaded["images"] = {
      show = function(target)
        shown_with = target
        return true
      end,
    }

    local mod_name = "lib.nvim.cross.open_default"
    local orig = package.loaded[mod_name]
    local fallback_called = false
    package.loaded[mod_name] = function()
      fallback_called = true
      return true
    end

    H.ok(handlers.image.run({ text = "/pic.png" }), "image handler succeeds via images.nvim")
    H.eq(shown_with, "/pic.png", "images.show() received the target")
    H.falsy(fallback_called, "open_default is not reached when images.nvim handled it")

    package.loaded["images"] = orig_images
    package.loaded[mod_name] = orig
  end

  -- open.handlers.browser --------------------------------------------------------
  do
    local handlers = register(require("open.handlers.browser"))
    local platform = require("open.platform")
    local util = require("open.util")
    local orig_get = platform.get
    local orig_run_detached = util.run_detached
    local orig_exe = vim.fn.executable

    local seen_cmd
    util.run_detached = function(cmd)
      seen_cmd = cmd
      return true
    end

    -- to_url(): a plain query becomes a Google search ------------------------
    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = false, is_linux = true }
    end
    handlers.browser.run({ text = "hello world", is_url = false, is_path = false })
    H.contains(
      seen_cmd[#seen_cmd],
      "google.com/search",
      "plain text is turned into a Google search"
    )
    H.contains(seen_cmd[#seen_cmd], "hello+world", "the query text is URL-encoded")

    -- to_url(): a www-only target gains a scheme ------------------------------
    handlers.browser.run({ text = "www.example.com", is_url = true, is_path = false })
    H.eq(seen_cmd[#seen_cmd], "https://www.example.com", "www target gains https://")

    -- to_url(): a local path target uses file:// ------------------------------
    handlers.browser.run({ text = "/tmp/doc.html", is_url = false, is_path = true })
    H.contains(seen_cmd[#seen_cmd], "file://", "a path context is opened via file://")

    -- to_url(): the is_path branch never runs vim.fn.expand() on context
    -- text -- a backtick span there must not risk a &shell command
    -- substitution (SEC-34) ---------------------------------------------------
    do
      local payload = "`echo sec34`"
      local orig_expand = vim.fn.expand
      local seen_candidate = false
      vim.fn.expand = function(x, ...)
        if x == payload then seen_candidate = true end
        return orig_expand(x, ...)
      end

      handlers.browser.run({ text = payload, is_url = false, is_path = true })

      vim.fn.expand = orig_expand
      H.falsy(seen_candidate, "vim.fn.expand() is never called with the raw context text")
    end

    -- default_browser_cmd(): platform dispatch --------------------------------
    platform.get = function()
      return { is_win = true, is_wsl = false, is_mac = false, is_linux = false }
    end
    handlers.browser.run({ text = "https://x.dev", is_url = true, is_path = false })
    H.eq(seen_cmd[1], "explorer.exe", "Windows dispatches the default browser via explorer.exe")

    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = true, is_linux = false }
    end
    handlers.browser.run({ text = "https://x.dev", is_url = true, is_path = false })
    H.eq(seen_cmd[1], "open", "macOS dispatches the default browser via open")

    vim.fn.executable = function()
      return 0
    end
    platform.get = function()
      return { is_win = false, is_wsl = true, is_mac = false, is_linux = true }
    end
    handlers.browser.run({ text = "https://x.dev&y=1", is_url = true, is_path = false })
    H.eq(seen_cmd[1], "cmd.exe", "WSL with no wslview/explorer falls back to cmd.exe /C start")
    H.contains(
      table.concat(seen_cmd, " "),
      "^&",
      "the URL's & is shielded from cmd.exe's tokenizer"
    )

    -- named_browser_cmd(): a specific browser on Linux ------------------------
    vim.fn.executable = function(name)
      return name == "firefox" and 1 or 0
    end
    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = false, is_linux = true }
    end
    H.ok(handlers.firefox.run({ text = "https://x.dev", is_url = true, is_path = false }))
    H.eq(seen_cmd[1], "firefox", "the firefox handler finds firefox on PATH")

    -- named_browser_cmd(): none of the candidates found on PATH ---------------
    vim.fn.executable = function()
      return 0
    end
    local orig_notify = vim.notify
    local warned
    vim.notify = function(msg)
      warned = msg
    end
    H.falsy(
      handlers.opera.run({ text = "https://x.dev", is_url = true, is_path = false }),
      "no candidate on PATH is a reported failure, not a crash"
    )
    H.contains(warned, "opera", "the failure names the handler that could not launch")
    vim.notify = orig_notify

    -- safari: refuses off macOS -------------------------------------------------
    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = false, is_linux = true }
    end
    H.falsy(
      handlers.safari.run({ text = "https://x.dev", is_url = true, is_path = false }),
      "safari refuses off macOS"
    )

    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = true, is_linux = false }
    end
    H.ok(
      handlers.safari.run({ text = "https://x.dev", is_url = true, is_path = false }),
      "safari runs on macOS"
    )
    H.eq(seen_cmd[1], "open", "safari on macOS is launched via `open -a Safari`")
    H.eq(seen_cmd[2], "-a", "the -a flag selects the named app")
    H.eq(seen_cmd[3], "Safari", "Safari is the selected app")

    platform.get = orig_get
    util.run_detached = orig_run_detached
    vim.fn.executable = orig_exe
  end

  -- open.handlers.notepad ---------------------------------------------------------
  do
    local handlers = register(require("open.handlers.notepad"))
    local platform = require("open.platform")
    local util = require("open.util")
    local orig_get = platform.get
    local orig_run_detached = util.run_detached
    local orig_exe = vim.fn.executable

    local seen_cmd
    util.run_detached = function(cmd)
      seen_cmd = cmd
      return true
    end

    platform.get = function()
      return { is_win = true, is_wsl = false, is_mac = false, is_linux = false }
    end
    H.ok(handlers.notepad.run({ text = "hello" }), "notepad handler succeeds on Windows")
    H.eq(seen_cmd[1], "notepad.exe", "Windows opens the temp file with notepad.exe")
    H.ok(
      vim.uv.fs_stat(seen_cmd[2]) ~= nil,
      "the temp file notepad.exe is pointed at really exists"
    )
    vim.fn.delete(seen_cmd[2])
    H.ok(handlers.editor, "editor is registered as its own handler")
    H.ok(handlers.editor.run({ text = "hi" }), "the editor alias shares notepad's run()")
    vim.fn.delete(seen_cmd[2])

    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = true, is_linux = false }
    end
    handlers.notepad.run({ text = "hello" })
    H.eq(seen_cmd[1], "open", "macOS opens the temp file via `open -e`")
    H.eq(seen_cmd[2], "-e", "the -e flag opens in TextEdit")
    vim.fn.delete(seen_cmd[3])

    -- Linux: no GUI editor on PATH is a reported failure, not a crash --------
    platform.get = function()
      return { is_win = false, is_wsl = false, is_mac = false, is_linux = true }
    end
    vim.fn.executable = function()
      return 0
    end
    H.falsy(handlers.notepad.run({ text = "hello" }), "no Linux GUI editor on PATH fails cleanly")

    vim.fn.executable = function(name)
      return name == "gedit" and 1 or 0
    end
    handlers.notepad.run({ text = "hello" })
    H.eq(seen_cmd[1], "gedit", "the first available Linux GUI editor is chosen")
    vim.fn.delete(seen_cmd[2])

    platform.get = orig_get
    util.run_detached = orig_run_detached
    vim.fn.executable = orig_exe
  end

  -- open.handlers.notepad: WSL converts the temp path via wslpath -------------
  do
    local handlers = register(require("open.handlers.notepad"))
    local platform = require("open.platform")
    local util = require("open.util")
    local orig_get = platform.get
    local orig_run_detached = util.run_detached
    local wslpath = require("lib.nvim.cross.fs.wslpath")
    local orig_to_win = wslpath.to_win

    local seen_cmd
    util.run_detached = function(cmd)
      seen_cmd = cmd
      return true
    end
    platform.get = function()
      return { is_win = false, is_wsl = true, is_mac = false, is_linux = true }
    end
    wslpath.to_win = function(p)
      return "C:\\wsl\\" .. vim.fn.fnamemodify(p, ":t")
    end

    H.ok(
      handlers.notepad.run({ text = "hello" }),
      "WSL notepad handler succeeds with a converted path"
    )
    H.eq(seen_cmd[1], "notepad.exe", "WSL still launches notepad.exe")
    H.contains(seen_cmd[2], "C:\\wsl\\", "the temp path was converted via wslpath before launch")

    wslpath.to_win = function()
      return nil
    end
    H.falsy(
      handlers.notepad.run({ text = "hello" }),
      "a failed wslpath conversion is a reported failure"
    )

    wslpath.to_win = orig_to_win
    platform.get = orig_get
    util.run_detached = orig_run_detached
  end

  -- open.handlers.nvim_internal: split / vsplit / tab -----------------------------
  H.tmpdir(function(dir)
    local handlers = register(require("open.handlers.nvim_internal"))
    local file = dir .. "/doc.md"
    H.write(file, "# hi\n")

    H.ok(
      handlers.split.run({ text = file, is_url = false }),
      "split handler opens an existing file"
    )
    H.eq(vim.fn.expand("%:t"), "doc.md", "the split's buffer is the target file")
    vim.cmd("close")

    H.falsy(
      handlers.vsplit.run({ text = "https://example.com", is_url = true }),
      "a URL context is rejected by the Neovim-internal handlers"
    )

    H.falsy(
      handlers.tab.run({ text = dir .. "/ghost.md", is_url = false }),
      "a nonexistent path is rejected, not silently opened as [No Name]"
    )
  end)
end
