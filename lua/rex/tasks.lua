-- Tasks per project: built-in ones from the project type, plus your own in a
-- private file (:RexTasks). Also remembers each project's command history.
-- Everything lives in nvim's data folder, never in the project.
local M = {}

local dir = vim.fn.stdpath('data') .. '/rex'

-- Keys under <leader>r that belong to Rex itself; tasks can't use them.
M.reserved =
  { a = true, c = true, h = true, k = true, o = true, p = true, q = true, r = true, v = true, w = true, x = true }

function M.root() return vim.fs.root(vim.fn.getcwd(), '.git') or vim.fn.getcwd() end

local function has(root, name) return vim.uv.fs_stat(root .. '/' .. name) ~= nil end

-- Built-in tasks ---------------------------------------------------------------

local function node_tasks(root)
  local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(root .. '/package.json'), '\n'))
  local scripts = ok and type(pkg) == 'table' and pkg.scripts or {}
  local pm = has(root, 'pnpm-lock.yaml') and 'pnpm'
    or has(root, 'yarn.lock') and 'yarn'
    or (has(root, 'bun.lock') or has(root, 'bun.lockb')) and 'bun'
    or 'npm'
  local tasks = {}
  for name, key in pairs({ test = 't', build = 'b', lint = 'l' }) do
    if scripts[name] then tasks[name] = { cmd = pm .. ' run ' .. name, key = key } end
  end
  return tasks
end

-- Sensible test/build/lint commands for the project type at `root`.
function M.builtin(root)
  if has(root, 'Cargo.toml') then
    return {
      test = { cmd = 'cargo test', key = 't' },
      build = { cmd = 'cargo build', key = 'b' },
      lint = { cmd = 'cargo clippy', key = 'l' },
    }
  elseif has(root, 'go.mod') then
    return {
      test = { cmd = 'go test ./...', key = 't' },
      build = { cmd = 'go build ./...', key = 'b' },
      lint = { cmd = 'go vet ./...', key = 'l' },
    }
  elseif has(root, 'pyproject.toml') or has(root, 'setup.py') or has(root, 'requirements.txt') then
    local run = has(root, 'uv.lock') and 'uv run ' or ''
    return {
      test = { cmd = run .. 'pytest', key = 't' },
      lint = { cmd = run .. 'ruff check .', key = 'l' },
    }
  elseif has(root, 'package.json') then
    return node_tasks(root)
  end
  return {}
end

-- Your tasks -----------------------------------------------------------------------

function M.file(root) return ('%s/tasks/%s.lua'):format(dir, (root:gsub('[/\\:]', '%%'))) end

local function own_tasks(root)
  local path = M.file(root)
  if not vim.uv.fs_stat(path) then return {} end
  local ok, tasks = pcall(dofile, path)
  if not ok or type(tasks) ~= 'table' then
    vim.notify('Rex: error in ' .. path .. '\n' .. tostring(tasks), vim.log.levels.ERROR)
    return {}
  end
  return tasks
end

-- Built-in tasks with yours merged over them (`name = false` removes one).
-- Returns a list sorted by name: { { name, cmd, key }, ... }
function M.list(root)
  local merged = vim.tbl_extend('force', M.builtin(root), own_tasks(root))
  local list = {}
  for name, t in pairs(merged) do
    if t then table.insert(list, { name = name, cmd = t.cmd, key = t.key }) end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

-- Open this project's task file, creating it from a template the first time.
function M.edit(root)
  local path = M.file(root)
  if not vim.uv.fs_stat(path) then
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local lines = {
      '-- Rex tasks for ' .. root,
      '-- Private to nvim (not in the project). Merged over the built-in tasks;',
      '-- set a name to false to remove a built-in one.',
      '--   name = { cmd = "shell command", key = "x" }   -- key: <leader>r<key>, optional',
      '-- Keys taken by Rex: a c h k o p q r v w x',
      '',
      '-- Built-in tasks for this project:',
    }
    for _, t in ipairs(M.list(root)) do
      table.insert(lines, ('--   %s = { cmd = %q, key = %q },'):format(t.name, t.cmd, t.key or ''))
    end
    vim.list_extend(lines, { '', 'return {', '}' })
    vim.fn.writefile(lines, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end

-- History (per project, kept across restarts) -------------------------------------------

local state_file = dir .. '/state.json'

local function read_state()
  if not vim.uv.fs_stat(state_file) then return {} end
  local ok, s = pcall(vim.json.decode, table.concat(vim.fn.readfile(state_file), '\n'))
  return ok and type(s) == 'table' and s or {}
end

-- Most recent first: { { cmd, name? }, ... }
function M.history(root) return (read_state()[root] or {}).history or {} end

function M.last(root) return M.history(root)[1] end

function M.remember(root, entry)
  local s = read_state()
  local hist = vim.tbl_filter(function(e) return e.cmd ~= entry.cmd end, (s[root] or {}).history or {})
  table.insert(hist, 1, { cmd = entry.cmd, name = entry.name })
  s[root] = { history = vim.list_slice(hist, 1, 30) }
  vim.fn.mkdir(dir, 'p')
  vim.fn.writefile({ vim.json.encode(s) }, state_file)
end

return M
