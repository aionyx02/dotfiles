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
-- heic、heif、hif：HEIF 格式的三個副檔名，mime-ext 的資料庫只收錄了 avif。
--   heic 是 iPhone 相簿的預設格式；hif 是 Canon、Fujifilm 相機產生的同一格式。
--   查不到時並非判斷錯誤，而是完全沒有類型：local.lua 會直接回傳
--   application/octet-stream（v26.5.6 的 local.lua:1113），previewer 因而落到
--   最後一條 { url = "*", run = "file" }，畫面只顯示檔案資訊而沒有圖片。
--
--   補上後不需安裝其他外掛，yazi 內建的 preset 已有
--     { mime = "image/{avif,hei?,jxl}", run = "magick" }
--   （previewers 與 preloaders 各一條），`hei?` 的 ? 比對一個字元。
--   該規則會呼叫 ImageMagick 7 的 magick.exe，本機 7.1.2-29 的 delegates
--   包含 heic（libheif 1.23.1），可以正常讀取。
--   注意：hei? 比對的是右側的 value 而非左側的 key，因此 value 必須寫成
--     image/heic 或 image/heif，不可寫成 image/x-heic 等。
--     hif 的 key 不符合 hei? 並無影響，其 value 為 image/heif。
--
--   不需處理大小寫：查表前會先 :lower()（local.lua:1105），.HEIC 同樣能比對。
--   remote:// 也不需另外設定：mime-ext.remote 查不到時會改呼叫 .local。
require("mime-ext.local"):setup {
	with_exts = {
		heic = "image/heic",
		heif = "image/heif",
		hif  = "image/heif",
	},
}
