# PowerShell profile

`profile.ps1` 由 PowerShell 5.1 與 7 **共用**——兩邊的 `$PROFILE` 都只是三行 bootstrap，dot-source 這一支。

> bootstrap 那兩支不在本 repo 管理範圍（它們在 OneDrive 同步範圍內）。內容見[根 README 的附錄](../README.md#附錄profile-bootstrap)。

**本檔必須存成 UTF-8 with BOM**，否則 5.1 會用 ANSI(Big5) 解讀中文註解而語法錯誤。

---

## 設計原則：開 shell 時不 spawn 任何外部程序

啟動速度是這支 profile 的核心約束。所有「需要 spawn 才拿得到」的東西都預先算好、存進 `~/.cache/pwsh-init/`，之後每次開 shell 只是讀檔 + dot-source。

| 原本的成本 | 怎麼處理 |
|---|---|
| `Get-Command` 第一次呼叫要掃整個 PATH 並建 command cache（實測 ~180ms） | 工具路徑解析一次就寫進 `tools.ps1` |
| `starship init powershell` 印出的東西自己又會再 spawn 一次 `--print-full-init` | 直接快取 full-init，省掉兩次 spawn |
| `Get-Item` 走 FileSystem provider，每次要建 PSObject 並做 ACL／reparse 檢查（四次檢查實測 ~144ms） | 改用 `[IO.File]::Exists` 等 .NET 靜態方法 |

**快取失效條件**：
- `tools.ps1`：快取檔不存在，或記錄的任一路徑已不存在 → 重新解析。所以「先開過 shell、之後才裝 zoxide」也會在下次開 shell 時自動修好。工具真的沒裝時，每次開 shell 都會重新解析一次（約 180ms），直到裝好為止。
- starship／zoxide 的初始化腳本：對應的 exe 比快取檔新，或快取檔不存在 → 自動重建。
**手動重建**：`Remove-Item ~/.cache/pwsh-init -Recurse`

---

## Starship：兩套配置自動切換

提示列的配置不是一份而是兩份，由本檔依終端機身分切換：

| 終端機 | `$env:STARSHIP_CONFIG` |
|---|---|
| JetBrains 系 IDE 的內嵌終端（`$env:TERMINAL_EMULATOR -eq 'JetBrains-JediTerm'`） | `~/.config/starship-tokyo-night-jetbrains.toml` |
| 其他（WezTerm 等） | `~/.config/starship-tokyo-night-user.toml` |

JediTerm 版比較精簡——IDE 內嵌終端寬度窄，段落太多會擠爆。

改配色時記得：`format` 裡的箭頭顏色要跟各段的 `bg` 同步，改一邊會出現色階斷層。

---

## 其他

- **PATH** — 本檔不修改 PATH。7-Zip（yazi 的壓縮檔預覽與 `ya pub extract` 都呼叫 `7z`）與 Sublime Text（`yazi.toml` 的 edit opener 設為 `subl`）的安裝程式不會自己加進 PATH，改由 `install.ps1` 寫進 User PATH（登錄檔），`-Verify` 會檢查。
- **zoxide** — `_ZO_EXCLUDE_DIRS` 排除掉 `$HOME`、各種 AppData、`C:\Windows` 與 OneDrive，避免資料庫被雜訊灌爆。
- **`sn`** — snippet 管理，dot-source `D:\Project\snippets\sn.ps1`（獨立 repo `aionyx02/snippets`，snippet 內容在該 repo 的 `data/`，不進 git）。檔案不存在就略過，所以沒 clone 也不會報錯。`SN_EDITOR=nvim` 讓它不跟著 `EDITOR`（Claude Code 設的 `subl -w`）走。
- **`y` 函式與 `yazi` 別名** — 啟動 yazi，離開（`q`）時 shell 自動 `cd` 到你最後所在的目錄。官方 `--cwd-file` 寫法。`Set-Alias yazi y` 讓直接打 `yazi` 也走這個函式（`yazi.exe` 是子行程，自己無法改變 shell 的目錄）；因此函式內部必須明確呼叫 `yazi.exe`，否則會遞迴呼叫自己。裡面兩個看似多餘的防禦都是踩過的坑：
  - `Test-Path` 檢查：在 yazi 裡把當前目錄刪掉再離開時，cwd-file 記的是已不存在的路徑
  - `finally` 區塊：yazi 執行中按 `Ctrl+C` 會中止整個函式，沒有它的話 `GetTempFileName()` 建的實體檔案會一直堆積在 `%TEMP%`
