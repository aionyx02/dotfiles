-- =====================================================================
--  Neovim 設定 — 終端內的隨手編輯器
--
--  定位：改設定檔、寫 git commit、從 yazi 開檔。大型專案仍走 JetBrains / Sublime。
--  原則：vim 原生鍵位一個都不覆蓋。自訂鍵全部掛在 leader (\) 底下。
--
--  ★ 真身在 ~/.config/nvim，%LOCALAPPDATA%\nvim 是指過來的目錄 junction。
--    junction 不需要開發人員模式(跟 symlink 不同)，而且 nvim 完全不知情 —
--    官方文件與 :checkhealth 的路徑訊息都還是對的。
--
--  ★ 套件程式碼不在這裡，在 %LOCALAPPDATA%\nvim-data\site\pack\core\opt\。
--    那是拋棄式快取：整個刪掉再開 nvim 就會照 lua/plugins/ 重建。
--    這個目錄裡永遠只有純文字，可以整份丟進 git。
--
--  ★ 套件永遠不會自己更新。只有你手動執行 :lua vim.pack.update() 才會，
--    而且會先開一個 diff 分頁讓你審，:w 套用 / :q 丟掉。
--    實際版本記在 nvim-pack-lock.json(本目錄內)。
-- =====================================================================

-- ★ mapleader 必須在任何 keymap 定義之前設定 — 已經定義的鍵不會回溯套用新的 leader。
--   這裡設的就是 vim 的原生預設值(反斜線)，寫出來是為了讓它是一個明確的決定，
--   而不是「剛好沒設」。想換成空白鍵時，改這兩行就好，其他檔案一行都不用動。
vim.g.mapleader = '\\'
vim.g.maplocalleader = '\\'

require('options')
require('autocmds')
require('completion') -- 打字時自動跳補全選單(純內建，不靠外掛)
require('lsp')        -- 啟用語言伺服器(設定在 nvim/lsp/ 底下，也不靠外掛)
require('plugins')    -- 安裝並設定外掛(第一次會 git clone，需要網路)
require('keymaps')    -- 我們自己的 leader 鍵，放最後：此時外掛指令已經存在
