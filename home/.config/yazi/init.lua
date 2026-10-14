-- =====================================================================
--  Yazi 外掛初始化
--  只列出需要呼叫 setup() 的外掛。
--  smart-enter、smart-filter、smart-paste、toggle-pane 皆由按鍵觸發，
--  不需要初始化，也沒有常駐成本。
-- =====================================================================

-- git：在 linemode 顯示檔案的 git 狀態。
-- order 決定狀態符號在 linemode 中的排列位置，1500 為 README 的建議值。
require("git"):setup {
	order = 1500,
}

-- mime-ext：維持預設行為（僅依副檔名資料庫判斷，不改用 file(1)），
-- 這正符合 Windows 的需求，本機也沒有 file(1) 可用。
-- 此處只補上資料庫缺少的副檔名。
--
-- heic、heif、hif：HEIF 格式（iPhone 相簿；Canon、Fujifilm 相機的 .hif），
--   資料庫只收錄了 avif。查不到時檔案完全沒有類型，預覽只會顯示檔案資訊。
--   補上後由 yazi 內建的 image/{avif,hei?,jxl} → magick 規則預覽，不需其他外掛。
--   value 必須是 image/heic 或 image/heif：hei? 比對的是 value，不是 key。
--   大小寫與 remote:// 都不需另外處理。原始碼依據見 docs/yazi.md。
require("mime-ext.local"):setup {
	with_exts = {
		heic = "image/heic",
		heif = "image/heif",
		hif  = "image/heif",
	},
}
