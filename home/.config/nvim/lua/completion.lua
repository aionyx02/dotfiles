-- =====================================================================
--  自動補全：輸入時自動顯示候選選單
--
--  vim 原生已有補全功能（<C-n>、<C-x><C-o> 等），但必須手動按鍵觸發。
--    本檔僅負責在輸入時自動送出該按鍵，其餘鍵位與行為皆為原生：
--        <C-n> / <C-p>   上下選擇（選單開啟時 Tab / Shift+Tab 也可，見檔案最後）
--        <C-y>           確認選擇        <C-e> 取消並還原原本輸入的文字
--    Enter 仍為換行；Tab 只在選單開啟時改為選擇，其餘時候仍為縮排。
--
--  依 buffer 自動選擇補全來源：
--      有 LSP：使用 vim.lsp.completion（非同步，不會阻塞輸入）
--      無 LSP：使用原生 <C-n>（從已開啟的檔案中收集單字，幾乎沒有成本）
--    設定檔、git commit 與一般文字檔都會使用後者，
--    可減少拼字錯誤，因為要輸入的字通常已出現在檔案中。
-- =====================================================================

-- 觸發門檻：游標前（含正要輸入的字元）累積 2 個字元才觸發。
--   設為 1 時每輸入一個字母都會顯示選單，輸入標點或註解時會不斷閃爍。
local MIN_CHARS = 2

local group = vim.api.nvim_create_augroup('autocomplete', { clear = true })

-- ---------------------------------------------------------------------
--  LSP 連線後，改以 LSP 作為補全來源
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('LspAttach', {
  group = group,
  desc = '有 LSP 的 buffer 改用 LSP 補全',
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or not client:supports_method('textDocument/completion') then
      return
    end

    -- autotrigger 只回應 server 宣告的觸發字元（Lua 為 . 與 :），
    --   因此輸入 vim. 會自動顯示選單，但直接輸入 nvim_buf 不會；
    --   後者由下方的 InsertCharPre 處理，兩者搭配才是完整的自動補全。
    vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
    vim.b[ev.buf].has_lsp_completion = true
  end,
})

vim.api.nvim_create_autocmd('LspDetach', {
  group = group,
  desc = 'LSP 斷線後退回原生單字補全',
  callback = function(ev)
    -- 同一 buffer 可能連接多個 server（如 .py 同時有 basedpyright 與 ruff），
    -- 只有在沒有其他支援補全的 client 時才退回原生補全。
    -- LspDetach 觸發時斷線的 client 仍在清單中，因此以 id 排除。
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = ev.buf })) do
      if client.id ~= ev.data.client_id and client:supports_method('textDocument/completion') then
        return
      end
    end
    vim.b[ev.buf].has_lsp_completion = nil
  end,
})

-- ---------------------------------------------------------------------
--  輸入時自動觸發
--
--  使用 InsertCharPre 而非 TextChangedI：InsertCharPre 可取得 vim.v.char
--    （即將插入的字元），能在字元插入前判斷是否觸發。
--    TextChangedI 在任何文字變動時都會觸發（包括 undo、貼上與補全本身插入的文字），
--    容易造成無窮迴圈。
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('InsertCharPre', {
  group = group,
  desc = '打字時自動叫出補全選單',
  callback = function()
    -- 選單已開啟時不處理，nvim 會隨輸入自動重新篩選。
    if vim.fn.pumvisible() == 1 then return end

    -- state('m') 非空表示正在執行 mapping、:normal、feedkeys 或巨集。
    --   此時送出按鍵會打亂正在執行的按鍵序列，在錄製（q）與重播（@）巨集時最明顯；
    --   此檢查可避免補全污染巨集內容。
    if vim.fn.state('m') ~= '' then return end
    if vim.fn.reg_executing() ~= '' or vim.fn.reg_recording() ~= '' then return end

    -- buftype 非空表示不是一般檔案（fzf-lua 輸入框、quickfix、終端機等），
    --   在這些地方顯示補全選單只會遮擋畫面。
    if vim.bo.buftype ~= '' then return end

    -- 只在輸入識別字元時觸發，空白、括號與標點不觸發。
    if not vim.v.char:match('[%w_]') then return end

    -- 計算游標前連續的識別字元數（目前字元尚未插入，因此要加 1）
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local word = vim.api.nvim_get_current_line():sub(1, col):match('[%w_]*$')
    if #word + 1 < MIN_CHARS then return end

    if vim.b.has_lsp_completion then
      -- 必須使用 vim.schedule：目前字元尚未插入 buffer，立即查詢 LSP
      --   會少一個字元；延到下一輪事件迴圈時字元已插入。
      vim.schedule(function()
        if vim.fn.mode():find('i') and vim.fn.pumvisible() == 0 then
          vim.lsp.completion.get()
        end
      end)
    else
      -- 'n' 模式表示不展開鍵位映射，送出的就是原生的 <C-n>。
      --   feedkeys 會在目前字元插入後執行，因此 <C-n> 能取得完整的字首。
      vim.api.nvim_feedkeys(vim.keycode('<C-n>'), 'n', false)
    end
  end,
})

-- ---------------------------------------------------------------------
--  選單開啟時，Tab / Shift+Tab 上下選擇
--
--  <C-n> / <C-p> 與方向鍵都離主鍵區太遠，選擇候選字時手要移開，使用上不順手。
--    只在 pumvisible() 時改變行為，選單沒開時送出原本的 Tab，縮排不受影響。
--  與 <C-n> 一樣只移動選取、不確認，確認仍用 <C-y>。
-- ---------------------------------------------------------------------
vim.keymap.set('i', '<Tab>', function()
  return vim.fn.pumvisible() == 1 and '<C-n>' or '<Tab>'
end, { expr = true, desc = '補全選單：下一個（選單沒開時為一般 Tab）' })

vim.keymap.set('i', '<S-Tab>', function()
  return vim.fn.pumvisible() == 1 and '<C-p>' or '<S-Tab>'
end, { expr = true, desc = '補全選單：上一個' })
