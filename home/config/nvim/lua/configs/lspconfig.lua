require("nvchad.configs.lspconfig").defaults()

local servers = { "html", "cssls" }
local on_attach = require("nvchad.configs.lspconfig").on_attach
local on_init = require("nvchad.configs.lspconfig").on_init
local capabilities = require("nvchad.configs.lspconfig").capabilities
vim.lsp.enable(servers)
-- добавляем gopls в список серверов
local lspconfig = require("nvchad.configs.lspconfig")
lspconfig.servers = {
  "lua_ls",
  "gopls",
}

-- конфигурация gopls
vim.lsp.config("gopls", {
  on_attach = function(client, bufnr)
    -- отключаем встроенное форматирование, если хотим внешние инструменты
    client.server_capabilities.documentFormattingProvider = false
    client.server_capabilities.documentRangeFormattingProvider = false
    on_attach(client, bufnr)
  end,
  on_init = on_init,
  capabilities = capabilities,
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gotmpl", "gowork" },
  root_dir = require("lspconfig.util").root_pattern("go.work", "go.mod", ".git"),
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
      completeUnimported = true,
    },
  },
})
-- read :h vim.lsp.config for changing options of lsp servers 
