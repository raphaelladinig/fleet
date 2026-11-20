vim.wo[0][0].spell = true
-- Commit messages are written in English, so German words count as typos.
vim.bo.spelllang = "en"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | ") or "") .. "setlocal spell< spelllang<"
