-- Completion menu: blink.cmp, fed by the language server, file paths,
-- snippets and words from open buffers.
-- Snippets come from three places: the language server, friendly-snippets,
-- and your own in snippets/ (VS Code format; see snippets/package.json).
local gh = require('pack').gh

vim.pack.add({
  gh('rafamadriz/friendly-snippets'), -- no releases
  -- Release tags ship a prebuilt fuzzy matcher, so there's no Rust build step.
  { src = gh('saghen/blink.cmp'), version = vim.version.range('1.*') },
})

-- In prose the menu only opens on <C-Space>.
local prose = { markdown = true, text = true, gitcommit = true }

require('blink.cmp').setup({
  -- 'default' preset: <C-y> accept, <C-n>/<C-p> move, <C-e> close,
  -- <C-Space> open menu / toggle docs, <C-b>/<C-f> scroll docs,
  -- <Tab>/<S-Tab> jump between snippet fields.
  keymap = {
    preset = 'default',
    ['<C-k>'] = false, -- keep Vim's digraphs; signature help is the built-in <C-s>
  },
  completion = {
    menu = { auto_show = function() return not prose[vim.bo.filetype] end },
  },
  signature = { enabled = false }, -- on demand with <C-s> instead
  cmdline = { enabled = false }, -- keep Neovim's own : command-line completion
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
})
