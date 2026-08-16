-- =====================================================================
--  基本選項 — 取向是「幫助學 vim」，不是「讓 nvim 像 Sublime」
-- =====================================================================

local o = vim.o

-- --- 行號 -----------------------------------------------------------
-- ★ relativenumber 是學原生 vim 最有效的加速器：游標上下幾行都直接標成
--   1 2 3…，所以「往下三行」就是看一眼按 3j，不必自己算。當前行仍顯示絕對
--   行號(number 同時開著)，所以要跟別人講第幾行時也不用數。
o.number = true
o.relativenumber = true

-- --- 復原 -----------------------------------------------------------
-- ★ undofile：復原歷史寫進 nvim-data\undo\，關掉檔案再開還能繼續按 u。
--   沒有這個的話，:q 之後所有復原歷史就消失了 —— 對「隨手改一下」的用途，
--   這是最容易後悔的預設值。
o.undofile = true

-- --- 搜尋 -----------------------------------------------------------
-- ignorecase + smartcase 是一組的：全小寫的搜尋字串不分大小寫，
-- 只要你打了任何一個大寫字母就自動變成精確比對。
o.ignorecase = true
o.smartcase = true

-- ★ :grep 直接走 ripgrep(你 PATH 上已經有)。內建的 grep 在 Windows 上
--   會去找根本不存在的 grep.exe，是一個必踩的坑。
--   --vimgrep 讓輸出格式(檔案:行:欄:內容)剛好對上 grepformat，結果會進
--   quickfix 清單，用 :copen 看、:cnext / :cprev 跳。
o.grepprg = 'rg --vimgrep --smart-case'
o.grepformat = '%f:%l:%c:%m'

-- --- 版面 -----------------------------------------------------------
o.scrolloff = 5      -- 游標上下永遠保留 5 行，不會貼著螢幕邊緣打字
o.cursorline = true  -- 標出當前行
o.signcolumn = 'yes' -- ★ 固定保留左邊那一欄給 gitsigns。不固定的話，第一個
                     --   git 改動出現時整份文字會突然往右跳一格，很干擾。
o.splitright = true  -- 新的垂直分割開在右邊(預設是左邊，反直覺)
o.splitbelow = true  -- 新的水平分割開在下面

-- --- 縮排 -----------------------------------------------------------
-- ★ nvim 原廠預設是 tab 寬 8 且不轉空白，在今天幾乎沒有專案這樣寫。
--   這裡設 4 空白；lua 檔在 autocmds.lua 裡另外改成 2(跟你的 wezterm.lua 一致)。
--   專案裡有 .editorconfig 的話會蓋掉這裡 —— 那是 nvim 內建支援且預設開啟的。
o.expandtab = true
o.shiftwidth = 4
o.tabstop = 4
o.softtabstop = 4
o.smartindent = true

-- --- 滑鼠 -----------------------------------------------------------
-- ★ 保持 nvim 接管滑鼠(可以點選定位、拖曳成 visual、拖分割線)。
--   代價：WezTerm 的「拖曳選取即複製」在 nvim 畫面內會被攔截。
--   要用終端選取複製時，按住 Shift 拖曳即可繞過 nvim。
o.mouse = 'nvi'

-- --- 其他 -----------------------------------------------------------
o.termguicolors = true -- 24 位元色，tokyonight 需要(WezTerm 支援)
o.wrap = true          -- 長行折行顯示；隨手看設定檔時不折行更難讀
o.breakindent = true   -- 折行後對齊原本的縮排
