-- =====================================================================
--  rust-analyzer：Rust（執行檔位於 ~\.cargo\bin）
--
--  只在 Cargo 專案中啟動（依 root_markers 判斷），開啟零散的 .rs 檔案時不會啟動；
--    它是這些 server 中最耗資源的一個。
-- =====================================================================

return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', 'rust-project.json' },
}
