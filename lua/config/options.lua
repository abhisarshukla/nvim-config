-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

if vim.fn.has("windows") then
  vim.opt.shell = "bash.exe"
end

if vim.g.neovide then
  vim.g.neovide_fullscreen = true
  vim.g.neovide_remember_window_size = true
end
