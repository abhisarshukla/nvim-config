-- Go: setup when a Go buffer opens. Options: after/ftplugin/go.lua.
-- Server settings: after/lsp/gopls.lua.
vim.lsp.enable('gopls')
require('tools').ensure({ 'gopls', 'goimports' })
require('tools').parsers({ 'go', 'gomod', 'gosum' })
require('conform').formatters_by_ft.go = { 'goimports' } -- gofmt + fixes imports
