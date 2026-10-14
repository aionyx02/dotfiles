-- =====================================================================
--  自動指令
-- =====================================================================

-- ---------------------------------------------------------------------
--  新建的 .ps1 檔案一律加上 UTF-8 BOM
--
--  含中文的 .ps1 若沒有 BOM，Windows PowerShell 5.1 會以 Big5 解讀而產生語法錯誤。
--    錯誤訊息只顯示語法錯誤，不容易聯想到編碼問題。
--
--  只綁定 BufNewFile，不綁定 BufRead：既有檔案維持原樣。
--    nvim 開啟既有檔案時會自動偵測 BOM 並在存檔時保留，不需額外處理；
--    也可避免修改其他 repo 中本來就不帶 BOM 的 .ps1。
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
--  複製時短暫高亮被複製的範圍
--
--  vim 的 y 沒有畫面回饋，無法分辨是複製成功還是按錯鍵。
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
  desc = '複製時把範圍高亮一下',
  callback = function()
    vim.hl.on_yank()
  end,
})

-- ---------------------------------------------------------------------
--  以 y 複製時，同步寫入 Windows 剪貼簿
--
--  不使用 clipboard=unnamedplus：該選項會將所有 register 操作連到剪貼簿，
--    而 vim 的 d 是剪下而非刪除，因此每次 d / c / x / s 都會覆蓋 Windows 剪貼簿。
--    此處只處理 y 這個 operator，只有實際複製時剪貼簿才會改變。
--
--  regname == '' 的條件用於排除具名 register：明確輸入 "ay 表示要存到 a，
--    不應覆蓋剪貼簿；"+y 則走原生路徑，本來就會寫入剪貼簿。
--
--  此設定不修改任何鍵位，y、yy、Vy 皆為原生行為。
--    貼上方向不需設定：WezTerm 的 Ctrl+V 與 Shift+Insert 已綁定
--    PasteFrom Clipboard，在 insert 模式中可直接使用。
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
--  Lua 檔案使用 2 個空白縮排（與 wezterm.lua 一致）
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

-- ---------------------------------------------------------------------
--  C / C++ 預先設好 :make，開檔後直接 :make 即可編譯並跳到錯誤行
--
--  做法與 TUTORIAL 第 10 節的手動流程相同（:compiler gcc + setlocal makeprg），
--    只是在開檔時自動執行。都是 buffer 區域的設定，不影響其他檔案。
--
--  仍可隨時以 :setlocal makeprg=... 改成別的指令（例如有 Makefile 的專案改回 make）。
--    已手動設定過時不會覆蓋：:e 重新載入會再次觸發 FileType，
--    因此先檢查 buffer 區域的 makeprg 是否為空，空的才填入預設值。
--
--  -lstdc++exp：mingw g++ 15 的 std::print 實作位於此函式庫，少了它會連結失敗，
--    且錯誤訊息看不出原因；未使用 <print> 的程式加上也沒有影響。
--  -std=c++23：g++ 預設為 C++17，需明確指定。
--  %:S：路徑含空白時加上引號。mingw 在 -o 沒有副檔名時會自動產生 .exe。
-- ---------------------------------------------------------------------
local makeprg = {
  c = 'gcc -std=c17 -Wall -g %:S -o %:r:S',
  cpp = 'g++ -std=c++23 -Wall -g %:S -o %:r:S -lstdc++exp',
}

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('make-c-cpp', { clear = true }),
  pattern = { 'c', 'cpp' },
  desc = 'C / C++ 預設 :make 為單檔編譯',
  callback = function(ev)
    if vim.api.nvim_get_option_value('makeprg', { scope = 'local', buf = ev.buf }) ~= '' then
      return
    end
    vim.cmd.compiler('gcc') -- 只設定 errorformat（解析錯誤訊息），不設定 makeprg
    vim.bo[ev.buf].makeprg = makeprg[ev.match]
  end,
})
