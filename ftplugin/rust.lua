-- Rust: setup when a Rust buffer opens.
vim.lsp.enable('rust_analyzer')
require('tools').ensure({ 'rust-analyzer' }) -- rustfmt comes from rustup
require('tools').parsers({ 'rust' })
require('conform').formatters_by_ft.rust = { 'rustfmt' }
