-- Look and feel: colorscheme, file-type icons, key hints.
-- The statusline is hand-written in lua/statusline.lua.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('folke/tokyonight.nvim'), version = vim.version.range('4.*') },
  { src = gh('nvim-mini/mini.nvim'), version = vim.version.range('0.*') },
})

-- Tokyonight: 'moon' when the background is dark, 'day' when it's light.
-- Neovim detects the terminal's background on its own.
require('tokyonight').setup({})
vim.cmd.colorscheme('tokyonight')

-- Icons (needs a Nerd Font). snacks and oil pick these up automatically.
require('mini.icons').setup()

-- Key hints: press a prefix (<leader>, g, [, ], z, <C-w>, ", ') and pause.
local clue = require('mini.clue')
clue.setup({
  triggers = {
    { mode = 'n', keys = '<Leader>' },
    { mode = 'x', keys = '<Leader>' },
    { mode = 'n', keys = 'g' },
    { mode = 'x', keys = 'g' },
    { mode = 'n', keys = '[' },
    { mode = 'n', keys = ']' },
    { mode = 'n', keys = 'z' },
    { mode = 'x', keys = 'z' },
    { mode = 'n', keys = '<C-w>' },
    { mode = 'n', keys = '"' },
    { mode = 'x', keys = '"' },
    { mode = 'i', keys = '<C-r>' },
    { mode = 'n', keys = "'" },
    { mode = 'n', keys = '`' },
  },
  clues = {
    -- Names for your <leader> groups
    { mode = 'n', keys = '<Leader>f', desc = '+find' },
    { mode = 'n', keys = '<Leader>g', desc = '+git' },
    { mode = 'n', keys = '<Leader>s', desc = '+search' },
    { mode = 'n', keys = '<Leader>r', desc = '+rex' },
    { mode = 'n', keys = '<Leader>t', desc = '+toggle' },
    -- Descriptions for Vim's built-in keys
    clue.gen_clues.g(),
    clue.gen_clues.z(),
    clue.gen_clues.windows(),
    clue.gen_clues.registers(),
    clue.gen_clues.marks(),
    clue.gen_clues.square_brackets(),
  },
  window = { delay = 500 },
})
