# WezTerm Keymap

本檔對應 `wezterm.lua`，並以 `wezterm show-keys` 驗證實際生效的鍵位。

- WezTerm 版本：`20260715-174104-3658b656`
- 設定檔**沒有**設 `disable_default_key_bindings`，所以內建預設鍵位**全部保留**，自訂鍵位是疊加上去的。
- 沒有設 Leader key，全部都是直接組合鍵。

**圖例**

| 標記 | 意義 |
|---|---|
| ★ | `wezterm.lua` 裡明確寫的（部分與內建預設重複，屬刻意固定） |
| （無標記） | WezTerm 內建預設，本檔未動 |

---

## 1. 分屏 Pane

| 鍵位 | 動作 | |
|---|---|---|
| `Alt` `Shift` `\|` | 左右並排切分（直線 = 中間一條直的分隔線） | ★ |
| `Alt` `Shift` `\` | 同上（不用按 Shift 打 `\|` 的備用鍵） | ★ |
| `Alt` `Shift` `-` | 上下堆疊切分 | ★ |
| `Alt` `Shift` `_` | 同上 | ★ |
| `Ctrl` `Shift` `Alt` `%` | 左右並排切分 | |
| `Ctrl` `Shift` `Alt` `"` | 上下堆疊切分 | |
| `Alt` `H` / `J` / `K` / `L` | 切換到 左 / 下 / 上 / 右 的分屏 | ★ |
| `Alt` `←` `↓` `↑` `→` | 同上（方向鍵版） | ★ |
| `Ctrl` `Shift` `←` `↓` `↑` `→` | 同上 | |
| `Alt` `Shift` `H` `J` `K` `L` | 調整分屏大小（每次 4 格） | ★ |
| `Ctrl` `Shift` `Alt` `←` `↓` `↑` `→` | 調整分屏大小（每次 1 格，微調用） | |
| `Alt` `Z` | 目前分屏放大 / 還原（Zoom 全屏獨占） | ★ |
| `Ctrl` `Shift` `Z` | 同上 | |
| `Alt` `W` | 關閉目前分屏（**不確認、直接關**） | ★ |
| `Ctrl` `Shift` `Space` | 分屏標號跳轉：跳出大字母，按 `a s d f g h j k l` 瞬移 | ★ |

> 非焦點的分屏會被壓暗（`inactive_pane_hsb`：飽和 0.65 / 亮度 0.42），當前分屏像聚光燈。

---

## 2. 分頁 Tab

| 鍵位 | 動作 | |
|---|---|---|
| `Ctrl` `Shift` `T` | 開新分頁（沿用當前 domain） | ★ |
| `Ctrl` `Shift` `W` | 關閉目前分頁（**不確認、直接關**） | ★ |
| `Ctrl` `Tab` | 下一個分頁 | ★ |
| `Ctrl` `Shift` `Tab` | 上一個分頁 | ★ |
| `Alt` `]` | 下一個分頁 | ★ |
| `Alt` `[` | 上一個分頁 | ★ |
| `Ctrl` `1` ~ `Ctrl` `8` | 直接跳到第 1~8 個分頁 | ★ |
| `Ctrl` `9` | 跳到**最後一個**分頁 | ★ |
| `Ctrl` `Shift` `1` ~ `9` | 同上（內建預設也吃這組） | |
| `Ctrl` `PageUp` / `PageDown` | 上一個 / 下一個分頁 | |
| `Ctrl` `Shift` `PageUp` / `PageDown` | **搬移**目前分頁的位置（往前 / 往後） | |

---

## 3. 複製 / 貼上

| 鍵位 | 動作 | |
|---|---|---|
| `Ctrl` `C` | **智慧鍵**：有反白選取 → 複製；沒選取 → 把 `Ctrl+C` 傳給 shell 中斷程式 | ★ |
| `Ctrl` `V` | 貼上（由 WezTerm 直接送文字，避免前景 CLI 誤判成「貼上圖片」） | ★ |
| `Ctrl` `Shift` `C` | 複製 | ★ |
| `Ctrl` `Shift` `V` | 貼上 | ★ |
| `Ctrl` `Insert` | 複製 | ★ |
| `Shift` `Insert` | 貼上 | ★ |

> ⚠️ `Ctrl+V` 是無條件把剪貼簿**文字**送進前景程式。在 yazi / vim 這類把每個字元都當按鍵解讀的 TUI 裡，貼含 `:` 的路徑會被當成指令輸入。要在特定 TUI 例外處理，請照 `copy_selection_or_interrupt` 的寫法用 `action_callback` 判斷前景行程，不要直接改成無條件 `SendKey`。

---

## 4. 搜尋與 Copy Mode

| 鍵位 | 動作 | |
|---|---|---|
| `Ctrl` `Shift` `F` | 搜尋 scrollback（以目前選取字串當初始關鍵字） | |
| `Ctrl` `Shift` `X` | 進入 Copy Mode（Vim 式鍵盤選取） | |
| `Ctrl` `Shift` `K` | 清空 scrollback（保留 20000 行緩衝） | |
| `Ctrl` `Shift` `U` | 字元 / Emoji 選擇器 | |

---

## 5. 視窗 / 外觀 / 系統

