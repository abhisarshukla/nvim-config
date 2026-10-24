-- Leader must be set before any mapping that uses it is created.
vim.g.mapleader = ' '

require('options')
require('autocmds')
require('keymaps')

-- Plugins: pack.lua first (hooks must exist before any plugin installs),
-- then each plugin file, listed explicitly so load order is visible.
require('pack')
require('plugins.ui') -- first: colorscheme before other plugins set highlights
require('plugins.mason') -- before LSP: puts tool binaries on PATH
require('plugins.treesitter')
require('plugins.lsp')
require('plugins.fidget')
require('plugins.completion')
require('plugins.format')
require('plugins.snacks')
require('plugins.oil')
require('plugins.git')

-- Run commands in a Rex pane and pull errors back (only inside Rex).
require('rex')

-- Hand-written statusline (shows Rex state, so it comes after rex).
require('statusline')

-- Key lookup table (<leader>sk) and asking Claude about Neovim (<leader>?).
require('keyhelp')
require('ask')
