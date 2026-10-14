-- =====================================================================
--  LSP 啟用設定：各 server 的設定位於 nvim/lsp/<名稱>.lua，本檔只決定啟用哪些
--
--  不使用 nvim-lspconfig。nvim 0.11 起，讀取 lsp/<名稱>.lua、依 filetype 啟動、
--    依 root_markers 尋找專案根目錄等功能皆已內建，該套件僅剩提供預設值的作用。
--    本設定只用少數幾個 server，自行撰寫比多一個相依套件（上限 6 個）更划算。
--
--  補全功能位於 lua/completion.lua，該檔同時處理有 LSP 與無 LSP 的情況；
--    本檔只負責啟動 server。
-- =====================================================================

-- server 名稱與其執行檔。找不到執行檔時略過，不會在啟動時報錯。
-- 此檢查的必要性：這是全域設定，會套用在每台機器與每個專案上；
--   若直接啟用不存在的 server，每次開啟對應類型的檔案時 nvim 都會報錯。
local servers = {
  lua_ls = 'lua-language-server',           -- .lua  設定檔（nvim、wezterm）
  clangd = 'clangd',                        -- .c .cpp .h .hpp
  basedpyright = 'basedpyright-langserver', -- .py   補全與型別檢查
  ruff = 'ruff',                            -- .py   lint 與格式化（與 basedpyright 分工）
  rust_analyzer = 'rust-analyzer',          -- .rs   僅在 Cargo 專案中啟動
}

-- ---------------------------------------------------------------------
--  延遲到首次開啟對應檔案類型時才檢查執行檔
--
--  `vim.fn.executable()` 在本機很慢（PATH 很長，且 nvim 不快取結果），
--    啟動時檢查全部 server 會佔掉約兩成的啟動時間，
--    而開啟 git commit 訊息或 .txt 時這些查詢完全用不到。
--    因此改為每種語言第一次開檔時才檢查（once = true）。
--
--  不會遺漏已開啟的 buffer：vim.lsp.enable() 會自動補接，不需要自行補觸發。
--  filetypes 直接從 lsp/<名稱>.lua 讀取，不在此重複定義，避免兩份清單不一致。
--  實測數據與原始碼依據：docs/nvim.md。
-- ---------------------------------------------------------------------
local group = vim.api.nvim_create_augroup('lsp-lazy-enable', { clear = true })

for name, exe in pairs(servers) do
  local ok, cfg = pcall(function() return vim.lsp.config[name] end)
  local filetypes = ok and cfg and cfg.filetypes

  if not filetypes then
    -- 缺少 filetypes 時 autocmd 的 pattern 會變成 '*'，開啟任何檔案都會觸發；
    -- 因此明確提示並略過該 server，避免退化為全域觸發。
    vim.notify(('[lsp] %s 沒有宣告 filetypes，略過'):format(name), vim.log.levels.WARN)
  else
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = filetypes,
      once = true, -- 只需檢查一次，PATH 不會在 session 中途改變
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
--  virtual_text 設定 current_line = true：只在游標所在行顯示錯誤訊息。
--    全部顯示時每一行錯誤後都會附加訊息，警告一多畫面就難以閱讀；
--    全部關閉則只剩左側的小圖示，看不出問題內容。
--  severity_sort：同一行有多個問題時，依嚴重程度排序，error 優先於 warning 與 hint。
-- ---------------------------------------------------------------------
vim.diagnostic.config({
  virtual_text = { current_line = true },
  underline = true,
  severity_sort = true,
})

-- 未自訂任何 LSP 鍵位：nvim 0.11 起已內建以下預設鍵位，皆使用 g 前綴
--   （vim 慣例中用於「跳至」與「取得」的前綴）：
--       K      顯示說明（函式簽名、型別、文件）
--       grn    重新命名（同步修改整個專案的參照）
--       gra    code action（自動修正）
--       grr    尋找所有參照    gri  尋找實作    grt  尋找型別定義
--       gO     列出目前檔案的所有符號（函式、變數大綱）
--       <C-s>  在 insert 模式中顯示參數提示
--   確認 server 是否已連線：:checkhealth vim.lsp
