-- Plugin management on top of vim.pack: build hooks, commands, update check.
-- Plugins themselves are added in lua/plugins/*.lua.

local M = {}

function M.gh(repo) return 'https://github.com/' .. repo end

-- Build steps to run after a plugin is installed or updated, keyed by name.
-- Registered here, before any vim.pack.add(), because the first add() may
-- install every plugin from the lockfile at once.
local hooks = {
  -- Parsers must match nvim-treesitter's queries, so update them together.
  ['nvim-treesitter'] = function(data)
    if data.kind ~= 'update' then return end
    if not data.active then vim.cmd.packadd('nvim-treesitter') end
    vim.cmd('TSUpdate')
  end,
}

vim.api.nvim_create_autocmd('PackChanged', {
  group = vim.api.nvim_create_augroup('pack_hooks', { clear = true }),
  callback = function(ev)
    local hook = hooks[ev.data.spec.name]
    if hook and ev.data.kind ~= 'delete' then hook(ev.data) end
  end,
})

-- Commands ------------------------------------------------------------------

local function plugin_names()
  return vim.iter(vim.pack.get(nil, { info = false })):map(function(p) return p.spec.name end):totable()
end

vim.api.nvim_create_user_command(
  'PackUpdate',
  function(opts) vim.pack.update(#opts.fargs > 0 and opts.fargs or nil) end,
  { nargs = '*', complete = plugin_names, desc = 'Review plugin updates; :write applies, :quit cancels' }
)

vim.api.nvim_create_user_command('PackClean', function()
  local unused = vim
    .iter(vim.pack.get(nil, { info = false }))
    :filter(function(p) return not p.active end)
    :map(function(p) return p.spec.name end)
    :totable()
  if #unused == 0 then return vim.notify('No unused plugins') end
  if vim.fn.confirm('Delete ' .. table.concat(unused, ', ') .. '?', '&Yes\n&No', 2) == 1 then vim.pack.del(unused) end
end, { desc = 'Delete plugins that are no longer in the config' })

-- Update check ----------------------------------------------------------------
-- Fetches in the background and tells you if updates exist. Never applies them.

-- Run a command from inside a coroutine without blocking the editor.
local function run(cmd, cwd)
  local co = coroutine.running()
  vim.system(cmd, { cwd = cwd, text = true }, function(res) coroutine.resume(co, res) end)
  local res = coroutine.yield()
  return res.code == 0 and vim.trim(res.stdout) or nil
end

-- The git ref vim.pack.update() would move this plugin to (mirrors vim.pack's rules).
local function target_ref(p)
  local v = p.spec.version
  if v == nil then return 'origin/HEAD' end
  if type(v) == 'string' then
    local is_branch = run({ 'git', 'rev-parse', '--verify', '--quiet', 'origin/' .. v }, p.path)
    return is_branch and ('origin/' .. v) or v
  end
  -- Version range: newest semver tag inside it.
  local best, best_ver
  for tag in vim.gsplit(run({ 'git', 'tag', '--list' }, p.path) or '', '\n') do
    local ver = vim.version.parse(tag, { strict = true })
    if ver and v:has(ver) and (not best_ver or ver > best_ver) then
      best, best_ver = tag, ver
    end
  end
  return best
end

function M.check_updates()
  local plugs = vim.iter(vim.pack.get(nil, { info = false })):filter(function(p) return p.active end):totable()
  local pending, outdated = #plugs, {}
  for _, p in ipairs(plugs) do
    coroutine.wrap(function()
      if run({ 'git', 'fetch', '--quiet', '--tags', '--force', 'origin' }, p.path) then
        local ref = target_ref(p)
        local want = ref and run({ 'git', 'rev-list', '-1', ref }, p.path)
        if want and want ~= p.rev then table.insert(outdated, p.spec.name) end
      end
      pending = pending - 1
      if pending == 0 and #outdated > 0 then
        table.sort(outdated)
        vim.schedule(
          function()
            vim.notify(
              ('Plugin updates available: %s\nRun :PackUpdate to review.'):format(table.concat(outdated, ', '))
            )
          end
        )
      end
    end)()
  end
end

vim.api.nvim_create_user_command('PackCheck', M.check_updates, { desc = 'Check for plugin updates now' })

-- Check at most once a day, shortly after startup.
local stamp = vim.fn.stdpath('state') .. '/pack-last-check'
vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('pack_check', { clear = true }),
  once = true,
  callback = function()
    local stat = vim.uv.fs_stat(stamp)
    if stat and os.time() - stat.mtime.sec < 24 * 60 * 60 then return end
    vim.fn.writefile({}, stamp)
    M.check_updates()
  end,
})

return M
