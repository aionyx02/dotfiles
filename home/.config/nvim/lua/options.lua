-- =====================================================================
--  基本選項：以學習原生 vim 為目標，不刻意模仿 Sublime
-- =====================================================================

local o = vim.o

-- --- 行號 -----------------------------------------------------------
-- relativenumber：游標上下各行標示相對行數，例如往下三行可直接看出並按 3j。
--   同時開啟 number，目前行仍顯示絕對行號。
o.number = true
o.relativenumber = true

-- --- 復原 -----------------------------------------------------------
-- undofile：將復原歷史寫入 nvim-data\undo\，關閉檔案後重新開啟仍可按 u 復原。
--   未開啟時，:q 後復原歷史即全部遺失。
o.undofile = true

-- --- 搜尋 -----------------------------------------------------------
-- ignorecase 與 smartcase 搭配使用：搜尋字串全為小寫時不分大小寫，
-- 含有任何大寫字母時則區分大小寫。
o.ignorecase = true
o.smartcase = true

-- :grep 改用 ripgrep。
--   內建設定在 Windows 上會呼叫不存在的 grep.exe。
--   --vimgrep 的輸出格式（檔案:行:欄:內容）與 grepformat 對應，結果會進入
--   quickfix 清單，可用 :copen 檢視、:cnext / :cprev 跳轉。
o.grepprg = 'rg --vimgrep --smart-case'
o.grepformat = '%f:%l:%c:%m'

-- --- 版面 -----------------------------------------------------------
o.scrolloff = 5      -- 游標上下至少保留 5 行
o.cursorline = true  -- 標示目前行
o.signcolumn = 'yes' -- 固定保留左側標記欄給 gitsigns；否則出現第一個
                     --   git 變更時，整份文字會向右位移一格
o.splitright = true  -- 垂直分割開在右側（預設為左側）
o.splitbelow = true  -- 水平分割開在下方

-- --- 縮排 -----------------------------------------------------------
-- nvim 預設為 tab 寬度 8 且不轉換為空白，此處改為 4 個空白；
--   Lua 檔案在 autocmds.lua 中另設為 2 個空白（與 wezterm.lua 一致）。
--   專案中若有 .editorconfig，將覆蓋此處設定（nvim 內建支援且預設啟用）。
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = true

-- --- 補全 -----------------------------------------------------------
-- noselect：補全選單出現時不自動選取候選項。
--   若不設定，選單一出現就會將第一個候選項插入文字中，造成輸入內容被改寫。
--   設定後選單僅供顯示：<C-n> / <C-p> 選擇、<C-y> 插入，不理會則繼續輸入，選單會自動關閉。
--
-- menuone：只有一個候選項時也顯示選單。
--   預設行為是直接插入唯一的候選項，在自動觸發補全時同樣會改寫輸入內容。
--
-- fuzzy：模糊比對，例如輸入 nvmbuf 可比對到 nvim_buf_set_lines。
-- popup：在選單旁另開小視窗，顯示候選項的說明（來自 LSP 的文件字串）。
o.completeopt = 'menu,menuone,noselect,popup,fuzzy'
o.pumheight = 10 -- 選單最多顯示 10 行，避免長清單遮住整個畫面

-- 'complete' 決定原生 <C-n> 的搜尋來源。
--   預設值包含 't'（tag 檔），但本機未使用 ctags，因此移除。保留以下四個來源：
--     .  目前檔案        w  其他分割視窗中的檔案
--     b  已開啟的檔案    u  已卸載的檔案
--   不加入 'o'（omnifunc / LSP）：該來源為同步呼叫，每輸入一個字元都要等待 LSP 回應。
--   LSP 補全改由 completion.lua 以非同步方式處理。
o.complete = '.,w,b,u'
o.infercase = true -- 補全結果依照已輸入的大小寫調整（輸入 nv 補出 nvim 而非 NVIM）

-- shortmess 加入 'c'：隱藏「-- 已搜尋全部 --」「符合 1 / 8」等補全訊息，
--   自動補全時這些訊息會在每次輸入時閃爍。
o.shortmess = o.shortmess .. 'c'

-- --- 滑鼠 -----------------------------------------------------------
-- 由 nvim 處理滑鼠（點選定位游標、拖曳進入 visual 模式、拖曳分割線）。
--   代價是 WezTerm 的「選取即複製」在 nvim 畫面中無效；
--   需要使用終端機的選取複製時，按住 Shift 拖曳即可。
o.mouse = 'nvi'

-- --- 其他 -----------------------------------------------------------
o.termguicolors = true -- 24 位元色彩，tokyonight 需要（WezTerm 支援）
o.wrap = true          -- 長行自動折行顯示
o.breakindent = true   -- 折行後的內容對齊原本的縮排
