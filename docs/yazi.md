# Yazi

`yazi.toml` 只留每個設定的結論與「改了會怎樣」；本檔記錄背後的調查與原始碼依據。

> **鍵位與操作在 [TUTORIAL.md](../home/.config/yazi/TUTORIAL.md)**。本檔只講 `yazi.toml` 的設定理由。

以下引用的原始碼位置皆以 **v26.5.6** 為準，升級後可能已改變。升級後請跑一次 `.\check.ps1`。

---

## 預覽品質（`[preview]`）

### 為什麼調高解析度與品質

WezTerm 使用 kitty graphics protocol，可顯示比預設更高的解析度。預設的 600x900 在本機螢幕上會被放大，quality 75 的壓縮痕跡在檢視照片時清晰可見。使用 toggle-pane（`T`）把預覽擴展成全寬時，`max_width` / `max_height` 就是實際的畫質上限。

### 為什麼不改 `image_filter = "lanczos3"`

畫質提升主要來自解析度（像素量約為預設的 3.5 倍）。lanczos3 只略微提升邊緣銳利度，濾波成本卻高出 3～5 倍（6-tap 對 2-tap），維持 triangle 最符合成本效益。

### 為什麼 `image_delay` 要跟著調高

官方定義為「送出圖片預覽資料前至少等待的毫秒數」，預設值 30 是針對 600x900、quality 75 所設。此處像素量為 3.5 倍、JPEG 品質 90，單張成本明顯較高。

Windows 預設的按鍵重複速率約每秒 30 次（每次約 33ms），剛好超過 30ms 的門檻。因此按住方向鍵捲動相簿時，幾乎每一格都會完整執行「解碼 → 縮放 → q90 編碼 → base64 → 寫入終端機」，畫面因而卡頓。

### `image_delay` 的上限是 100（官方文件沒寫）

超出範圍時 yazi 會顯示「Press <Enter> to continue with preset settings...」，並把**整組**使用者設定（包括 `keymap.toml`）退回預設值。症狀是所有自訂鍵位失效，而不是預覽異常，很難聯想到原因。

`check.ps1` 會偵測這個情況：設定正常時 `yazi --debug` 立即結束；任一值不合法時它會停在這個提示，不印出任何內容。

---

## 開啟方式（`[opener]`）

只覆寫 `edit`。其餘（open、play、reveal、extract、trash 等）沿用預設值，其中這幾個已由預設提供，不需自行設定：

| 動作 | 預設規則 | 作用 |
|---|---|---|
| reveal | `explorer /select,%s1` | 在檔案總管中選取 |
| extract | `ya pub extract` | 解壓縮（使用 7-Zip） |
| trash | `ya pub trash-restore` | 瀏覽與還原資源回收筒 |

### 為什麼 nvim 必須排在 `subl -w` 之後

清單第一條是 Enter 與 `o` 的預設開啟方式，nvim 排在最後，要按 `O` 從選單選。但順序不只影響選單：

批次重新命名（選取多個檔案後按 `r`）使用的是**第一條 `block = true` 的規則**，原始碼為 `YAZI.opener.block(&r)` → `.find(|r| r.block)`。若 nvim 排在前面，批次重新命名會改用 nvim 開啟，而 Enter 的行為不變，不易察覺。

nvim 必須設 `block = true`：它是 TUI，需要接管整個終端機。若比照 subl 設為 `orphan`，會在背景與 yazi 爭用同一個畫面。

### 為什麼 nvim 規則要寫 `if defined NVIM (ya emit open)`

問題：從 nvim 以 `\y`（yazi.nvim）開啟的 yazi 必定帶有 `--chooser-file`。此時按 `O` 選 nvim，會在 yazi 所在的浮動終端機裡再開一個 nvim，兩個 nvim 開同一個檔案會產生 swap 衝突（E325）。

