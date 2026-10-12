-- =====================================================================
--  Neovim 設定：終端機內的輕量編輯器
--
--  用途：修改設定檔、撰寫 git commit、從 yazi 開啟檔案。大型專案仍使用 JetBrains 或 Sublime。
--  原則：不覆蓋任何 vim 原生鍵位，自訂鍵位一律掛在 leader（\）之下。
--
--  設定檔實際位於 ~/.config/nvim，%LOCALAPPDATA%\nvim 是指向該處的目錄 junction。
--    junction 不需要開發人員模式（與 symlink 不同），且對 nvim 完全透明，
--    官方文件與 :checkhealth 顯示的路徑仍然正確。
--
--  套件程式碼位於 %LOCALAPPDATA%\nvim-data\site\pack\core\opt\，屬於可拋棄的快取：
--    整個刪除後重新啟動 nvim，會依 lua/plugins/ 重新建立。
--    本目錄只包含純文字設定，可完整納入 git。
--
--  套件不會自動更新，只在手動執行 :lua vim.pack.update() 時更新；
--    更新前會開啟 diff 分頁供審閱，:w 套用、:q 放棄。
--    實際版本記錄於本目錄的 nvim-pack-lock.json。
-- =====================================================================

-- mapleader 必須在定義任何 keymap 之前設定，已定義的鍵位不會套用新的 leader。
--   此處設定的即是 vim 的原生預設值（反斜線），明確寫出以表示這是刻意的選擇。
--   若要改用空白鍵，只需修改這兩行。
vim.g.mapleader = '\\'
vim.g.maplocalleader = '\\'

require('options')
require('autocmds')
require('completion') -- 輸入時自動顯示補全選單（僅用內建功能）
require('autopairs')  -- 輸入 { 時自動補上 }
require('lsp')        -- 啟用語言伺服器（設定位於 nvim/lsp/，不使用外掛）
require('plugins')    -- 安裝並設定外掛（首次啟動會執行 git clone，需要網路）
require('keymaps')    -- 自訂的 leader 鍵位，放在最後以確保外掛指令已存在
