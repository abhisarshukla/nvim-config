-- Language servers. Neovim has the LSP client built in; nvim-lspconfig only
-- supplies ready-made server configs (its lsp/*.lua files). Your per-server
-- overrides live in after/lsp/<name>.lua. Binaries come from mason.
--
-- Keys (results open in the snacks picker, set below): gd definition,
-- grr references, gri implementations, grt type definition, gO symbols.
-- Built-in: K hover, grn rename, gra code action, <C-s> signature (insert),
-- ]d/[d next/prev diagnostic, <C-w>d diagnostic float, <C-]> definition.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('neovim/nvim-lspconfig'), version = vim.version.range('2.*') },
})

vim.lsp.enable({
  'lua_ls',
  'ty', -- Python types, hover, go-to
  'ruff', -- Python lint + fixes
  'vtsls', -- TypeScript / JavaScript
  'gopls',
  'rust_analyzer',
})

-- Per-buffer setup when a server attaches.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('lsp_attach', { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then return end
    if client.name == 'ruff' then client.server_capabilities.hoverProvider = false end

    -- Same keys as Neovim's defaults, but results open in the snacks picker.
    local picker = require('snacks').picker
    local function map(keys, fn, desc) vim.keymap.set('n', keys, fn, { buffer = ev.buf, desc = desc }) end
    map('gd', function() picker.lsp_definitions() end, 'Definition')
    map('grr', function() picker.lsp_references() end, 'References')
    map('gri', function() picker.lsp_implementations() end, 'Implementations')
    map('grt', function() picker.lsp_type_definitions() end, 'Type definition')
    map('gO', function() picker.lsp_symbols() end, 'Document symbols')
  end,
})

-- Inline types and parameter names; <leader>th toggles (lua/keymaps.lua).
vim.lsp.inlay_hint.enable(true)

-- Diagnostics: full message under the cursor line only; elsewhere sign + underline.
vim.diagnostic.config({
  virtual_lines = { current_line = true },
  virtual_text = false,
  severity_sort = true,
})
