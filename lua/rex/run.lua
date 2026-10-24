-- Running a command in the pane and bringing the results back.
-- nvim clears the pane, types the command, then watches the pane's foreground
-- process. When the shell is back in front the command is done: the whole
-- output goes into a log buffer and the file:line errors into quickfix.
local pane = require('rex.pane')
local tasks = require('rex.tasks')

local M = {}

M.current = nil -- { cmd, name? } of the last run
local timer = nil -- polls the pane while a command runs

function M.running() return timer ~= nil end

-- Results -----------------------------------------------------------------------------

-- Pick Neovim's built-in errorformat (:compiler) from the command's words.
local compilers = { 'cargo', 'go', 'pytest', 'tsc', 'jest', 'ruff', 'mypy', 'eslint' }
local function compiler_for(cmd)
  for _, name in ipairs(compilers) do
    if (' ' .. cmd .. ' '):find('[%s/]' .. name .. '%s') then return name end
  end
end

function M.log_buffer()
  local buf = vim.fn.bufnr('rex://output')
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, 'rex://output')
    vim.bo[buf].bufhidden = 'hide'
  end
  return buf
end

local function label() return M.current and (M.current.name or M.current.cmd) or 'output' end

-- `text`: output already captured; nil captures it now (<leader>rq).
function M.load_results(text)
  if not pane.alive() then return vim.notify('Rex: no pane yet; run something first', vim.log.levels.WARN) end
  text = text or pane.capture()
  if not text then return vim.notify('Rex: could not read the pane', vim.log.levels.ERROR) end
  local proc = pane.process()
  local lines = vim.split(text, '\n', { trimempty = true })

  local buf = M.log_buffer()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Errorformat: the command's compiler, else Neovim's default plus Python tracebacks.
  local efm
  local compiler = M.current and compiler_for(M.current.cmd)
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

  vim.fn.setqflist({}, ' ', { title = 'Rex: ' .. label(), items = items })
  if #items > 0 then
    vim.cmd('botright copen | wincmd p') -- show the list, keep the cursor where it was
  else
    vim.cmd.cclose()
  end
  vim.notify(('Rex: %s — %d location%s'):format(label(), #items, #items == 1 and '' or 's'))
end

-- Running -------------------------------------------------------------------------------

local function stop_polling()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
    vim.cmd.redrawstatus()
  end
end

-- The process can exit a moment before the pane has drawn its last output,
-- so capture until two captures in a row match.
local function capture_settled(on_text)
  local prev, tries = nil, 0
  local function step()
    local text = pane.capture()
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
  timer = vim.uv.new_timer()
  timer:start(
    300,
    300,
    vim.schedule_wrap(function()
      local proc = pane.process()
      if not proc then return stop_polling() end
      local fg = proc.foreground and proc.foreground.pid
      if fg ~= shell_pid then
        seen_running = true
      elseif seen_running or vim.uv.now() - started > 1000 then
        stop_polling()
        capture_settled(M.load_results)
      end
    end)
  )
end

-- Run `entry` ({ cmd, name? }) in the pane.
-- restart = true: if our previous run is still going, interrupt it first.
function M.run(entry, restart)
  local root = tasks.root()
  if not pane.ensure(root) then return vim.notify('Rex: could not find or create a pane', vim.log.levels.ERROR) end

  local proc = pane.process()
  if not pane.at_prompt(proc) and restart and M.running() then
    stop_polling()
    pane.interrupt()
    vim.wait(5000, function()
      proc = pane.process()
      return pane.at_prompt(proc)
    end, 100)
  end
  if not pane.at_prompt(proc) then
    local name = proc and proc.foreground and proc.foreground.name or '?'
    return vim.notify(('Rex: pane is busy (%s); not running'):format(name), vim.log.levels.WARN)
  end

  M.current = entry
  tasks.remember(root, entry)
  pane.type(entry.cmd)
  wait_for_finish(proc.foreground.pid)
  vim.cmd.redrawstatus()
end

return M
