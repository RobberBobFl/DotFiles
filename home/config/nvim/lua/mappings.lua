require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jj", "<ESC>")
map("n", "gw", function()
  require("flash").jump()
end, { desc = "Flash jump (Helix-like)" })
