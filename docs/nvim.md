# Neovim

設定檔裡的註解只說明「為什麼這樣設、改了會怎樣」；本檔記錄背後的實測數據與原始碼依據。

> **操作方式在 [TUTORIAL.md](../home/.config/nvim/TUTORIAL.md)**。本檔只講設定理由。

數據皆為本機（Windows 11、nvim 0.12）實測，換機器或升級後可能不同。修改設定後請跑 `.\check.ps1`。

---

## LSP：延遲到第一次開檔才檢查執行檔（`lua/lsp.lua`）

`vim.fn.executable()` 在本機每次約需 3～5ms：PATH 有 49 個目錄，且 nvim 不快取結果（連續查詢 100 次需 290ms）。啟動時檢查全部五個 server 約需 19ms，佔 nvim 啟動時間（109ms）的兩成；而開啟 git commit 訊息或 `.txt` 時，這些查詢完全用不到。

改為掛在 `FileType` 並設 `once = true`：只有實際用到該語言時才付出約 3ms，每個 session 一次。`require('lsp')` 因此從 22.8ms 降到 1.1ms。

不會漏掉已開啟的 buffer：`vim.lsp.enable()` 內部會以 `doautoall` 重新觸發 FileType（`runtime/lua/vim/lsp.lua` 的「Ensure any pre-existing buffers start」）。

filetypes 直接從 `lsp/<名稱>.lua` 讀取（`vim.lsp.config[name].filetypes`），解析五個設定檔共 1.3ms，因此不必在 `lsp.lua` 再抄一份清單。

`treesitter.lua` 也因同樣的理由，只在確實缺少 parser 時才呼叫 `executable('tree-sitter')`。

## lua_ls 的記憶體（`lsp/lua_ls.lua`）

lua_ls 常駐 232MB，其中 212MB 來自 `workspace.library` 載入的 VIMRUNTIME 型別標註。移除後只剩 20MB，但 `vim.api.*` 的補全候選數降為 0，所以這 212MB 是功能本身所需。

唯一沒有副作用的節省方式，是只在用得到 nvim API 的專案載入（`on_init` 的判斷）。編輯 `wezterm.lua` 等其他 Lua 檔時用不到 `vim.*`。

### root_markers 的順序

`init.lua` 必須排在 `.git` 之前。nvim 設定實際位於 `D:\Project\dotfiles` 這個 git repo 裡，若 `.git` 在前，根目錄會被判定為整個 dotfiles repo，`on_init` 判斷「是否為 nvim 設定目錄」時就會失敗（已實測）。

### 為什麼比對路徑前要先 realpath

同一份設定有三個入口，字串完全不同：`%LOCALAPPDATA%\nvim`（`stdpath('config')`）、`~\.config\nvim`、`D:\Project\dotfiles\home\.config\nvim`（實際位置）。只用 `vim.fs.normalize` 無法讓三者一致，必須先 `vim.uv.fs_realpath()`。

### 執行檔的位置

lua-language-server 由 winget 安裝在 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\LuaLS.lua-language-server_*\bin\`。未開啟開發人員模式時，winget 不會建立 Links 連結，而是把該目錄加進 User PATH，因此設定裡直接寫指令名稱。

## 剪貼簿同步的成本（`lua/autocmds.lua`）

`TextYankPost` 裡寫入 `+` register 平均耗時 7.9ms（經由 win32yank.exe），不會造成可察覺的延遲。

## treesitter（`lua/plugins/treesitter.lua`）

### 為什麼需要

沒有 treesitter 時，nvim 用舊式 regex 語法檔上色，只認得關鍵字、字串、數字。2026-10-12 實測：C++ 有 22/42 個詞、Python 有 17/43 個詞沒有顏色（型別、函式、成員、模組）。LSP 的 semantic tokens 可以補上一部分，但要等 server 啟動並完成索引（數秒）；treesitter 在開檔當下就完成上色。

剩下沒顏色的只有區域變數，那是 tokyonight 的設計，不是 bug。

### 編譯 parser 的 C 編譯器

不需要設定。tree-sitter CLI 會透過 vswhere 找到 Visual Studio 的 MSVC（本機是 VS 2022 Community，即使不在 PATH 上也找得到）。沒有 Visual Studio 的機器，先設定 `CC=gcc` 再 `:TSInstall`，改用 mingw。2026-10-12 實測兩者編出的 parser 都能正常載入。

## yazi 在 nvim 裡預覽圖片（`lua/plugins/yazi.lua`）

nvim 內建終端機不支援任何圖形協定，只能讓 yazi 改用 chafa 以字元近似顯示。但只安裝 chafa 不會生效：

nvim 的 job 會繼承 WezTerm 設定的 `TERM_PROGRAM`、`WEZTERM_*`，yazi 依此判定自己在 WezTerm 中（`yazi --debug` 顯示 `Brand.from_env = WezTerm`、`Adapter = Iip`），送出的圖片資料被 nvim 終端機直接丟棄，預覽欄一片空白。只清除 `TERM_PROGRAM` 不夠，`WEZTERM_*` 也會被判定；全部清除後 Adapter 才變成 Chafa（2026-10-14 以 headless nvim 的 term job 實測）。

yazi.nvim 沒有提供設定 yazi 環境變數的選項，因此包裝 `require('yazi').yazi`：`\y`、`\Y`、`:Yazi toggle`、開啟目錄最後都會呼叫它，而且 `jobstart` 在其中同步執行，所以只需在呼叫期間暫時移除這些變數，結束後立即還原。

`check.ps1` 會模擬 WezTerm 的環境變數實際開一次目錄，確認這個包裝在 yazi.nvim 更新後仍然有效。