原因：`open --interactive`（內建的 `O` 與本設定的 `` `o ``）在 chooser 模式下不會交回 chooser。`yazi-actor/src/mgr/open.rs` 的第一個判斷是：

```rust
if !opt.interactive && ARGS.chooser_file.is_some() { /* 交回 chooser */ }
```

interactive 模式不符合此條件，因此會實際執行 opener 規則。Enter 不受影響：它不是 interactive，一律交回 chooser。

解法：`NVIM` 是 nvim 注入給 pty job 的環境變數（值為 server pipe 位址），獨立執行的 yazi 沒有。在 nvim 中時改為執行 `ya emit open`，讓 yazi 再做一次**非** interactive 的 open，就會進入上面的 chooser 分支，效果等同按 Enter，由外層 nvim 開啟檔案。

不採用的做法與已知限制：

- **不用 `nvim --server %NVIM% --remote`**：`--remote` 會在目前視窗開檔，而目前視窗正是執行 yazi 的浮動視窗，檔案會蓋掉 yazi 的畫面。
- **限制**：在 nvim 中以 `:terminal` 執行 yazi（沒有 `--chooser-file`）時按 `O` 選 nvim，會改用第一條規則 subl 開啟。不會產生巢狀 nvim，是刻意的取捨。
- **`desc` 必須寫 `"nvim"`**：未設定時 yazi 取 `run` 的第一個字，選單會顯示 `if`。

---

## 外掛 fetcher（`[[plugin.prepend_fetchers]]`）

各外掛 README 中的 `id` 欄位只有 v26.1.22 以前需要，README 的寫法是舊版格式，此處一律省略。

### mime-ext：以副檔名判斷類型

取代讀取檔頭的 magic-byte 判斷。Windows 沒有 `file(1)`，改用副檔名資料庫可省去一輪 I/O，在 `\\wsl.localhost` 等較慢的路徑上差異尤其明顯。代價是副檔名與實際內容不符的少數檔案會被誤判。資料庫缺少的副檔名（heic、heif、hif）在 `init.lua` 補上。

### HEIF 副檔名（`init.lua` 的 `with_exts`）

mime-ext 的資料庫只收錄了 avif，沒有 heic、heif、hif（hif 是 Canon、Fujifilm 相機產生的同一格式）。查不到時並非判斷錯誤，而是完全沒有類型：`local.lua` 直接回傳 `application/octet-stream`（`local.lua:1113`），previewer 因而落到最後一條 `{ url = "*", run = "file" }`，畫面只顯示檔案資訊而沒有圖片。

補上後不需安裝其他外掛。yazi 內建的 preset 已有 `{ mime = "image/{avif,hei?,jxl}", run = "magick" }`（previewers 與 preloaders 各一條），`hei?` 的 `?` 比對一個字元。該規則呼叫 ImageMagick 7 的 `magick.exe`，本機 7.1.2-29 的 delegates 含 heic（libheif 1.23.1），可以正常讀取。

- `hei?` 比對的是右側的 **value** 而不是左側的 key，所以 value 必須寫成 `image/heic` 或 `image/heif`，不可寫成 `image/x-heic`。`hif` 這個 key 不符合 `hei?` 沒有影響，因為它的 value 是 `image/heif`。
- 不需處理大小寫：查表前會先 `:lower()`（`local.lua:1105`），`.HEIC` 同樣能比對。
- `remote://` 不需另外設定：`mime-ext.remote` 查不到時會改呼叫 `.local`。

### git：在檔案列表顯示狀態

以 linemode 顯示 modified、added、untracked、ignored。此 fetcher 是非同步的：進入目錄時檔案列表立即顯示，狀態圖示稍後才出現。在大型 repo 中最多只是圖示延遲，不會卡住瀏覽。

---

## 在 nvim 裡預覽圖片

由 nvim 那一側處理，見 `home/.config/nvim/lua/plugins/yazi.lua`。重點：nvim 的終端機不支援任何圖形協定，只能讓 yazi 改用 chafa；但 nvim 的 job 會繼承 WezTerm 的 `TERM_PROGRAM`、`WEZTERM_*`，yazi 會因此誤判自己在 WezTerm 中、送出被丟棄的圖片資料。所以除了安裝 chafa，還要在啟動 yazi 時暫時移除這些變數。
