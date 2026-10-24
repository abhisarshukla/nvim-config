-- JSONC: setup when a jsonc buffer opens.
require('tools').parsers({ 'json' })
require('conform').formatters_by_ft.jsonc = { 'biome', 'prettier', stop_after_first = true } -- Biome if configured, else Prettier
