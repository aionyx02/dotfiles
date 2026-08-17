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
--  y 複製時順手同步一份到 Windows 剪貼簿
--
--  ★ 為什麼不用 clipboard=unnamedplus：那個選項是把「所有 register 操作」
--    都接到剪貼簿上，而 vim 的 d 是「剪下」不是「刪除」—— 於是每按一次
--    d / c / x / s 都會洗掉 Windows 剪貼簿，連刪一個字元的 x 都會。
--    這裡改成只攔 y 這一個 operator，剪貼簿只有你真的「複製」時才會變。
--
--  ★ regname == '' 的條件是留給具名 register 的：明確打了 "ay 就是想存到
--    a，不該順便蓋掉剪貼簿。同理 "+y 走的是原生路徑，本來就會進剪貼簿。
--
--  ★ 這條完全不動鍵位 —— y / yy / Vy 都還是原生的 y，沒有任何 vim 內建鍵
--    被覆蓋。反方向(貼上)不用設：WezTerm 的 Ctrl+V 與 Shift+Insert 已經綁
--    了 PasteFrom Clipboard，insert mode 直接按就進來了。
--
--  ★ 成本實測過：在 nvim 內寫一次剪貼簿平均 7.9ms(win32yank.exe)，
--    不會有可感知的延遲。
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('TextYankPost', {
    group = vim.api.nvim_create_augroup('yank-to-clipboard', { clear = true }),
    desc = 'y 複製的內容同步一份到系統剪貼簿',
    callback = function()
        local ev = vim.v.event
        if ev.operator == 'y' and ev.regname == '' then
            vim.fn.setreg('+', ev.regcontents, ev.regtype)
        end
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
