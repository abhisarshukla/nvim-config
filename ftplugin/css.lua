-- CSS: setup when a css buffer opens.
require('tools').parsers({ 'css' })
require('conform').formatters_by_ft.css = { 'biome', 'prettier', stop_after_first = true } -- Biome if configured, else Prettier
