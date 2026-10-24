-- Hand-written statusline:
--   MODE │  branch │ icon file [+]        󰅚 2 󰀪 1 │ lua_ls │ 󰑮 cargo test │ 12:5
-- Mode colors come from the colorscheme's MiniStatuslineMode* groups.
local M = {}

local modes = {
  n = { 'NORMAL', 'Normal' },
  i = { 'INSERT', 'Insert' },
  v = { 'VISUAL', 'Visual' },
  V = { 'V-LINE', 'Visual' },
  ['\22'] = { 'V-BLOCK', 'Visual' },
  s = { 'SELECT', 'Visual' },
  S = { 'S-LINE', 'Visual' },
  R = { 'REPLACE', 'Replace' },
  c = { 'COMMAND', 'Command' },
  t = { 'TERMINAL', 'Other' },
}

local function mode()
  local m = modes[vim.api.nvim_get_mode().mode:sub(1, 1)] or { 'OTHER', 'Other' }
  return ('%%#MiniStatuslineMode%s# %s %%*'):format(m[2], m[1])
end

local function branch()
  local b = vim.b.git_branch
  return (b and b ~= '') and ('  ' .. b .. ' │') or ''
end

local function file()
  local name = vim.api.nvim_buf_get_name(0)
  local icon = name ~= '' and require('mini.icons').get('file', name) or ''
  return ' ' .. icon .. ' %<%f %h%m%r'
end

local function diagnostics()
  local count = vim.diagnostic.count(0)
  local parts = {}
  local kinds = {
    { vim.diagnostic.severity.ERROR, 'DiagnosticError', '󰅚 ' },
    { vim.diagnostic.severity.WARN, 'DiagnosticWarn', '󰀪 ' },
    { vim.diagnostic.severity.INFO, 'DiagnosticInfo', '󰋽 ' },
    { vim.diagnostic.severity.HINT, 'DiagnosticHint', '󰌶 ' },
  }
  for _, k in ipairs(kinds) do
    if (count[k[1]] or 0) > 0 then table.insert(parts, ('%%#%s#%s%d%%*'):format(k[2], k[3], count[k[1]])) end
  end
  return #parts > 0 and (table.concat(parts, ' ') .. ' │ ') or ''
end

local function lsp()
  local names = vim.iter(vim.lsp.get_clients({ bufnr = 0 })):map(function(c) return c.name end):totable()
  return #names > 0 and (table.concat(names, ' ') .. ' │ ') or ''
end

local function rex()
  local ok, r = pcall(require, 'rex')
  local s = ok and r.status and r.status() or ''
  return s ~= '' and (s .. ' │ ') or ''
end

function M.render()
  -- Inactive windows: just the file.
  -- While %{} is evaluated, the "current" window is the one being drawn;
  -- g:actual_curwin (a string) is the window that really has focus.
  if vim.api.nvim_get_current_win() ~= tonumber(vim.g.actual_curwin) then return file() end
  return table.concat({
    mode(),
    branch(),
    file(),
    '%=',
    diagnostics(),
    lsp(),
    rex(),
    '%l:%v ',
  })
end

vim.o.statusline = "%{%v:lua.require'statusline'.render()%}"
vim.o.showmode = false -- the statusline shows the mode

-- Git branch per buffer, looked up in the background.
local function update_branch(buf)
  if vim.bo[buf].buftype ~= '' then return end
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
  if not dir or not vim.uv.fs_stat(dir) then return end
  vim.system({ 'git', '-C', dir, 'branch', '--show-current' }, { text = true }, function(res)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      vim.b[buf].git_branch = res.code == 0 and vim.trim(res.stdout) or nil
      vim.cmd.redrawstatus()
    end)
  end)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained' }, {
  group = vim.api.nvim_create_augroup('statusline', { clear = true }),
  callback = function(ev) update_branch(ev.buf) end,
})

-- Redraw when diagnostics or attached servers change.
vim.api.nvim_create_autocmd({ 'DiagnosticChanged', 'LspAttach', 'LspDetach' }, {
  group = 'statusline',
  callback = function() vim.cmd.redrawstatus() end,
})

return M
