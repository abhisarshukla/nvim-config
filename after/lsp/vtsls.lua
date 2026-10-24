-- Overrides merged on top of nvim-lspconfig's lsp/vtsls.lua: turn on inlay hints.
local hints = {
  parameterNames = { enabled = 'literals' },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}
return {
  settings = {
    typescript = { inlayHints = hints },
    javascript = { inlayHints = hints },
  },
}
