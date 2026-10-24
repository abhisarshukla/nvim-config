local o = vim.o

-- Line numbers: absolute on the cursor line, relative everywhere else.
o.number = true
o.relativenumber = true

-- Keyboard only; the terminal keeps text selection.
o.mouse = ''

-- Keep context around the cursor.
o.scrolloff = 8
o.sidescrolloff = 8

-- Code doesn't wrap. Prose filetypes turn it on in after/ftplugin/.
o.wrap = false

-- Undo history survives closing a file; no swap files.
o.undofile = true
o.swapfile = false

-- Fallback indent when there's no .editorconfig and no after/ftplugin/<lang>.lua.
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4

-- Neovim's Python, Rust and Go ftplugins map ]] [[ ]m [m per buffer, which
-- hides the treesitter jumps. Turn those off per language (g:no_plugin_maps
-- would also remove matchit's %).
vim.g.no_python_maps = 1
vim.g.no_rust_maps = 1
vim.g.no_go_maps = 1

-- Search ignores case unless the pattern has a capital letter.
o.ignorecase = true
o.smartcase = true

-- Always show the sign column so text doesn't shift when LSP or git signs appear.
o.signcolumn = 'yes'

-- New splits open to the right and below.
o.splitright = true
o.splitbelow = true

-- Folds come from treesitter (lua/plugins/treesitter.lua); files open unfolded.
o.foldlevelstart = 99
o.foldtext = '' -- show the folded line itself, with syntax colors
