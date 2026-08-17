-- =====================================================================
--  clangd — C / C++
--
--  ★ 最重要的一件事：clangd 要知道「這個檔案是怎麼編的」才會準。它找的是
--    compile_commands.json。有這個檔的專案，補全與診斷是完全精確的；沒有的
--    話它只能猜，猜不到的 #include 會整片標紅。
--
--      CMake 專案產生的方法：
--          cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
--      單檔 / 手寫 Makefile 的專案：在專案根放一個 compile_flags.txt，
--      一行一個編譯參數，例如：
--          -std=c++23
--          -Wall
--          -I./include
-- =====================================================================

-- ★ --query-driver 是 mingw 使用者一定要的：你的編譯器是
--   C:\Program Files\mingw64\bin\g++.exe，而 clangd 內建的預設標頭路徑是
--   照 MSVC / libc++ 排的。這個參數讓 clangd 實際去執行一次那個 g++、問它
--   「你的系統 include 路徑有哪些」，然後照抄。沒有這行的話，
--   #include <vector> 這種最基本的一行就會被標成找不到檔案。
--
-- ★ 路徑要用 glob 而且必須是「絕對路徑」，clangd 不接受相對路徑。
--   VS 2022 的 cl.exe 不需要列 —— clangd 對 MSVC 有內建支援。
local drivers = {
  'C:/Program Files/mingw64/bin/*g++.exe',
  'C:/Program Files/mingw64/bin/*gcc.exe',
  'C:/Program Files/mingw64/bin/*clang*.exe',
}

return {
  cmd = {
    'clangd',

    -- 背景索引整個專案，跨檔案的「跳到定義 / 找引用」才會準。
    -- 第一次開大專案時會吃一點 CPU，索引結果快取在 .cache/clangd/。
    '--background-index',

    -- 順手跑 clang-tidy 的靜態檢查(不只是編譯錯誤，還有「這樣寫有問題」)。
    '--clang-tidy',

    -- 補全選單顯示完整簽名(回傳型別 + 參數)，不是只有函式名。
    '--completion-style=detailed',

    -- ★ 刻意關掉自動插入 #include。開著的話，你選一個 std::vector，clangd
    --   會順手在檔案最上面插一行 #include <vector> —— 那是「補全順便改了
    --   你沒在看的地方」。跟 completeopt 裡 noselect 的理由是同一個：
    --   選字就只做選字。要它幫你補 include 時，用 gra(code action) 明確叫。
    '--header-insertion=never',

    -- ★ 關掉參數佔位符。開著的話選 push_back 會插入
    --       nums.push_back(const int &Val)
    --   那串 const int &Val 是「已選取的佔位文字」，你接著打字會蓋掉它 ——
    --   但只要你這時按了 <Esc>(而按 Esc 是 vim 使用者的反射動作)，那串字就
    --   原封不動留在程式碼裡了。關掉之後插入的是 push_back()，游標停在括號
    --   中間，乾淨且沒有這個陷阱。
    --   想知道參數有哪些：insert mode 按 <C-s>(nvim 內建的參數提示鍵)。
    --   要改回來的話把下面這行刪掉即可。
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