| 鍵位 | 動作 | |
|---|---|---|
| `Ctrl` `Shift` `P` | 指令面板（找不到快捷鍵時從這裡翻） | ★ |
| `Ctrl` `Shift` `B` | **透明度即時切換**：`0.90`（玻璃）⇄ `1.0`（實色），不需重載設定 | ★ |
| `Alt` `Enter` | 全螢幕切換 | |
| `Ctrl` `Shift` `N` | 開新視窗 | |
| `Ctrl` `Shift` `M` | 最小化視窗 | |
| `Ctrl` `Shift` `R` | 重新載入設定檔 | |
| `Ctrl` `Shift` `L` | 除錯 Overlay（Lua REPL + 錯誤訊息） | |
| `Ctrl` `-` / `Ctrl` `=` | 字級縮小 / 放大 | |
| `Ctrl` `0` | 字級還原（回 11.5） | |
| `Shift` `PageUp` / `PageDown` | 上下捲動一頁 | |

> `Ctrl+Shift+B` 用來自測「透明視窗是否造成打字延遲」：透明視窗每一幀都要 DWM 合成整個視窗。兩邊各打幾行字比一比，有感就是取捨，沒感就能排除這條嫌疑。

---

## 6. 滑鼠

| 操作 | 動作 | |
|---|---|---|
| 左鍵拖曳 → 放開 | **選取即自動複製**到系統剪貼簿；若停在連結上則開啟連結 | ★ |
| `Ctrl` + 左鍵放開 | 開啟游標下的連結 | ★ |
| `Ctrl` + 左鍵按下 | 不做事（避免與上面那條打架） | ★ |
| 左鍵雙擊 / 三擊 | 選取一個字 / 整行 | |
| `Alt` + 左鍵拖曳 | 區塊（矩形）選取 | |
| `Shift` + 左鍵 | 延伸現有選取範圍 | |
| `Ctrl` `Shift` + 左鍵拖曳 | 拖曳搬移整個視窗 | |
| 滾輪 | 捲動 scrollback | |

---

## 7. Copy Mode 鍵表（`Ctrl+Shift+X` 進入）

**移動**

| 鍵 | 動作 |
|---|---|
| `h` `j` `k` `l` / 方向鍵 | 左下上右 |
| `w` / `b` / `e` | 下一個字首 / 上一個字首 / 字尾 |
| `0` / `^` / `$` | 行首 / 行首第一個非空白 / 行尾 |
| `H` / `M` / `L` | 跳到視窗頂 / 中 / 底 |
| `g` / `G` | 跳到 scrollback 最頂 / 最底 |
| `Ctrl` `b` / `Ctrl` `f` | 上一頁 / 下一頁 |
| `Ctrl` `u` / `Ctrl` `d` | 上半頁 / 下半頁 |
| `f` / `F` / `t` / `T` | 跳到指定字元（前 / 後，含 / 不含該字元） |
| `;` / `,` | 重複上次跳字 / 反向重複 |

**選取與離開**

| 鍵 | 動作 |
|---|---|
| `v` / `Space` | 開始逐字元選取 |
| `V` | 整行選取 |
| `Ctrl` `v` | 區塊（矩形）選取 |
| `o` / `O` | 跳到選取範圍的另一端 / 另一端（水平） |
| `y` | 複製並離開 Copy Mode |
| `q` / `Esc` / `Ctrl` `c` / `Ctrl` `g` | 離開 Copy Mode |

---

## 8. Search Mode 鍵表（`Ctrl+Shift+F` 進入）

| 鍵 | 動作 |
|---|---|
| `Enter` / `Ctrl` `p` / `↑` | 上一個符合 |
| `Ctrl` `n` / `↓` | 下一個符合 |
| `PageUp` / `PageDown` | 上一頁 / 下一頁的符合結果 |
| `Ctrl` `r` | 切換比對模式（純文字 ⇄ 正則） |
| `Ctrl` `u` | 清空搜尋字串 |
| `Esc` | 離開搜尋 |

---

## 9. 注意事項與已知衝突

- **`Ctrl+Shift+Space` 撞鍵**：設定檔綁 `PaneSelect`（分屏標號跳轉），WezTerm 內建同一組鍵是 `QuickSelect`（快速選連結/雜湊值）。兩者同時登記在鍵表裡，內建那條是以「實體鍵位」註冊的。若哪天發現按下去跑的是 QuickSelect，就把設定檔那行改成 `key = 'phys:Space'` 來明確蓋掉；QuickSelect 平時可從指令面板呼叫。
- **關閉不會問你**：`Alt+W`（關分屏）、`Ctrl+Shift+W`（關分頁）都是 `confirm = false`，加上 `window_close_confirmation = 'NeverPrompt'`，全程沒有「確定要關閉嗎」。手滑就沒了。
- **`Ctrl+C` 的語意**：有選取時**不會**送中斷訊號。程式跑不停又剛好有反白時，先按 `Esc` 或點一下空白處清掉選取，再按 `Ctrl+C`。
- **`Alt+H/J/K/L` vs `Alt+Shift+H/J/K/L`**：前者是「移動焦點」，後者是「改變大小」，只差一個 Shift，肌肉記憶要分清楚。
- **中鍵貼上**：內建綁的是 PrimarySelection（X11 概念），Windows 上沒有這個緩衝區，所以中鍵基本上等於沒作用。

---

## 10. 非鍵盤但常用

- **Launch Menu**（`Ctrl+Shift+P` → 搜尋 "Launch"，或點分頁列）可切換：
  - PowerShell 7（預設，已強制 UTF-8）
  - Windows PowerShell 5.1
  - Ubuntu (WSL)
  - CMD（`chcp 65001`）
- 分頁標題會依前景行程自動換圖示（pwsh / bash / nvim / node / python / cargo / docker / git / ssh / go…），WSL 分頁一律顯示為 `Ubuntu`。
