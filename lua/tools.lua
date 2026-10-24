-- Helpers for ftplugin/ files: make sure a language's tools exist.
-- ftplugins run for every buffer of their filetype, so each helper only does
-- work the first time it sees a name in a session.
local M = {}

local seen_pkgs, seen_parsers = {}, {}

local function first_time(list, seen)
  local out = {}
  for _, x in ipairs(list) do
    if not seen[x] then
      seen[x] = true
      table.insert(out, x)
    end
  end
  return out
end

-- Install missing mason packages in the background. When a language server
-- finishes installing, it attaches to the buffers that are already open.
function M.ensure(names)
  local todo = first_time(names, seen_pkgs)
  if #todo == 0 then return end
  local registry = require('mason-registry')
  registry.refresh(function()
    for _, name in ipairs(todo) do
      local ok, pkg = pcall(registry.get_package, name)
      if not ok then
        vim.notify('mason: unknown package ' .. name, vim.log.levels.WARN)
      elseif not pkg:is_installed() and not pkg:is_installing() then
        vim.notify('mason: installing ' .. name)
        pkg:install({}, function(success)
          vim.schedule(function()
            if not success then return vim.notify('mason: failed to install ' .. name, vim.log.levels.ERROR) end
            vim.notify('mason: installed ' .. name)
            pcall(vim.cmd.doautoall, 'nvim.lsp.enable FileType') -- attach servers now
          end)
        end)
      end
    end
  end)
end

-- Install missing treesitter parsers in the background; once ready, turn on
-- highlighting in buffers that were opened before the parser existed.
function M.parsers(langs)
  local todo = first_time(langs, seen_parsers)
  if #todo == 0 then return end
  local ts = require('nvim-treesitter')
  local installed = ts.get_installed()
  local missing = vim.tbl_filter(function(l) return not vim.tbl_contains(installed, l) end, todo)
  if #missing == 0 then return end
  ts.install(missing):await(function()
    vim.schedule(function() pcall(vim.cmd.doautoall, 'treesitter FileType') end)
  end)
end

return M
