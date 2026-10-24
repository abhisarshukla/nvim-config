-- mason.nvim installs language servers and formatters into nvim's data folder
-- and puts them on nvim's PATH. :Mason opens its UI.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('mason-org/mason.nvim'), version = vim.version.range('2.*') },
})

require('mason').setup()

-- Each language's tools are installed on demand by its ftplugin/<ft>.lua
-- (via require('tools').ensure). prettier and biome come from each project's
-- node_modules instead.
