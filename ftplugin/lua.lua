-- Lua: setup when a Lua buffer opens. Options: after/ftplugin/lua.lua.
-- Server settings: after/lsp/lua_ls.lua. Parser: built into Neovim's list.
vim.lsp.enable('lua_ls')
require('tools').ensure({ 'lua-language-server', 'stylua' })
require('conform').formatters_by_ft.lua = { 'stylua' }
