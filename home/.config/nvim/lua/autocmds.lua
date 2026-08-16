-- =====================================================================
--  自動指令
-- =====================================================================

-- ---------------------------------------------------------------------
--  新建的 .ps1 一律加 UTF-8 BOM
--
--  ★ 這台機器的硬規則：含中文的 .ps1 沒有 BOM 時，Windows PowerShell 5.1
--    會用 Big5 解讀而爆語法錯誤 —— 症狀跟編碼完全無關，是「語法錯誤」，
--    所以很難聯想到 BOM。你的 profile.ps1 開頭就寫著這件事。
--
--  ★ 只綁 BufNewFile，不綁 BufRead：既有檔案維持它原本的樣子。
--    nvim 開既有檔時本來就會偵測 BOM 並在存檔時保留，所以不需要插手；
--    而且別人的 repo 裡不該有 BOM 的 .ps1 也不會被我們偷偷改掉。
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('BufNewFile', {
    group = vim.api.nvim_create_augroup('ps1-bom', { clear = true }),
    pattern = { '*.ps1' },
    desc = '新建的 .ps1 自動加上 UTF-8 BOM',
    callback = function()
        vim.bo.fileencoding = 'utf-8'
        vim.bo.bomb = true
    end,
})

-- ---------------------------------------------------------------------
--  複製時高亮一下
--
--  ★ vim 的 y(複製)沒有任何畫面回饋，剛開始學時你會分不出「複製成功了」
--    跟「按錯鍵什麼都沒發生」。這條讓被複製的範圍閃一下。
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('TextYankPost', {
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    desc = '複製時把範圍高亮一下',
    callback = function()
        vim.hl.on_yank()
    end,
})

-- ---------------------------------------------------------------------
--  Lua 用 2 空白縮排(跟你的 wezterm.lua 一致)
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('FileType', {
    group = vim.api.nvim_create_augroup('indent-lua', { clear = true }),
    pattern = { 'lua' },
    desc = 'Lua 縮排 2 空白',
    callback = function()
        vim.bo.shiftwidth = 2
        vim.bo.tabstop = 2
        vim.bo.softtabstop = 2
    end,
})
