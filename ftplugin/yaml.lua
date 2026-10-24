-- YAML: setup when a yaml buffer opens.
require('tools').parsers({ 'yaml' })
require('conform').formatters_by_ft.yaml = { 'prettier' } -- if the project configures Prettier
