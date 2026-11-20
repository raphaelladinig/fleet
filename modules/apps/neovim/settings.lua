vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.no_plugin_maps = true
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0

vim.o.clipboard = "unnamedplus"
vim.o.wrap = false
vim.o.linebreak = false

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("my.wrapping", {}),
  callback = function()
    local prose = vim.b.prose_wrap == true
    vim.wo[0][0].wrap = prose
    vim.wo[0][0].linebreak = prose
  end,
})

vim.o.termguicolors = true
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.number = true
vim.o.relativenumber = true
vim.o.hlsearch = false
vim.o.incsearch = true
vim.o.scrolloff = 10
vim.o.updatetime = 50
vim.o.tabstop = 2
vim.o.expandtab = true
vim.o.shiftwidth = 0
vim.o.mouse = "a"
vim.o.mousemodel = "extend"
vim.o.virtualedit = "block"
vim.o.ignorecase = true
vim.o.signcolumn = "yes"
vim.o.swapfile = false

vim.opt.title = true
vim.opt.shortmess:append("I")
vim.opt.autoread = true
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

vim.diagnostic.config({ virtual_text = true })

-- Trust each project file by content. Directory trust covers only the name, so
-- .nvim stays off the runtimepath. See :h vim.secure.read().
-- Errors are reported instead of raised so a broken project file cannot abort
-- the rest of the config.
local function run_trusted(file, apply)
  local code = vim.secure.read(file)
  if type(code) == "string" then
    local ok, err = pcall(function()
      local result = assert(load(code, "@" .. file))()
      if apply then
        apply(result)
      end
    end)
    if not ok then
      vim.notify(err, vim.log.levels.ERROR)
    end
  end
end

local exrc_root = vim.fs.root(vim.fn.getcwd(), ".nvim")
if exrc_root then
  local exrc_dir = exrc_root .. "/.nvim"
  for name, kind in vim.fs.dir(exrc_dir .. "/lsp") do
    if kind == "file" and name:match("%.lua$") then
      run_trusted(exrc_dir .. "/lsp/" .. name, function(config)
        vim.lsp.config(name:sub(1, -5), config)
      end)
    end
  end
  run_trusted(exrc_dir .. "/init.lua")
end
