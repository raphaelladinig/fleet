return {
  filetypes = { "rust" },
  setup = function()
    if require("my.features").lsp then
      vim.lsp.enable("rust_analyzer")
    end

    if require("my.features").formatting then
      require("conform").formatters_by_ft.rust = { "rustfmt" }
    end
  end,
}
