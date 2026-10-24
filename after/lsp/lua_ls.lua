-- Overrides merged on top of nvim-lspconfig's lsp/lua_ls.lua.
return {
  on_init = function(client)
    -- Teach lua_ls about Neovim's API and installed plugins, but only for this config.
    if client.root_dir ~= vim.fn.stdpath('config') then return end
    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua or {}, {
      runtime = { version = 'LuaJIT' },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME, vim.fn.stdpath('data') .. '/site/pack/core/opt' },
      },
    })
  end,
  settings = { Lua = { hint = { enable = true } } },
}
