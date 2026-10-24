-- Markdown: setup when a Markdown buffer opens. Options: after/ftplugin/markdown.lua.
-- Parser: built into Neovim's list.
require('conform').formatters_by_ft.markdown = { 'prettier' } -- if the project configures Prettier
