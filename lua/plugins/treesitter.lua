-- Treesitter parses code into a syntax tree. Neovim itself does the
-- highlighting and folding; nvim-treesitter installs parsers and adds indent.
local gh = require('pack').gh

vim.pack.add({
  gh('nvim-treesitter/nvim-treesitter'), -- main branch (no releases)
  gh('nvim-treesitter/nvim-treesitter-textobjects'), -- main branch (no releases)
  { src = gh('nvim-treesitter/nvim-treesitter-context'), version = vim.version.range('1.*') },
})

-- Parsers for Neovim's own languages (kept in sync with nvim-treesitter's
-- queries). Each language's parser is installed by its ftplugin/<ft>.lua.
-- :TSUpdate after plugin updates is handled by the hook in lua/pack.lua.
require('tools').parsers({ 'lua', 'vim', 'vimdoc', 'query', 'markdown', 'markdown_inline' })

-- Turn treesitter on for any buffer whose language has a parser.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('treesitter', { clear = true }),
  callback = function(ev)
    if not pcall(vim.treesitter.start, ev.buf) then return end -- no parser
    vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    vim.wo[0][0].foldmethod = 'expr'
    vim.wo[0][0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
  end,
})

-- Text objects and motions for code structure -------------------------------

require('nvim-treesitter-textobjects').setup({
  select = { lookahead = true }, -- `vaf` before a function jumps forward to it
  move = { set_jumps = true }, -- motions below add to the jumplist (<C-o> returns)
})

local select = require('nvim-treesitter-textobjects.select')
local function obj(keys, query, desc)
  vim.keymap.set({ 'x', 'o' }, keys, function() select.select_textobject(query, 'textobjects') end, { desc = desc })
end
obj('af', '@function.outer', 'around function')
obj('if', '@function.inner', 'inside function')
obj('ac', '@class.outer', 'around class')
obj('ic', '@class.inner', 'inside class')
obj('aa', '@parameter.outer', 'around argument')
obj('ia', '@parameter.inner', 'inside argument')

-- Same keys Vim uses for methods (]m) and sections (]]), but syntax-aware.
local move = require('nvim-treesitter-textobjects.move')
local function mv(keys, fn, query, desc)
  vim.keymap.set({ 'n', 'x', 'o' }, keys, function() move[fn](query, 'textobjects') end, { desc = desc })
end
mv(']m', 'goto_next_start', '@function.outer', 'next function start')
mv('[m', 'goto_previous_start', '@function.outer', 'previous function start')
mv(']M', 'goto_next_end', '@function.outer', 'next function end')
mv('[M', 'goto_previous_end', '@function.outer', 'previous function end')
mv(']]', 'goto_next_start', '@class.outer', 'next class start')
mv('[[', 'goto_previous_start', '@class.outer', 'previous class start')

-- Pin the enclosing function/class signature at the top while scrolling its body.
require('treesitter-context').setup({ max_lines = 3 })
