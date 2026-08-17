-- =====================================================================
--  ruff — 你的 ~\.local\bin 裡本來就有，這裡只是接線
--
--  ★ ruff 不提供補全 —— 它是 linter + formatter，補全清單是空的。
--    Python 是兩隻 server 分工，兩隻都會掛在同一個 .py 上：
--        basedpyright(lsp/basedpyright.lua) → 補全、型別、跳定義、改名
--        ruff(這個檔案)                      → 沒用到的 import、shadow 掉的
--                                              變數、格式問題，以及 gra 一鍵修正
--    「不寫錯」的兩半：打字打對(basedpyright)、寫法沒問題(ruff)。
--
--  ★ 兩隻的診斷會有少量重疊(例如未使用的變數)，同一行出現兩個提示是正常的。
-- =====================================================================

return {
  cmd = { 'ruff', 'server' },
  filetypes = { 'python' },
  root_markers = { 'pyproject.toml', 'ruff.toml', '.ruff.toml', 'uv.lock', '.git' },
}
