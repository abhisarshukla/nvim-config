-- Format on save, but only where the project opts in with formatter config.
-- Go and Rust always format: gofmt/rustfmt style is universal in those languages.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('stevearc/conform.nvim'), version = vim.version.range('9.*') },
})

-- Condition: one of `names` exists in this file's directory or any parent.
local function project_has(names)
  return function(_, ctx) return vim.fs.root(ctx.dirname, names) ~= nil end
end

local function project_uses_ruff(_, ctx)
  if vim.fs.root(ctx.dirname, { 'ruff.toml', '.ruff.toml' }) then return true end
  local pyproject = vim.fs.find('pyproject.toml', { path = ctx.dirname, upward = true })[1]
  if not pyproject then return false end
  return vim.iter(vim.fn.readfile(pyproject)):any(function(l) return l:match('^%[tool%.ruff') ~= nil end)
end

-- JS/TS-family files: Biome if configured, else Prettier if configured.
local web = { 'biome', 'prettier', stop_after_first = true }

require('conform').setup({
  formatters_by_ft = {
    lua = { 'stylua' },
    python = { 'ruff_format' },
    go = { 'goimports' }, -- gofmt + adds/removes imports
    rust = { 'rustfmt' },
    javascript = web,
    javascriptreact = web,
    typescript = web,
    typescriptreact = web,
    json = web,
    jsonc = web,
    css = web,
    html = { 'prettier' },
    yaml = { 'prettier' },
    markdown = { 'prettier' },
  },
  formatters = {
    stylua = { condition = project_has({ 'stylua.toml', '.stylua.toml' }) },
    ruff_format = { condition = project_uses_ruff },
    biome = { condition = project_has({ 'biome.json', 'biome.jsonc' }) },
    -- stylua: ignore
    prettier = {
      condition = project_has({
        '.prettierrc', '.prettierrc.json', '.prettierrc.yaml', '.prettierrc.yml', '.prettierrc.toml',
        '.prettierrc.js', '.prettierrc.cjs', '.prettierrc.mjs',
        'prettier.config.js', 'prettier.config.cjs', 'prettier.config.mjs', 'prettier.config.ts',
      }),
    },
  },
  -- Never fall back to the language server's formatter; only the tools above.
  format_on_save = { timeout_ms = 1000, lsp_format = 'never' },
})
