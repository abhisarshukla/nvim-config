-- Run commands in a Rex pane beside nvim and bring the results back, without
-- leaving nvim. Only active when nvim itself runs inside Rex.
--
--   <leader>rc  run a command in the pane (asks; remembered)
--   <leader>rr  re-run the last command
--   <leader>rw  toggle re-run on save
--   <leader>rq  reload results from the pane
--   <leader>rl  open the full output log
--   <leader>rp  choose a different pane
--   :Rex {cmd}  same as <leader>rc; :Rex alone re-runs
--
-- How it works: nvim clears the pane, types the command, then watches the
-- pane's foreground process. When the shell is back in front, the command is
-- done: the whole output goes into a log buffer and the file:line errors go
-- into the quickfix list (]q / [q to walk them).

local M = {}
if not vim.env.REX_SESSION then return M end

local session = vim.env.REX_SESSION
local state = {
  pane = nil, -- Rex block id, picked once per nvim session
  cmd = nil, -- last command
  timer = nil, -- polling timer while a command runs
}

-- Rex CLI ----------------------------------------------------------------------

local function rex(args)
  local res = vim.system(vim.list_extend({ 'rex', '-s', session }, args), { text = true }):wait()
  return res.code == 0 and res.stdout or nil
end

local function rex_json(args)
  local ok, val = pcall(vim.json.decode, rex(vim.list_extend(args, { '--json' })) or '')
  return ok and val or nil
end

-- Process info for a pane: { foreground = { pid, name, cwd } , ... }
local function pane_process(block)
  local ok, val = pcall(vim.json.decode, rex({ 'block', 'call', '-b', block, 'process' }) or '')
  return ok and val or nil
end

local shells = { zsh = true, bash = true, fish = true, sh = true, dash = true, nu = true }
local function at_prompt(proc) return proc and proc.foreground and shells[proc.foreground.name] end

-- Choosing the pane --------------------------------------------------------------

local function pick_pane(on_picked)
  local blocks = (rex_json({ 'block', 'ls' }) or {}).blocks or {}
  local panes = {}
  for _, b in ipairs(blocks) do
    if b.block_id ~= vim.env.REX_BLOCK and (b.flavor or ''):find('terminal') then
      local fg = (pane_process(b.block_id) or {}).foreground or {}
      b.desc = ('%s  %s  [%s]'):format(b.label or '?', vim.fn.fnamemodify(fg.cwd or '?', ':~'), fg.name or '?')
      table.insert(panes, b)
    end
  end
  if #panes == 0 then return vim.notify('Rex: no other pane in this session. Split one first.', vim.log.levels.WARN) end
  vim.ui.select(panes, { prompt = 'Rex pane for commands', format_item = function(b) return b.desc end }, function(b)
    if not b then return end
    state.pane = b.block_id
    on_picked()
  end)
end

local function with_pane(fn)
  if state.pane and pane_process(state.pane) then return fn() end
  state.pane = nil -- gone (closed) or never picked
  pick_pane(fn)
end

-- Results ---------------------------------------------------------------------------

-- Pick Neovim's built-in errorformat (:compiler) from the command's words.
local compilers = { 'cargo', 'go', 'pytest', 'tsc', 'jest', 'ruff', 'mypy', 'eslint' }
local function compiler_for(cmd)
  for _, name in ipairs(compilers) do
    if (' ' .. cmd .. ' '):find('[%s/]' .. name .. '%s') then return name end
  end
end

local function log_buffer()
  local buf = vim.fn.bufnr('rex://output')
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'rex://output')
    vim.bo[buf].bufhidden = 'hide'
  end
  return buf
end

local function capture() return rex({ 'capture', '-b', state.pane, '--trim', '--unwrap' }) end

