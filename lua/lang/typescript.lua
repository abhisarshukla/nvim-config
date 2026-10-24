-- TypeScript / JavaScript: shared by ftplugin/{typescript,typescriptreact,
-- javascript,javascriptreact}.lua. Runs once per session (require caches it).
-- Server settings: after/lsp/vtsls.lua.
vim.lsp.enable('vtsls')
require('tools').ensure({ 'vtsls' })
require('tools').parsers({ 'javascript', 'typescript', 'tsx' })

local web = { 'biome', 'prettier', stop_after_first = true } -- Biome if configured, else Prettier
local by_ft = require('conform').formatters_by_ft
for _, ft in ipairs({ 'javascript', 'javascriptreact', 'typescript', 'typescriptreact' }) do
  by_ft[ft] = web
end
