-- Finding keys when you forget them.
--   <leader>sk  table of every key: yours, plugins', and Vim's built-ins.
--               Fuzzy search matches the key or its description only.
--               Preview shows where it's defined; <CR> runs a normal-mode key.
--   <leader>?   ask in plain English ("how do I stage part of a hunk?").
--               Claude answers from the keys this table lists, nothing else.
local M = {}

-- Collecting keys -------------------------------------------------------------

local modes = { 'n', 'x', 'o', 'i', 'c', 't' }
local config_dir = vim.fn.stdpath('config') .. '/'

-- "config: lua/plugins/git.lua", "gitsigns.nvim", "neovim", ...
local function where(file)
  if not file then return '' end
  if vim.startswith(file, config_dir) then return 'config: ' .. file:sub(#config_dir + 1) end
  local plugin = file:match('/pack/core/opt/([^/]+)/')
  if plugin then return plugin end
  if file:find(vim.env.VIMRUNTIME, 1, true) or file:match('^vim/') then return 'neovim' end
  return vim.fn.fnamemodify(file, ':~')
end

-- Where a mapping was defined: { file, line }.
local function definition(k)
  if k.callback then
    local info = debug.getinfo(k.callback, 'S')
    if info.what == 'Lua' and info.source:sub(1, 1) == '@' then
      return info.source:sub(2):gsub('^vim/', vim.env.VIMRUNTIME .. '/lua/vim/'), info.linedefined
    end
  elseif k.sid and k.sid > 0 then
    local script = vim.fn.getscriptinfo({ sid = k.sid })[1]
    if script then return script.name, k.lnum end
  end
end

-- Every key for buffer `buf`: { mode, keys, raw, desc, from, file?, line?, buffer? }
function M.collect(buf)
  local rows, seen = {}, {}
  local function add(r)
    local id = r.mode .. r.keys
    if seen[id] then return end
    seen[id] = true
    table.insert(rows, r)
  end

  -- Mappings: this buffer's first (they win over global ones).
  for _, mode in ipairs(modes) do
    for _, scope in ipairs({ 'buffer', 'global' }) do
      local maps = scope == 'buffer' and vim.api.nvim_buf_get_keymap(buf, mode) or vim.api.nvim_get_keymap(mode)
      for _, k in ipairs(maps) do
        if not k.lhs:match('^<Plug>') then
          local file, line = definition(k)
          local raw = vim.fn.keytrans(vim.keycode(k.lhs)) -- e.g. " gs" -> "<Space>gs"
          local keys = raw:gsub('<lt>', '<') -- readable: "g<" rather than "g<lt>"
          add({
            mode = mode,
            keys = keys,
            raw = raw,
            desc = (k.desc and k.desc ~= '') and k.desc or (k.rhs or ''),
            -- Neovim's text-only defaults (Y, &, <C-L>…) have no file; their desc is ":help …-default".
            from = (scope == 'buffer' and 'this buffer · ' or '')
              .. (file and where(file) or ((k.desc or ''):match('^:help .*%-default$') and 'neovim' or '')),
            file = file,
            line = line,
            buffer = scope == 'buffer',
          })
        end
      end
    end
  end

  -- Vim's own keys, described by mini.clue.
  local gen = require('mini.clue').gen_clues
  -- Prefixes add context the hint popup gets from its group ("Split vertically"
  -- under <C-w> means a window), so searching "split window" finds it.
  local groups = { { gen.g(), '' }, { gen.z(), '' }, { gen.windows(), 'Window: ' }, { gen.square_brackets(), '' } }
  for _, group in ipairs(groups) do
    for _, c in ipairs(group[1]) do
      if c.desc and type(c.keys) == 'string' then
        local raw = vim.fn.keytrans(vim.keycode(c.keys))
        add({
          mode = c.mode,
          keys = (raw:gsub('<lt>', '<')),
          raw = raw,
          desc = group[2] .. c.desc,
          from = 'vim built-in',
        })
      end
    end
  end
  return rows
end

-- The table -------------------------------------------------------------------------

local function pad(s, n) return s .. string.rep(' ', math.max(1, n - vim.fn.strdisplaywidth(s))) end

function M.table()
  local items = {}
  for _, r in ipairs(M.collect(vim.api.nvim_get_current_buf())) do
    local item = { row = r, text = r.keys .. ' ' .. r.desc } -- what fuzzy search matches
    if r.file and vim.uv.fs_stat(r.file) then
      item.file, item.pos = r.file, { math.max(r.line or 1, 1), 0 }
    else
      local details = { 'mode:  ' .. r.mode, 'keys:  ' .. r.keys, 'does:  ' .. r.desc, 'from:  ' .. r.from }
      item.preview = { text = table.concat(details, '\n'), ft = 'text' }
    end
    table.insert(items, item)
  end
  require('snacks').picker({
    title = 'Keys (search by key or description)',
    items = items,
    preview = function(ctx)
      if ctx.item.file then return require('snacks').picker.preview.file(ctx) end
      return require('snacks').picker.preview.preview(ctx)
    end,
    format = function(item)
      local r = item.row
      return {
        { r.mode .. ' ', 'SnacksPickerKeymapMode' },
        { pad(r.keys, 14), 'SnacksPickerKeymapLhs' },
        { pad(r.desc, 42) },
        { r.from, 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      -- Run normal-mode keys directly; for other modes the table is just a reference.
      if item and item.row.mode == 'n' then vim.schedule(function() vim.api.nvim_input(item.row.raw) end) end
    end,
  })
end

-- Asking in plain English -----------------------------------------------------------------

local system_prompt = table.concat({
  "You answer questions about the user's Neovim key bindings.",
  'Only suggest keys from the list provided (it is complete for this buffer) plus standard Vim keys and commands.',
  'If nothing fits, say so and suggest the closest key.',
  'Reply in at most 6 short lines of Markdown; put keys in backticks; mention the mode when it is not normal mode.',
}, ' ')

local function float(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = 'markdown'
  local width = math.min(90, vim.o.columns - 6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = 3,
    row = math.floor(vim.o.lines * 0.2),
    col = math.floor((vim.o.columns - width) / 2),
    border = 'rounded',
    title = ' Keys ',
    style = 'minimal',
  })
  vim.wo[win].wrap, vim.wo[win].linebreak = true, true
  local function set(text)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
    local height = 0
    for _, l in ipairs(text) do
      height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / width))
    end
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_set_height(win, math.min(height, vim.o.lines - 6)) end
  end
  for _, key in ipairs({ 'q', '<Esc>' }) do
    vim.keymap.set('n', key, function() pcall(vim.api.nvim_win_close, win, true) end, { buffer = buf, nowait = true })
  end
  set(lines)
  return set
end

function M.ask()
  local buf = vim.api.nvim_get_current_buf()
  vim.ui.input({ prompt = 'Ask about keys: ' }, function(question)
    if not question or question == '' then return end
    local rows = {}
    for _, r in ipairs(M.collect(buf)) do
      table.insert(rows, table.concat({ r.mode, r.keys, r.desc, r.from }, '\t'))
    end
    local input = table.concat({
      'Leader is <Space>. Modes: n normal, x visual, o operator-pending, i insert, c command-line, t terminal.',
      'Current filetype: ' .. vim.bo[buf].filetype,
      'Keys (mode, keys, description, defined in):',
      table.concat(rows, '\n'),
      '',
      'Question: ' .. question,
    }, '\n')

    local set = float({ '**' .. question .. '**', '', '_Asking Claude…_' })
    vim.system({
      'claude',
      '-p',
      '--model',
      'haiku',
      '--tools',
      '',
      '--system-prompt',
      system_prompt,
      '--no-session-persistence',
      '--disable-slash-commands',
      '--strict-mcp-config',
      '--setting-sources',
      '',
    }, { stdin = input, text = true, cwd = vim.fn.stdpath('cache') }, function(res)
      vim.schedule(function()
        local answer = res.code == 0 and vim.trim(res.stdout) or ('Claude failed: ' .. vim.trim(res.stderr or ''))
        set(vim.list_extend({ '**' .. question .. '**', '' }, vim.split(answer, '\n')))
      end)
    end)
  end)
end

-- Descriptions for matchit's % keys (bundled with Neovim, loaded after init.lua) ------

local matchit = {
  ['%'] = 'Jump to matching pair / if-else-end',
  ['g%'] = 'Jump back through matching pair / if-else-end',
  ['[%'] = 'Previous unmatched open (bracket / if)',
  [']%'] = 'Next unmatched close (bracket / end)',
  ['a%'] = 'around matching pair / block',
}
vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('keyhelp', { clear = true }),
  once = true,
  callback = function()
    for _, mode in ipairs({ 'n', 'x', 'o' }) do
      for _, k in ipairs(vim.api.nvim_get_keymap(mode)) do
        local desc = matchit[k.lhs]
        if desc and (k.rhs or ''):match('Matchit') and (k.desc or '') == '' then
          vim.keymap.set(mode, k.lhs, k.rhs, { remap = true, silent = true, desc = desc })
        end
      end
    end
  end,
})

-- Keys ---------------------------------------------------------------------------------------

vim.keymap.set('n', '<leader>sk', M.table, { desc = 'Search keys (table)' })
vim.keymap.set('n', '<leader>?', M.ask, { desc = 'Ask about keys in plain English' })

return M
