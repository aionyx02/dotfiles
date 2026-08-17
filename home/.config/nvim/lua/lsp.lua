-- =====================================================================
--  LSP 開關 — 設定內容在 nvim/lsp/<名字>.lua，這裡只決定「啟用哪幾隻」
--
--  ★ 沒有用 nvim-lspconfig。nvim 0.11 起把「讀 lsp/<名字>.lua、依 filetype
--    啟動、依 root_markers 找專案根」整套搬進核心了，那個套件現在只剩「一包
--    別人寫好的預設值」的價值。我們只用三隻，自己寫比多一個相依便宜。
--    所以套件數還是 5 個(tokyonight、fzf-lua、gitsigns、yazi.nvim、plenary)。
--
--  ★ 補全本身不在這裡，在 lua/completion.lua —— 那個檔案同時管「有 LSP」和
--    「沒 LSP」兩種情況，這裡只負責把 server 叫起來。
-- =====================================================================

-- 名字 → 要檢查的執行檔。找不到執行檔就跳過，不會在啟動時噴錯。
-- ★ 為什麼要這層檢查：這是全域設定，會在每一台機器/每一個專案生效。
--   直接 enable 一隻不存在的 server，nvim 會在你每次開對應檔案時報一次錯。
local servers = {
  lua_ls = 'lua-language-server',           -- .lua  設定檔(nvim / wezterm)
  clangd = 'clangd',                        -- .c .cpp .h .hpp
  basedpyright = 'basedpyright-langserver', -- .py   補全 + 型別
  ruff = 'ruff',                            -- .py   lint + 格式化(跟上面分工)
  rust_analyzer = 'rust-analyzer',          -- .rs   只在 Cargo 專案啟動
}

-- ---------------------------------------------------------------------
--  ★ 為什麼不在啟動時直接檢查完 —— 這是實測出來的：
--    `vim.fn.executable()` 在這台機器上一次要 3~5ms(PATH 有 49 個目錄，而且
--    nvim 完全不快取，連續查 100 次是 290ms)。五隻查完 ≈ 19ms，佔整個 nvim
--    啟動時間(109ms)的 兩成 —— 而且是白付的：開 git commit message、開一個
--    .txt，這五次查詢一樣會跑，卻沒有任何一隻 server 用得上。
--
--    改成「第一次開到那個檔案類型時才查」之後，只有你真的在寫那個語言時才
--    付那 3ms，而且一個 session 只付一次(once = true)。
--
--  ★ 這樣做安全的原因：vim.lsp.enable() 內部會 doautoall 補踩一次 FileType
--    (runtime/lua/vim/lsp.lua 的「Ensure any pre-existing buffers start」)，
--    所以「已經開著的這個 buffer」不會被漏掉，不需要自己補觸發。
--
--  ★ filetypes 直接從 lsp/<名字>.lua 讀出來，不在這裡再抄一份 —— 兩邊列表
--    不同步是遲早會發生的 bug。實測解析五個設定檔只要 1.3ms。
-- ---------------------------------------------------------------------
local group = vim.api.nvim_create_augroup('lsp-lazy-enable', { clear = true })

for name, exe in pairs(servers) do
  local ok, cfg = pcall(function() return vim.lsp.config[name] end)
  local filetypes = ok and cfg and cfg.filetypes

  if not filetypes then
    -- 沒有 filetypes 的話 autocmd 的 pattern 會變成 '*'，變成每開一個檔案都
    -- 觸發一次 —— 寧可跳過這隻並講清楚，也不要偷偷退化成全域觸發。
    vim.notify(('[lsp] %s 沒有宣告 filetypes，略過'):format(name), vim.log.levels.WARN)
  else
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = filetypes,
      once = true, -- 查一次就好；PATH 不會在 session 中途改變
      desc = ('第一次開到 %s 時才檢查並啟用 %s'):format(table.concat(filetypes, '/'), name),
      callback = function()
        if vim.fn.executable(exe) == 1 then
          vim.lsp.enable(name)
        end
      end,
    })
  end
end

-- ---------------------------------------------------------------------
--  診斷訊息的顯示方式
--
--  ★ virtual_text 的 current_line = true 是關鍵：錯誤訊息只在游標所在的那一行
--    顯示。全開的話每一行錯誤後面都掛一段紅字，一個檔案有十個警告畫面就毀了；
--    全關的話你只看得到左邊一個小圖示，不知道是什麼問題。
--  ★ severity_sort：同一行有多個問題時，error 蓋過 warning，不會被 hint 擋住。
-- ---------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = { current_line = true },
  underline = true,
  severity_sort = true,
})

-- ★ 沒有自訂任何鍵位 —— nvim 0.11 起這些已經是內建預設鍵，全部走 g 前綴
--   (vim 規範裡本來就留給「跳到/取得」語意的字首)：
--       K      看說明(函式簽名、型別、文件)
--       grn    改名(整個專案的參照一起改)
--       gra    code action(自動修正)
--       grr    找所有引用      gri  找實作      grt  找型別定義
--       gO     列出這個檔案的所有符號(函式/變數大綱)
--       <C-s>  insert mode 下看參數提示
--   要確認 server 有沒有接上，用 :checkhealth vim.lsp。
