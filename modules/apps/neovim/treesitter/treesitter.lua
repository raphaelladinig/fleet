local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

local function move(direction, query, group)
  return function()
    require("nvim-treesitter-textobjects.move")[direction](query, group)
  end
end

-- The textobjects move functions error in a buffer without a parser, so these
-- maps are set per buffer once a parser starts. Other buffers keep Vim's
-- builtin `]s`, `]]`, `;`, `,` and the rest.
local motion_maps = {
  ["]m"] = move("goto_next_start", "@function.outer", "textobjects"),
  ["]]"] = move("goto_next_start", "@class.outer", "textobjects"),
  ["]o"] = move("goto_next_start", { "@loop.inner", "@loop.outer" }, "textobjects"),
  ["]s"] = move("goto_next_start", "@local.scope", "locals"),
  ["]z"] = move("goto_next_start", "@fold", "folds"),
  ["]M"] = move("goto_next_end", "@function.outer", "textobjects"),
  ["]["] = move("goto_next_end", "@class.outer", "textobjects"),
  ["[m"] = move("goto_previous_start", "@function.outer", "textobjects"),
  ["[["] = move("goto_previous_start", "@class.outer", "textobjects"),
  ["[M"] = move("goto_previous_end", "@function.outer", "textobjects"),
  ["[]"] = move("goto_previous_end", "@class.outer", "textobjects"),
  ["]C"] = move("goto_next", "@conditional.outer", "textobjects"),
  ["[C"] = move("goto_previous", "@conditional.outer", "textobjects"),
  [";"] = ts_repeat_move.repeat_last_move_next,
  [","] = ts_repeat_move.repeat_last_move_previous,
}

local function enable_treesitter()
  local parser_available = pcall(vim.treesitter.start)
  if not parser_available then
    return
  end

  vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
  vim.wo[0][0].foldmethod = "expr"

  for lhs, rhs in pairs(motion_maps) do
    vim.keymap.set({ "n", "x", "o" }, lhs, rhs, { buffer = true })
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = enable_treesitter,
})

require("nvim-ts-autotag").setup()

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v",
      ["@function.outer"] = "V",
      ["@class.outer"] = "<c-v>",
    },
    include_surrounding_whitespace = false,
  },
  move = {
    set_jumps = true,
  },
})

vim.keymap.set({ "x", "o" }, "am", function()
  require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "im", function()
  require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "ac", function()
  require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "ic", function()
  require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects")
end)
vim.keymap.set({ "x", "o" }, "as", function()
  require("nvim-treesitter-textobjects.select").select_textobject("@local.scope", "locals")
end)

vim.keymap.set("n", "<leader>a", function()
  require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
end)
vim.keymap.set("n", "<leader>A", function()
  require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
end)

vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })

require("treesitter-context").setup({
  enable = true,
  multiwindow = false,
  max_lines = 5,
  min_window_height = 0,
  line_numbers = true,
  multiline_threshold = 20,
  trim_scope = "outer",
  mode = "cursor",
  separator = nil,
  zindex = 20,
  on_attach = nil,
})

vim.keymap.set("n", "[k", function()
  require("treesitter-context").go_to_context(vim.v.count1)
end, { silent = true })
