-- oil.nvim: a directory is a buffer. Edit the lines (rename, add, delete,
-- move between oil buffers) and :w applies the changes to disk.
-- Replaces netrw, so `nvim .` and :e some/dir/ open oil too.
-- Inside oil: <CR> open, - parent dir, _ cwd, g. toggle hidden files, g? help.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('stevearc/oil.nvim'), version = vim.version.range('2.*') },
})

require('oil').setup()

vim.keymap.set('n', '-', '<Cmd>Oil<CR>', { desc = "Open current file's directory" })
