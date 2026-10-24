-- The Rex pane that commands run in: find it by label, create it, hide/show,
-- close, and talk to it through the `rex` CLI.
local M = {}

-- Commands run in the pane with this label. If none exists, one is created below nvim.
M.NAME = 'run'

local session = vim.env.REX_SESSION
local me = vim.env.REX_BLOCK -- nvim's own pane
M.block = nil -- current pane id; found (or picked) once per nvim session

-- Rex CLI --------------------------------------------------------------------

function M.rex(args)
  local res = vim.system(vim.list_extend({ 'rex', '-s', session }, args), { text = true }):wait()
  return res.code == 0 and res.stdout or nil
end

local function decode(text)
  local ok, val = pcall(vim.json.decode, text or '')
  return ok and val or nil
end

function M.rex_json(args) return decode(M.rex(vim.list_extend(args, { '--json' }))) end

local function blocks() return (M.rex_json({ 'block', 'ls' }) or {}).blocks or {} end

-- Process info for a pane: { foreground = { pid, name, cwd }, ... }
function M.process(block) return decode(M.rex({ 'block', 'call', '-b', block or M.block, 'process' })) end

local shells = { zsh = true, bash = true, fish = true, sh = true, dash = true, nu = true }
function M.at_prompt(proc) return proc and proc.foreground and shells[proc.foreground.name] or false end

function M.alive() return M.block ~= nil and M.process() ~= nil end

function M.capture() return M.rex({ 'capture', '-b', M.block, '--trim', '--unwrap' }) end

function M.type(cmd)
  M.rex({ 'block', 'call', '-b', M.block, 'clear' })
  M.rex({ 'send', '-b', M.block, cmd })
  M.rex({ 'send-key', '-b', M.block, 'enter' })
end

function M.interrupt() M.rex({ 'send-key', '-b', M.block, 'ctrl+c' }) end

-- Finding / creating -----------------------------------------------------------

-- The pane labeled NAME, preferring one in nvim's own tab.
local function find_named()
  local all = blocks()
  local my_window
  for _, b in ipairs(all) do
    if b.block_id == me then my_window = b.window_id end
  end
  local found
  for _, b in ipairs(all) do
    if b.label == M.NAME and b.block_id ~= me then
      if b.window_id == my_window then return b.block_id end
      found = found or b.block_id
    end
  end
  return found
end

-- Ready = shell in front and its prompt drawn and unchanged for 300ms
-- (keys typed while the shell is still starting up get lost).
local function wait_ready(block)
  local last, stable_since = nil, vim.uv.now()
  vim.wait(10000, function()
    if not M.at_prompt(M.process(block)) then return false end
    local text = vim.trim(M.rex({ 'capture', '-b', block, '--trim' }) or '')
    if text ~= last then
      last, stable_since = text, vim.uv.now()
    end
    return text ~= '' and vim.uv.now() - stable_since >= 300
  end, 100)
end

-- Split a new shell pane below nvim; focus stays in nvim.
local function create(cwd)
  -- stylua: ignore
  local created = M.rex_json({
    'split', '-b', me, '--split', 'below', '--ratio', '30',
    '--label', M.NAME, '--focus=false', '-c', cwd,
  })
  local block = created and created.block_ids and created.block_ids[1]
  if not block then return nil end
  wait_ready(block)
  vim.notify(('Rex: created pane "%s" below'):format(M.NAME))
  return block
end

-- The pane to use: the remembered one, else found by name, else created.
function M.ensure(cwd)
  if not M.alive() then M.block = find_named() or create(cwd) end
  return M.block
end

-- Choose any other pane in this session for the rest of this nvim session.
function M.pick()
  local panes = {}
  for _, b in ipairs(blocks()) do
    if b.block_id ~= me and (b.flavor or ''):find('terminal') then
      local fg = (M.process(b.block_id) or {}).foreground or {}
      b.desc = ('%s  %s  [%s]'):format(b.label or '?', vim.fn.fnamemodify(fg.cwd or '?', ':~'), fg.name or '?')
      table.insert(panes, b)
    end
  end
  if #panes == 0 then return vim.notify('Rex: no other pane in this session', vim.log.levels.WARN) end
  vim.ui.select(panes, { prompt = 'Rex pane for commands', format_item = function(b) return b.desc end }, function(b)
    if b then M.block = b.block_id end
  end)
end

-- Hide / show / close --------------------------------------------------------------

local function window_of(block)
  for _, b in ipairs(blocks()) do
    if b.block_id == block then return b.window_id end
  end
end

-- Hide: move the pane into its own background tab (it keeps running).
-- Show: move it back below nvim; the emptied tab closes by itself.
function M.toggle_hidden()
  if not M.alive() then return vim.notify('Rex: no pane yet', vim.log.levels.WARN) end
  if window_of(M.block) == window_of(me) then
    local tab = M.rex_json({ 'window', 'new', M.NAME, '--focus=false' })
    local placeholder = tab and tab.block_ids and tab.block_ids[1]
    if not placeholder then return vim.notify('Rex: could not create a tab', vim.log.levels.ERROR) end
    M.rex({ 'move', M.block, 'right', placeholder })
    M.rex({ 'block', 'close', placeholder })
  else
    M.rex({ 'move', M.block, 'below', me, '--ratio', '30' })
  end
end

function M.close()
  if not M.alive() then return end
  M.rex({ 'block', 'close', M.block })
  M.block = nil
end

return M
