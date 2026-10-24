-- Prose: soft-wrap at word boundaries, keeping list indentation.
-- opt_local (like :setlocal) so wrap doesn't leak into code opened in this window.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
