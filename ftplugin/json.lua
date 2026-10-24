-- JSON: setup when a json buffer opens.
require('tools').parsers({ 'json' })
require('conform').formatters_by_ft.json = { 'biome', 'prettier', stop_after_first = true } -- Biome if configured, else Prettier
