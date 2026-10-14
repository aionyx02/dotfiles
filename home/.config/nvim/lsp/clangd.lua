-- =====================================================================
--  clangd：C / C++
--
--  clangd 需要知道檔案的編譯方式才能正確分析，資訊來源為 compile_commands.json。
--    有此檔案時補全與診斷完全精確；沒有時只能推測，
--    無法解析的 #include 會被標為錯誤。
--
--      CMake 專案的產生方式：
--          cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
--      單一檔案或手寫 Makefile 的專案：在專案根目錄建立 compile_flags.txt，
--      每行一個編譯參數，例如：
--          -std=c++23
--          -Wall
--          -I./include
-- =====================================================================

-- 使用 mingw 時必須設定 --query-driver。
--   本機編譯器為 C:\Program Files\mingw64\bin\g++.exe，而 clangd 預設的標頭路徑
--   依 MSVC / libc++ 設定。此參數讓 clangd 實際執行一次 g++，取得其系統 include 路徑；
--   未設定時連 #include <vector> 都會被標為找不到檔案。
--
-- 路徑須為 glob 形式的絕對路徑，clangd 不接受相對路徑。
--   VS 2022 的 cl.exe 不需列出，clangd 已內建 MSVC 支援。
local drivers = {
  'C:/Program Files/mingw64/bin/*g++.exe',
  'C:/Program Files/mingw64/bin/*gcc.exe',
  'C:/Program Files/mingw64/bin/*clang*.exe',
}

return {
  cmd = {
    'clangd',

    -- 在背景索引整個專案，跨檔案的跳至定義與尋找參照才會準確。
    -- 首次開啟大型專案時會佔用一些 CPU，索引結果快取於 .cache/clangd/。
    '--background-index',

    -- 同時執行 clang-tidy 靜態檢查（除了編譯錯誤，也檢查有問題的寫法）。
    '--clang-tidy',

    -- 補全選單顯示完整簽名（回傳型別與參數），而非只有函式名稱。
    '--completion-style=detailed',

    -- 停用自動插入 #include。
    --   啟用時選擇 std::vector 會在檔案開頭自動加入 #include <vector>，
    --   等於補全時修改了畫面外的內容。理由與 completeopt 的 noselect 相同：
    --   選擇補全項目時不應有其他副作用。需要補上 include 時，以 gra（code action）明確執行。
    '--header-insertion=never',

    -- 停用參數佔位符。
    --   啟用時選擇 push_back 會插入
    --       nums.push_back(const int &Val)
    --   其中 const int &Val 為已選取的佔位文字，繼續輸入即可覆蓋；
    --   但若此時按下 <Esc>，佔位文字就會原樣留在程式碼中。
    --   停用後插入 push_back()，游標停在括號中間。
    --   查看參數：在 insert 模式按 <C-s>（nvim 內建的參數提示鍵）。
    --   刪除下面這行即可恢復預設行為。
    '--function-arg-placeholders=0',

    '--query-driver=' .. table.concat(drivers, ','),
  },

  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },

  root_markers = {
    'compile_commands.json',
    'compile_flags.txt',
    '.clangd',
    'CMakeLists.txt',
    'Makefile',
    '.git',
  },
}
