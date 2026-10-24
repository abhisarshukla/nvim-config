local group = vim.api.nvim_create_augroup('config', { clear = true })

-- Briefly highlight yanked text.
vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  callback = function() vim.hl.on_yank() end,
})

-- Clipboard: yanks go to the system clipboard, deletes/changes don't.
-- When nvim regains focus and the clipboard holds something new (copied in
-- another app), make it what `p` pastes.
local last_clip -- clipboard text we last sent or received

local function norm(s) return (s:gsub('\n+$', '')) end

vim.api.nvim_create_autocmd('TextYankPost', {
  group = group,
  callback = function()
    local ev = vim.v.event
    -- Only plain `y` into the default register; "ay etc. stay private.
    if ev.operator ~= 'y' or ev.regname ~= '' then return end
    vim.fn.setreg('+', ev.regcontents, ev.regtype)
    last_clip = norm(table.concat(ev.regcontents, '\n'))
  end,
})

vim.api.nvim_create_autocmd('FocusGained', {
  group = group,
  callback = function()
    local clip = vim.fn.getreginfo('+')
    local text = norm(table.concat(clip.regcontents or {}, '\n'))
    if text == '' or text == last_clip then return end
    last_clip = text
    vim.fn.setreg('"', clip.regcontents, clip.regtype)
  end,
})
