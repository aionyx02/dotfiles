-- =====================================================================
--  Yazi 外掛初始化
--  只有需要 setup() 的外掛才列在這裡。
--  smart-enter / smart-filter / smart-paste / toggle-pane 都是純按鍵觸發，
--  不需要初始化，也不會產生任何常駐成本。
-- =====================================================================

-- git：在 linemode 顯示檔案的 git 狀態。
-- order 決定狀態符號在 linemode 裡的排序位置，1500 是 README 建議值。
require("git"):setup {
	order = 1500,
}

-- mime-ext：維持預設行為(純副檔名資料庫、不 fallback 到 file(1)) —
-- 正好是 Windows 上想要的，這台機器本來就沒有 file(1) 可以 fallback。
-- 只補資料庫缺的副檔名。
--
-- ★ heic / heif / hif：HEIF 家族的三個副檔名，mime-ext 的資料庫只收了 avif、三個全漏。
--   heic 是 iPhone 相簿的預設格式；hif 是 Canon / Fujifilm 相機寫出來的同一種東西。
--   漏掉的代價不是「猜錯類型」而是「完全沒有類型」：查不到時 local.lua 直接回
--   application/octet-stream(v26.5.6 的 local.lua:1113)，於是 previewer 一路落到
--   最後一條 { url = "*", run = "file" }，畫面上只剩檔案資訊、沒有圖。
--
--   補上之後不需要裝任何外掛 — yazi 內建的 preset 早就有
--     { mime = "image/{avif,hei?,jxl}", run = "magick" }
--   這條(previewers 和 preloaders 各一)，`hei?` 的 ? 正好各吃一個字元。
--   它背後呼叫 ImageMagick 7 的 magick.exe，本機 7.1.2-29 的 delegates
--   有 heic(libheif 1.23.1)，讀得動。
--   → hei? 比對的是「右邊的 value」不是左邊的 key，所以 value 一定要寫成
--     image/heic 或 image/heif，別寫成 image/x-heic 之類。
--     hif 的 key 對不上 hei? 完全沒關係 — 它的 value 是 image/heif。
--
--   大小寫不必處理：查表前有 :lower()(local.lua:1105)，.HEIC 一樣命中。
--   remote:// 也不必另外設定：mime-ext.remote 查不到時會轉呼叫 .local。
require("mime-ext.local"):setup {
	with_exts = {
		heic = "image/heic",
		heif = "image/heif",
		hif  = "image/heif",
	},
}
