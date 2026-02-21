local mason_lspconfig = require "mason-lspconfig"

mason_lspconfig.setup {
  ensure_installed = {
    "gopls", -- Go LSP
  },
  automatic_installation = true,
}
