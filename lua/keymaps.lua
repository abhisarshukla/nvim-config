-- Your own mappings. Built-in LSP and treesitter keys are listed in
-- lua/plugins/lsp.lua and lua/plugins/treesitter.lua.
local map = vim.keymap.set

local function toggle_inlay_hints() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled()) end
map('n', '<leader>th', toggle_inlay_hints, { desc = 'Toggle inlay hints' })
