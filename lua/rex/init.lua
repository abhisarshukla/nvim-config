-- Run commands in a Rex pane beside nvim and bring the results back, without
-- leaving nvim. Only active when nvim itself runs inside Rex.
--
--   <leader>rr  re-run the last task/command (remembered per project)
--   <leader>ra  pick a task (all tasks)      <leader>rc  run any command
--   <leader>rh  pick from history            <leader>rx  interrupt (Ctrl-C)
--   <leader>rw  toggle re-run on save        <leader>rq  reload results
--   <leader>ro  open the output log          <leader>rv  hide/show the pane
--   <leader>rk  close the pane               <leader>rp  use a different pane
--   <leader>r{key}  run the task with that key (e.g. rt test, rb build, rl lint)
--   :Rex {cmd}  run a command (:Rex alone re-runs)   :RexTasks  edit this project's tasks
--
-- Files: pane.lua (the Rex pane), run.lua (running + results),
-- tasks.lua (tasks + history per project).

local M = {}
function M.status() return '' end
if not vim.env.REX_SESSION then return M end

local pane = require('rex.pane')
local run = require('rex.run')
local tasks = require('rex.tasks')

-- Running things ---------------------------------------------------------------------

local function run_task(t) run.run({ cmd = t.cmd, name = t.name }) end

local function ask_and_run()
  local root = tasks.root()
  local last = run.current or tasks.last(root)
  -- Pre-fill: last command, else this project's test task.
  local default = last and last.cmd
  if not default then
    local test = vim.iter(tasks.list(root)):find(function(t) return t.name == 'test' end)
    default = test and test.cmd
  end
  vim.ui.input({ prompt = 'Run in Rex: ', default = default, completion = 'shellcmd' }, function(cmd)
    if cmd and cmd ~= '' then run.run({ cmd = cmd }) end
  end)
end

local function rerun()
  local last = run.current or tasks.last(tasks.root())
  if last then return run.run(last) end
  ask_and_run()
end

local function pick_task()
  local root = tasks.root()
  local items = tasks.list(root)
  table.insert(items, { name = 'Edit tasks…', edit = true })
  vim.ui.select(items, {
    prompt = 'Rex tasks',
    format_item = function(t)
      if t.edit then return t.name end
      return ('%-8s %s%s'):format(t.name, t.cmd, t.key and ('  <leader>r' .. t.key) or '')
    end,
  }, function(t)
    if not t then return end
    if t.edit then return tasks.edit(root) end
    run_task(t)
  end)
end

local function pick_history()
  local hist = tasks.history(tasks.root())
  if #hist == 0 then return vim.notify('Rex: no history for this project yet') end
  vim.ui.select(hist, {
    prompt = 'Rex history',
    format_item = function(e) return e.name and ('%s  (%s)'):format(e.cmd, e.name) or e.cmd end,
  }, function(e)
    if e then run.run(e) end
  end)
end

-- Re-run on save (files in this project only) -------------------------------------------

local watch_group = vim.api.nvim_create_augroup('rex_watch', { clear = true })
local watching = false

local function toggle_watch()
  watching = not watching
  vim.api.nvim_clear_autocmds({ group = watch_group })
  if watching then
    local root = tasks.root()
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = watch_group,
      callback = function(ev)
        if not vim.startswith(vim.api.nvim_buf_get_name(ev.buf), root .. '/') then return end
        local last = run.current or tasks.last(root)
        if last then run.run(last, true) end -- true: restart if still running
      end,
    })
  end
  vim.notify('Rex: re-run on save ' .. (watching and 'ON' or 'OFF'))
  vim.cmd.redrawstatus()
end

-- Keys ------------------------------------------------------------------------------------

local map = vim.keymap.set
map('n', '<leader>rr', rerun, { desc = 'Re-run last' })
map('n', '<leader>ra', pick_task, { desc = 'Tasks' })
map('n', '<leader>rc', ask_and_run, { desc = 'Run command' })
map('n', '<leader>rh', pick_history, { desc = 'History' })
map('n', '<leader>rx', function()
  if pane.alive() then pane.interrupt() end
end, { desc = 'Interrupt (Ctrl-C)' })
map('n', '<leader>rw', toggle_watch, { desc = 'Toggle re-run on save' })
map('n', '<leader>rq', function() run.load_results() end, { desc = 'Reload results' })
map('n', '<leader>ro', function() vim.cmd.sbuffer(run.log_buffer()) end, { desc = 'Output log' })
map('n', '<leader>rv', pane.toggle_hidden, { desc = 'Hide/show pane' })
map('n', '<leader>rk', pane.close, { desc = 'Close pane' })
map('n', '<leader>rp', pane.pick, { desc = 'Use a different pane' })

-- Task keys (<leader>r + task's key) for the current project; remapped when
-- the working directory changes.
local task_keys = {}
local function map_task_keys()
  for _, lhs in ipairs(task_keys) do
    pcall(vim.keymap.del, 'n', lhs)
  end
  task_keys = {}
  for _, t in ipairs(tasks.list(tasks.root())) do
    if t.key and t.key ~= '' then
      if tasks.reserved[t.key] then
        vim.notify(('Rex: task "%s" uses reserved key %s'):format(t.name, t.key), vim.log.levels.WARN)
      else
        local lhs = '<leader>r' .. t.key
        map('n', lhs, function() run_task(t) end, { desc = 'Task: ' .. t.name })
        table.insert(task_keys, lhs)
      end
    end
  end
end
map_task_keys()

local group = vim.api.nvim_create_augroup('rex', { clear = true })
vim.api.nvim_create_autocmd('DirChanged', { group = group, callback = map_task_keys })
-- Saving the task file applies it right away.
vim.api.nvim_create_autocmd('BufWritePost', {
  group = group,
  pattern = vim.fn.stdpath('data') .. '/rex/tasks/*.lua',
  callback = map_task_keys,
})

-- Commands ----------------------------------------------------------------------------------

vim.api.nvim_create_user_command('Rex', function(opts)
  if opts.args == '' then return rerun() end
  run.run({ cmd = opts.args })
end, { nargs = '*', complete = 'shellcmd', desc = 'Run a command in the Rex pane (no args: re-run)' })

vim.api.nvim_create_user_command('RexTasks', function() tasks.edit(tasks.root()) end, {
  desc = "Edit this project's Rex tasks",
})

-- Statusline: what's running / whether watch mode is on.
function M.status()
  local cur = run.current
  if not cur then return '' end
  local name = cur.name or cur.cmd
  if run.running() then return '󰑮 ' .. name end
  if watching then return '󰈈 ' .. name end
  return ''
end

return M
