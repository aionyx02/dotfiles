-- =====================================================================
--  輸入 { 時自動補上 }
--
--  不使用外掛（nvim-autopairs 等）：只需處理 { 一種括號，用三個 insert 模式鍵位即可完成。
--    套件數維持 6 個。
--
--  三個鍵位互相配合，缺一不可：
--      {        插入 {}，游標停在中間
--      }        右邊正好是 } 時跳過它，不會變成 }}（打字習慣不需要改）
--      Enter    在 {|} 之間按下時展開成三行，游標停在縮排好的中間行
--
--  游標移動使用 <C-g>U<Left> 而非 <Left>：一般的 <Left> 會切斷 undo 與 . 重複，
--    <C-g>U 可讓整段輸入仍算同一次修改。
-- =====================================================================

local function next_char()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(col + 1, col + 1)
end

local function prev_char()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  return vim.api.nvim_get_current_line():sub(col, col)
end

-- 只在右邊是空白、行尾或閉括號時才補上 }。
--   游標緊貼在文字前面時（例如在 foo 前輸入 {），使用者多半是要把既有內容包起來，
--   此時自動補 } 反而需要再刪掉。
vim.keymap.set('i', '{', function()
  local nc = next_char()
  if nc == '' or nc:match('[%s%)%]};,]') then
    return '{}<C-g>U<Left>'
  end
  return '{'
end, { expr = true, desc = '輸入 { 時自動補上 }' })

vim.keymap.set('i', '}', function()
  return next_char() == '}' and '<C-g>U<Right>' or '}'
end, { expr = true, desc = '右邊已有 } 時直接跳過' })

-- 選單開啟時維持原生行為（關閉選單並換行），不搶補全的 Enter。
-- <C-o>O 在 } 上方開一行，縮排由 smartindent / 語言的 indentexpr 決定。
vim.keymap.set('i', '<CR>', function()
  if vim.fn.pumvisible() == 0 and prev_char() == '{' and next_char() == '}' then
    return '<CR><C-o>O'
  end
  return '<CR>'
end, { expr = true, desc = '在 {} 之間換行時展開成區塊' })
