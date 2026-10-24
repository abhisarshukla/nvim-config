-- snacks.nvim is a toolkit of modules, all off unless enabled here.
-- Using: picker (fuzzy search with live preview) and words (highlights other
-- uses of the symbol under the cursor, via LSP).
-- LSP results (gd, grr, gri, grt, gO) open in the picker too: see lua/plugins/lsp.lua.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('folke/snacks.nvim'), version = vim.version.range('2.*') },
})

local snacks = require('snacks')
snacks.setup({
  picker = { enabled = true },
  words = { enabled = true },
})

local picker = snacks.picker
local map = vim.keymap.set

-- Files
map('n', '<leader>ff', function() picker.files() end, { desc = 'Find files' })
map('n', '<leader>fb', function() picker.buffers() end, { desc = 'Find open buffers' })
map('n', '<leader>fr', function() picker.recent() end, { desc = 'Find recent files' })

-- Search
map('n', '<leader>sg', function() picker.grep() end, { desc = 'Grep project' })
map({ 'n', 'x' }, '<leader>sw', function() picker.grep_word() end, { desc = 'Grep word / selection' })
map('n', '<leader>sd', function() picker.diagnostics() end, { desc = 'Search diagnostics' })
map('n', '<leader>sh', function() picker.help() end, { desc = 'Search help' })
map('n', '<leader>sk', function() picker.keymaps() end, { desc = 'Search keymaps' })
map('n', '<leader>sr', function() picker.resume() end, { desc = 'Resume last search' })

-- Jump between uses of the symbol under the cursor (]] [[ are taken by classes).
map('n', ']r', function() snacks.words.jump(vim.v.count1) end, { desc = 'Next reference' })
map('n', '[r', function() snacks.words.jump(-vim.v.count1) end, { desc = 'Previous reference' })
