require "nvchad.options"
vim.keymap.set("n", "x", '"_x', { desc = "Delete char without yank" })
vim.keymap.set("n", "X", '"_X', { desc = "Delete char before cursor without yank" })
vim.keymap.set("n", "dd", '"_dd', { desc = "Delete line without yank" })
vim.keymap.set("v", "d", '"_d', { desc = "Delete selection without yank" })
-- Все delete через black hole
vim.keymap.set({ "n", "v" }, "d", '"_d', { noremap = true })

-- Все change через black hole
vim.keymap.set({ "n", "v" }, "c", '"_c', { noremap = true })

-- s / S тоже
vim.keymap.set("n", "s", '"_s', { noremap = true })
vim.keymap.set("n", "S", '"_S', { noremap = true })
-- Относительные номера + текущая строка абсолютная
vim.opt.relativenumber = true
vim.opt.number = true
-- Относительные номера + текущая строка абсолютная
vim.opt.relativenumber = true
vim.opt.number = true
-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!
