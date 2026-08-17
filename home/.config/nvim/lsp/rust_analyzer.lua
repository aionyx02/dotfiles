-- =====================================================================
--  rust-analyzer — 你的 ~\.cargo\bin 裡本來就有，這裡只是接線
--
--  ★ 只在 Cargo 專案裡啟動(靠 root_markers 判斷)，隨手開一個 .rs 片段
--    不會叫醒它 —— 它是這幾隻裡最吃資源的，這樣分界剛好。
-- =====================================================================

return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', 'rust-project.json' },
}
