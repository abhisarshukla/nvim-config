-- Ask Claude about Neovim, your config, plugins or keys, in plain English.
--   <leader>?  ask; in the answer window:
--              a  ask a follow-up (same conversation)
--              r  run the command Claude suggested (shown at the bottom first)
--              q  close (the conversation ends)
--
-- Runs `claude -p` with the Haiku model. Claude can only read (Read/Grep/Glob):
-- Neovim's help files, your plugins' docs and this config. It can't run
-- anything or change files; a suggested command runs only when you press r.
local M = {}

local runtime_doc = vim.env.VIMRUNTIME .. '/doc'
local plugins = vim.fn.stdpath('data') .. '/site/pack/core/opt'
local config = vim.fn.stdpath('config')
-- Claude runs from here, so these conversations don't show up in your Claude
-- Code history for ~/.config/nvim.
local workdir = vim.fn.stdpath('cache') .. '/ask'

local function system_prompt()
  local v = vim.version()
  return table.concat({
    ("You answer questions about the user's Neovim %d.%d.%d: Neovim itself, their config, plugins and key bindings."):format(
      v.major,
      v.minor,
      v.patch
    ),
    'Sources you can read (use Grep/Read/Glob when unsure instead of guessing; answers must match this version):',
    '- Neovim help: ' .. runtime_doc .. ' (Vim help format; tags look like *tag*)',
    '- Plugin docs: ' .. plugins .. '/<plugin>/doc and README.md',
    '- Their config: ' .. config .. ' (README.md explains the layout and keys)',
    'The first message includes their full key table; prefer keys from it.',
    'Answer in at most 10 short lines of Markdown. Put keys and commands in backticks.',
    'If one Ex command directly does what they asked, end with a final line exactly: Command: :<command>',
  }, '\n')
end

local function uuid()
  math.randomseed(vim.uv.hrtime())
  return (
    ('xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'):gsub('[xy]', function(c)
      local n = c == 'x' and math.random(0, 15) or math.random(8, 11)
      return ('%x'):format(n)
    end)
  )
end

-- One Claude call. `session` = { id, started }; calls `done(answer_or_nil, error_or_nil)`.
local function call(session, message, done)
  vim.fn.mkdir(workdir, 'p')
  local cmd = {
    'claude',
    '-p',
    '--model',
    'haiku',
    '--output-format',
    'json',
    '--tools',
    'Read',
    'Grep',
    'Glob',
    '--allowedTools',
    'Read',
    'Grep',
    'Glob',
    '--permission-mode',
    'dontAsk',
    '--add-dir',
    runtime_doc,
    plugins,
    config,
    '--disable-slash-commands',
    '--strict-mcp-config',
    '--setting-sources',
    '',
  }
  if session.started then
    vim.list_extend(cmd, { '--resume', session.id })
  else
    vim.list_extend(cmd, { '--session-id', session.id, '--system-prompt', system_prompt() })
  end
  vim.system(cmd, { stdin = message, text = true, cwd = workdir }, function(res)
    vim.schedule(function()
      local ok, out = pcall(vim.json.decode, res.stdout or '')
      if res.code ~= 0 or not ok or out.is_error then
        return done(nil, ok and out.result or vim.trim(res.stderr or res.stdout or 'no output'))
      end
      session.started = true
      done(out.result)
    end)
  end)
end

-- What to tell Claude up front: where you are, and every key you have.
local function context(buf)
  local rows = {}
  for _, r in ipairs(require('keyhelp').collect(buf)) do
    table.insert(rows, table.concat({ r.mode, r.keys, r.desc, r.from }, '\t'))
  end
  local name = vim.api.nvim_buf_get_name(buf)
  return table.concat({
    'Current file: ' .. (name ~= '' and vim.fn.fnamemodify(name, ':~') or '(none)'),
    'Filetype: ' .. vim.bo[buf].filetype .. ' | cwd: ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'),
    'Leader is <Space>. Modes: n normal, x visual, o operator-pending, i insert, c command-line, t terminal.',
    'Keys (mode, keys, description, defined in):',
    table.concat(rows, '\n'),
  }, '\n')
end

-- The answer window ----------------------------------------------------------------------

function M.ask()
  local origin_win, origin_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  local session = { id = uuid(), started = false }
  local busy, command = false, nil
  local buf, win

  local function footer()
    local parts = { 'a follow-up' }
    if command then table.insert(parts, 'r run :' .. command) end
    table.insert(parts, 'q close')
    return ' ' .. table.concat(parts, ' · ') .. ' '
  end

  local function render(lines)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
    vim.bo[buf].modifiable = false
    if not vim.api.nvim_win_is_valid(win) then return end
    local width = vim.api.nvim_win_get_width(win)
    local height = 0
    for _, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / width))
    end
    vim.api.nvim_win_set_config(win, { height = math.min(height, math.floor(vim.o.lines * 0.7)), footer = footer() })
    vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  end

  local function send(question, message)
    busy = true
    render({ '', '**' .. question .. '**', '', '_Thinking… (reading docs and your config)_' })
    call(session, message, function(answer, err)
      busy = false
      if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, -2, -1, false, {}) -- drop "Thinking…"
      local lines = vim.split(answer or ('_Claude failed: ' .. err .. '_'), '\n')
      command = nil
      for i = #lines, 1, -1 do
        local found = lines[i]:match('^%s*Command:%s*:(.+)$')
        if found then
          command = vim.trim(found):gsub('`', '')
          table.remove(lines, i)
          break
        end
      end
      render(lines)
    end)
  end

  local function prompt(label, on_question)
    vim.ui.input({ prompt = label }, function(q)
      if q and q ~= '' then on_question(q) end
    end)
  end

  prompt('Ask about Neovim: ', function(question)
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = 'markdown'
    local width = math.min(100, vim.o.columns - 6)
    win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = 3,
      row = math.floor(vim.o.lines * 0.15),
      col = math.floor((vim.o.columns - width) / 2),
      border = 'rounded',
      title = ' Ask Claude ',
      footer = footer(),
      footer_pos = 'center',
      style = 'minimal',
    })
    vim.wo[win].wrap, vim.wo[win].linebreak, vim.wo[win].conceallevel = true, true, 2
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

    local function map(key, fn) vim.keymap.set('n', key, fn, { buffer = buf, nowait = true }) end
    local function close() pcall(vim.api.nvim_win_close, win, true) end
    map('q', close)
    map('<Esc>', close)
    map('a', function()
      if busy then return vim.notify('Ask: still answering') end
      prompt('Follow-up: ', function(q) send(q, q) end)
    end)
    map('r', function()
      if not command then return vim.notify('Ask: no command suggested') end
      local cmd = command
      close()
      local ok, err = pcall(vim.api.nvim_win_call, origin_win, function() vim.cmd(cmd) end)
      if ok then
        vim.notify('Ran :' .. cmd)
      else
        vim.notify('Ask: :' .. cmd .. ' failed: ' .. tostring(err), vim.log.levels.ERROR)
      end
    end)

    send(question, context(origin_buf) .. '\n\nQuestion: ' .. question)
  end)
end

vim.keymap.set('n', '<leader>?', M.ask, { desc = 'Ask Claude about Neovim / config / keys' })

return M
