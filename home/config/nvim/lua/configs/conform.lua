local options = {
  formatters_by_ft = {
    go = { "gofumpt", "goimports-reviser", "golines" },
    lua = { "stylua" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
  formatters = {
    ["goimports-reviser"] = { prepend_args = { "-rm-unused" } },
    golines = { prepend_args = { "--max-len=80" } },
  },
}
require("conform").setup(options)
return options
