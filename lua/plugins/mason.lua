-- mason.nvim installs language servers and formatters into nvim's data folder
-- and puts them on nvim's PATH. :Mason opens its UI.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('mason-org/mason.nvim'), version = vim.version.range('2.*') },
})

require('mason').setup()

-- Tools to always have. Missing ones install in the background at startup.
-- (prettier and biome are not here: they come from each project's node_modules.)
-- stylua: ignore
local tools = {
  'lua-language-server', 'stylua',
  'ty', 'ruff',
  'vtsls',
  'gopls', 'goimports',
  'rust-analyzer', -- rustfmt comes from rustup
}

local registry = require('mason-registry')
registry.refresh(function()
  for _, name in ipairs(tools) do
    local pkg = registry.get_package(name)
    if not pkg:is_installed() then pkg:install() end
  end
end)
