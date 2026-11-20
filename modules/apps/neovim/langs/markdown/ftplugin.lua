vim.b.prose_wrap = true
vim.wo[0][0].wrap = true
vim.wo[0][0].linebreak = true
vim.wo[0][0].spell = true
vim.bo.spelllang = require("my.features").spell and "en,de" or "en"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "")
  .. "unlet! b:prose_wrap | setlocal wrap< linebreak< spell< spelllang<"
