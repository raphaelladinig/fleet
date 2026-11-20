require("nvim-surround").setup({})

require("nvim-autopairs").setup({})

if require("my.features").treesitter then
  require("nvim-ts-autotag").setup()
end

require("img-clip").setup({
  custom = {
    {
      trigger = function()
        return vim.b.img_clip_template ~= nil
      end,
      template = function()
        return vim.b.img_clip_template
      end,
    },
  },
})
