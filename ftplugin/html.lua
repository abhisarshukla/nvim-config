-- HTML: setup when a html buffer opens.
require('tools').parsers({ 'html' })
require('conform').formatters_by_ft.html = { 'prettier' } -- if the project configures Prettier
