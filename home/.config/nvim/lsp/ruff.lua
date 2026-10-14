-- =====================================================================
--  ruff：Python 的 lint 與格式化（執行檔位於 ~\.local\bin）
--
--  ruff 是 linter 與 formatter，不提供補全。
--    Python 由兩個 server 分工，兩者同時連接同一個 .py 檔案：
--        basedpyright（lsp/basedpyright.lua）：補全、型別檢查、跳至定義、重新命名
--        ruff（本檔）                       ：未使用的 import、遮蔽的變數、格式問題，
--                                              以及透過 gra 自動修正
--
--  兩者的診斷有少量重疊（例如未使用的變數），同一行出現兩個提示屬正常現象。
-- =====================================================================

return {
  cmd = { 'ruff', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', 'uv.lock', '.git' },

  -- 只輸出錯誤（預設為 info）。理由同 clangd 的 --log=error：
  --   nvim 會把 server 的 stderr 一律記成 ERROR，lsp.log 會塞滿假錯誤。
  init_options = { settings = { logLevel = 'error' } },
}
