-- go.mod: gopls understands it too.
vim.lsp.enable('gopls')
require('tools').ensure({ 'gopls' })
require('tools').parsers({ 'gomod' })