-- `text`: output already captured; nil captures it now (<leader>rq).
local function load_results(text)
  if not state.pane then return vim.notify('Rex: no pane yet; run a command first', vim.log.levels.WARN) end
  text = text or capture()
  local proc = pane_process(state.pane)
  if not text then return vim.notify('Rex: could not read the pane', vim.log.levels.ERROR) end
  local lines = vim.split(text, '\n', { trimempty = true })

  local buf = log_buffer()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Errorformat: the command's compiler, else Neovim's default plus Python tracebacks.
  local efm
  local compiler = state.cmd and compiler_for(state.cmd)
  vim.api.nvim_buf_call(buf, function()
    if compiler then
      vim.cmd.compiler(compiler)
      efm = vim.bo.errorformat
    else
      efm = vim.go.errorformat .. [[,%*\sFile "%f"\, line %l%.%#]]
    end
  end)

  -- Relative paths in the output are relative to the pane's directory, not nvim's.
  local cwd = proc and proc.foreground and proc.foreground.cwd or vim.fn.getcwd()
  table.insert(lines, 1, 'rex-dir: ' .. cwd)
  local items = vim.fn.getqflist({ lines = lines, efm = '%Drex-dir: %f,' .. efm }).items
  items = vim.tbl_filter(
    function(i) return i.valid == 1 and i.bufnr > 0 and vim.uv.fs_stat(vim.api.nvim_buf_get_name(i.bufnr)) end,
    items
  )

  vim.fn.setqflist({}, ' ', { title = 'Rex: ' .. (state.cmd or 'output'), items = items })
  if #items > 0 then
    vim.cmd('botright copen | wincmd p') -- show the list, keep the cursor where it was
  else
    vim.cmd.cclose()
  end
  vim.notify(('Rex: %s — %d location%s'):format(state.cmd or 'output', #items, #items == 1 and '' or 's'))
end

-- Running -----------------------------------------------------------------------------

local function stop_polling()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
    vim.cmd.redrawstatus()
  end
end

-- The process can exit a moment before the pane has drawn its last output,
-- so capture until two captures in a row match.
local function capture_settled(on_text)
  local prev, tries = nil, 0
  local function step()
    local text = capture()
    tries = tries + 1
    if text == prev or tries >= 10 then return on_text(text) end
    prev = text
    vim.defer_fn(step, 150)
  end
  step()
end

-- Poll the pane until its shell is back in front, then load results.
local function wait_for_finish(shell_pid)
  stop_polling()
  local started, seen_running = vim.uv.now(), false
  state.timer = vim.uv.new_timer()
  state.timer:start(
    300,
    300,
    vim.schedule_wrap(function()
      local proc = pane_process(state.pane)
      if not proc then return stop_polling() end
      local fg = proc.foreground and proc.foreground.pid
      if fg ~= shell_pid then
        seen_running = true
      elseif seen_running or vim.uv.now() - started > 1000 then
        stop_polling()
        capture_settled(load_results)
      end
    end)
  )
end

local function run(cmd)
  with_pane(function()
    local proc = pane_process(state.pane)
    if not at_prompt(proc) then
      local name = proc and proc.foreground and proc.foreground.name or '?'
      return vim.notify(('Rex: pane is busy (%s); not running'):format(name), vim.log.levels.WARN)
    end
    state.cmd = cmd
    rex({ 'block', 'call', '-b', state.pane, 'clear' })
    rex({ 'send', '-b', state.pane, cmd })
    rex({ 'send-key', '-b', state.pane, 'enter' })
    wait_for_finish(proc.foreground.pid)
    vim.cmd.redrawstatus()
  end)
end

local function ask_and_run()
  vim.ui.input({ prompt = 'Run in Rex: ', default = state.cmd, completion = 'shellcmd' }, function(cmd)
    if cmd and cmd ~= '' then run(cmd) end
  end)
end

local function rerun()
  if state.cmd then return run(state.cmd) end
  ask_and_run()
end

-- Re-run on save --------------------------------------------------------------------------

local watch_group = vim.api.nvim_create_augroup('rex_watch', { clear = true })
local watching = false

local function toggle_watch()
  watching = not watching
  vim.api.nvim_clear_autocmds({ group = watch_group })
  if watching then
    vim.api.nvim_create_autocmd('BufWritePost', { group = watch_group, callback = function() rerun() end })
  end
  vim.notify('Rex: re-run on save ' .. (watching and 'ON' or 'OFF'))
  vim.cmd.redrawstatus()
end

-- Keys and command ------------------------------------------------------------------------------

local map = vim.keymap.set
map('n', '<leader>rc', ask_and_run, { desc = 'Rex: run command in pane' })
map('n', '<leader>rr', rerun, { desc = 'Rex: re-run last command' })
map('n', '<leader>rw', toggle_watch, { desc = 'Rex: toggle re-run on save' })
map('n', '<leader>rq', load_results, { desc = 'Rex: reload results into quickfix' })
map('n', '<leader>rl', function() vim.cmd.sbuffer(log_buffer()) end, { desc = 'Rex: open output log' })
map('n', '<leader>rp', function()
  pick_pane(function() end)
end, { desc = 'Rex: choose pane' })

vim.api.nvim_create_user_command('Rex', function(opts)
  if opts.args == '' then return rerun() end
  run(opts.args)
end, { nargs = '*', complete = 'shellcmd', desc = 'Run a command in the Rex pane (no args: re-run)' })

-- For the statusline: what's running / whether watch mode is on.
function M.status()
  if not state.cmd then return '' end
  if state.timer then return '󰑮 ' .. state.cmd end
  if watching then return '󰈈 ' .. state.cmd end
  return ''
end

return M
