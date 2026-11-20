return {
  filetypes = { "lua" },
  setup = function()
    if require("my.features").lsp then
      vim.lsp.enable("lua_ls")
    end

    if require("my.features").formatting then
      require("conform").formatters_by_ft.lua = { "stylua" }
    end

    if require("my.features").linting then
      local lint = require("lint")
      local luacheck = lint.linters.luacheck

      -- Luacheck executes .luacheckrc as Lua, so a project config needs the
      -- same trust as exrc. This checks the vim.secure trust database without
      -- prompting and also returns the file's hash.
      local function is_trusted(path)
        local file = io.open(path, "rb")
        local contents = file and file:read("*a")
        if file then
          file:close()
        end
        if not contents then
          return false
        end
        local hash = vim.fn.sha256(contents)
        local trusted = false
        local db = io.open(vim.fn.stdpath("state") .. "/trust", "r")
        if db then
          -- Parse like vim.secure, where the last record for a path wins.
          for line in db:lines() do
            local record, record_path = line:match("^(%S+) (.+)$")
            if record_path == path then
              trusted = record == hash
            end
          end
          db:close()
        end
        return trusted, hash
      end

      -- vim.secure expands $VARS before resolving a path and stores one path
      -- per line. Accept only a regular file that it resolves to the same
      -- newline-free path, so the check, the prompt, and luacheck agree.
      local function resolve(path)
        local real = vim.uv.fs_realpath(path)
        local stat = real and vim.uv.fs_stat(real)
        if
          stat
          and stat.type == "file"
          and not real:find("\n")
          and vim.uv.fs_realpath(vim.fs.normalize(real)) == real
        then
          return real
        end
      end

      local prompted = {}

      -- nvim-lint resolves this factory in the target buffer before spawning.
      lint.linters.luacheck = function()
        local linter = vim.deepcopy(luacheck)
        local file = vim.api.nvim_buf_get_name(0)
        local config = "--no-config"
        if file ~= "" then
          linter.args = vim.list_extend({ "--filename", file }, linter.args)
        end
        if file:match("/%.nvim/") then
          table.insert(linter.args, 1, "--globals=vim")
        else
          local rc = vim.fs.find(".luacheckrc", {
            path = file ~= "" and vim.fs.dirname(file) or nil,
            upward = true,
            type = "file",
          })[1]
          local path = rc and resolve(rc)
          local trusted, hash
          if path then
            trusted, hash = is_trusted(path)
          end
          if trusted then
            linter.cwd = vim.fs.dirname(rc)
            config = "--config=" .. path
          elseif hash and not prompted[hash .. " " .. path] then
            -- Prompt once per file version, after the lint event, so the
            -- prompt cannot block insert mode or switch the linted buffer.
            prompted[hash .. " " .. path] = true
            vim.schedule(function()
              if resolve(path) == path then
                vim.secure.read(path)
              end
            end)
          end
        end
        -- Without a flag, luacheck searches for .luacheckrc upward from the
        -- process working directory.
        table.insert(linter.args, 1, config)
        return linter
      end

      lint.linters_by_ft.lua = { "luacheck" }
    end
  end,
}
