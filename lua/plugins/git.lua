-- Git in the buffer: change signs, hunks, blame, diffs (gitsigns.nvim).
-- Signs are drawn in the right slot of the snacks statuscolumn (lua/plugins/snacks.lua).
-- Everything else git (commits, pushes, log) stays in your Rex shell.
local gh = require('pack').gh

vim.pack.add({
  { src = gh('lewis6991/gitsigns.nvim'), version = vim.version.range('2.*') },
})

local gs = require('gitsigns')

gs.setup({
  current_line_blame = false, -- <leader>tb toggles it
  current_line_blame_opts = { delay = 300 },
  on_attach = function(buf)
    local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc }) end
    local function selection() return { vim.fn.line('.'), vim.fn.line('v') } end

    -- Moving between hunks
    map('n', ']h', function() gs.nav_hunk('next') end, 'Next hunk')
    map('n', '[h', function() gs.nav_hunk('prev') end, 'Previous hunk')
    map('n', ']H', function() gs.nav_hunk('last') end, 'Last hunk')
    map('n', '[H', function() gs.nav_hunk('first') end, 'First hunk')
    map({ 'o', 'x' }, 'ih', gs.select_hunk, 'inside hunk')

    -- Looking at changes
    map('n', '<leader>gp', gs.preview_hunk, 'Preview hunk (popup)')
    map('n', '<leader>gi', gs.preview_hunk_inline, 'Preview hunk (inline)')
    map('n', '<leader>gd', gs.diffthis, 'Diff file vs index')
    map('n', '<leader>gD', function() gs.diffthis('~') end, 'Diff file vs last commit')
    map('n', '<leader>gq', function() gs.setqflist('all') end, 'All hunks → quickfix')

    -- Blame
    map('n', '<leader>gb', function() gs.blame_line({ full = true }) end, 'Blame line (full commit)')
    map('n', '<leader>gB', gs.blame, 'Blame whole file')
    map('n', '<leader>tb', gs.toggle_current_line_blame, 'Toggle line blame')

    -- Staging
    map('n', '<leader>gs', gs.stage_hunk, 'Stage hunk')
    map('x', '<leader>gs', function() gs.stage_hunk(selection()) end, 'Stage selected lines')
    map('n', '<leader>gr', gs.reset_hunk, 'Reset hunk')
    map('x', '<leader>gr', function() gs.reset_hunk(selection()) end, 'Reset selected lines')
    map('n', '<leader>gS', gs.stage_buffer, 'Stage file')
    map('n', '<leader>gR', gs.reset_buffer, 'Reset file')
  end,
})

-- The snacks statuscolumn caches signs for 50ms. When gitsigns places signs
-- right after a file opens, the column can be drawn from the stale cache and
-- stay sign-less until the cursor moves. Redraw it once the cache has expired.
vim.api.nvim_create_autocmd('User', {
  group = vim.api.nvim_create_augroup('git_signs_redraw', { clear = true }),
  pattern = 'GitSignsUpdate',
  callback = function(ev)
    local buf = ev.data and ev.data.buffer
    vim.defer_fn(function()
      if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim__redraw({ buf = buf, statuscolumn = true }) end
    end, 60)
  end,
})
