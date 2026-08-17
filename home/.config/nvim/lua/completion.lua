-- =====================================================================
--  自動補全 — 打字時自動跳出候選選單
--
--  ★ vim 原生「有」補全(<C-n>、<C-x><C-o>…)，缺的只是「自動」這件事：
--    原生一定要你手動按鍵才會跳。這個檔案就只做一件事 —— 在你打字時
--    幫你按那個鍵。所有鍵位、所有行為都還是原生的：
--        <C-n> / <C-p>   上下選
--        <C-y>           確認選字        <C-e> 取消，回到你原本打的字
--    一個 vim 內建鍵都沒有被覆蓋，Enter 還是換行、Tab 還是縮排。
--
--  ★ 兩條來源，依 buffer 自動分流：
--      有 LSP  → 走 vim.lsp.completion(非同步，慢不會卡住打字)
--      沒 LSP  → 走原生 <C-n>(從已開啟的檔案裡收單字，零成本)
--    設定檔、git commit、隨手開的 txt 都吃得到第二條，這條才是「打錯字」
--    的主要解法 —— 你要的字通常已經在檔案裡出現過了。
-- =====================================================================

-- ★ 門檻：游標前(含正在打的這個字元)累積到 2 個字元才觸發。
--   設 1 的話每按一個字母都會跳選單，打中文標點、打註解時都在閃。
local MIN_CHARS = 2

local group = vim.api.nvim_create_augroup('autocomplete', { clear = true })

-- ---------------------------------------------------------------------
--  LSP 接上時，改用 LSP 當補全來源
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('LspAttach', {
    group = group,
    desc = '有 LSP 的 buffer 改用 LSP 補全',
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client or not client:supports_method('textDocument/completion') then
            return
        end

        -- ★ autotrigger 只認 server 自己宣告的「觸發字元」(lua 是 . 和 :)。
        --   所以 vim.<這裡> 會自己跳，但單純打 nvim_buf 不會 —— 那一半由
        --   下面的 InsertCharPre 補上。兩邊合起來才是完整的自動補全。
        vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
        vim.b[ev.buf].has_lsp_completion = true
    end,
})

vim.api.nvim_create_autocmd('LspDetach', {
    group = group,
    desc = 'LSP 斷線後退回原生單字補全',
    callback = function(ev)
        vim.b[ev.buf].has_lsp_completion = nil
    end,
})

-- ---------------------------------------------------------------------
--  打字時自動觸發
--
--  ★ 為什麼掛 InsertCharPre 而不是 TextChangedI：InsertCharPre 拿得到
--    vim.v.char(「即將被插入的那個字元」)，可以在字元進去之前就判斷要不要
--    觸發。TextChangedI 則是任何文字變動都會叫(含 undo、貼上、補全本身
--    插入的字)，很容易打成無窮迴圈。
-- ---------------------------------------------------------------------
vim.api.nvim_create_autocmd('InsertCharPre', {
    group = group,
    desc = '打字時自動叫出補全選單',
    callback = function()
        -- 選單已經開著 → 什麼都不做。nvim 內建就會隨著你繼續打字重新過濾。
        if vim.fn.pumvisible() == 1 then return end

        -- ★ state('m') = 「正在處理某個 mapping / :normal / feedkeys / 巨集」。
        --   在這種狀態下再塞鍵進去會弄亂正在跑的那串鍵 —— 錄巨集(q)和重播(@)
        --   時最明顯。這一行是防止補全污染巨集內容。
        if vim.fn.state('m') ~= '' then return end
        if vim.fn.reg_executing() ~= '' or vim.fn.reg_recording() ~= '' then return end

        -- ★ buftype 非空 = 不是真的檔案(fzf-lua 的輸入框、quickfix、終端…)。
        --   那些地方跳補全選單只會擋住畫面。
        if vim.bo.buftype ~= '' then return end

        -- 只在打「識別字元」時觸發。打空白、括號、標點都不該跳選單。
        if not vim.v.char:match('[%w_]') then return end

        -- 算游標前面已經連著幾個識別字元(這個字元還沒進去，所以要 +1)
        local col = vim.api.nvim_win_get_cursor(0)[2]
        local word = vim.api.nvim_get_current_line():sub(1, col):match('[%w_]*$')
        if #word + 1 < MIN_CHARS then return end

        if vim.b.has_lsp_completion then
            -- ★ vim.schedule 是必要的：現在這個字元還沒插進 buffer，直接問 LSP
            --   會拿到少一個字元的結果。排到下一輪事件迴圈時字元已經進去了。
            vim.schedule(function()
                if vim.fn.mode():find('i') and vim.fn.pumvisible() == 0 then
                    vim.lsp.completion.get()
                end
            end)
        else
            -- ★ 'n' 模式 = 不做鍵位映射展開，就是原封不動的 <C-n>。
            --   feedkeys 排在這個字元之後執行，所以 <C-n> 看到的是完整的字首。
            vim.api.nvim_feedkeys(vim.keycode('<C-n>'), 'n', false)
        end
    end,
})
