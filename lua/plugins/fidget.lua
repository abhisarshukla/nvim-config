-- fidget.nvim: shows what language servers are doing ("indexing",
-- "loading workspace", "checking") in the bottom-right corner; fades when done.
-- Which servers are attached is in the statusline (lua/statusline.lua).
local gh = require('pack').gh

vim.pack.add({
  { src = gh('j-hui/fidget.nvim'), version = vim.version.range('2.*') },
})

require('fidget').setup({})
