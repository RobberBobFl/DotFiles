local options = {
  ensure_installed = {
    "bash",
    "lua",
    "go",
    "gomod",
    "gotmpl",
    "gowork",
    "gosum",
  },
  highlight = {
    enable = true,
    use_languagetree = true,
  },
  indent = { enable = true },
}

require("nvim-treesitter.configs").setup(options)
