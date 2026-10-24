-- Python: setup when a Python buffer opens.
vim.lsp.enable({ 'ty', 'ruff' }) -- ty: types/hover/go-to; ruff: lint + fixes
require('tools').ensure({ 'ty', 'ruff' })
require('tools').parsers({ 'python' })
require('conform').formatters_by_ft.python = { 'ruff_format' }
