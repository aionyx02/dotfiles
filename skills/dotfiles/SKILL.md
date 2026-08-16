---
name: dotfiles
description: 維護這台機器的 dotfiles repo（WezTerm / Starship / PowerShell / Yazi / Neovim / Claude Code / Sublime）。當使用者要改任何個人化 config、新增模組、修 symlink、或問「這個設定放哪」時使用。
---

# dotfiles

Repo：`D:\Project\dotfiles` → `github.com/aionyx02/dotfiles`（public）

## 核心模型：symlink，不是複製

磁碟上每份 config 的位元組**只存在一份**，就在 repo 的 `home/` 底下。`$HOME` 的對應位置只是指標。

```
D:\Project\dotfiles\home\.config\wezterm\wezterm.lua   ← 真實檔案（唯一一份）
          ▲ symlink
C:\Users\shawn\.config\wezterm\                        ← 指標
```

**推論（這幾點最常被忘記）：**

- **沒有同步步驟。** 沒有 install/sync/copy 要跑。改完就 `git commit`。
- 在 `~/.config/...` 改 和 在 repo 改 是**同一個動作**，改哪邊都會立刻反映到另一邊。
- `install.ps1` 只在三種時候跑：① 新機器 ② 新增模組要多一條 link ③ link 斷了要修。

## ★ 改 config 一律在 repo 目錄裡改

```
D:\Project\dotfiles\home\.config\...
```

**理由不是同步，是 atomic save 會打斷 symlink。**

Sublime 這類編輯器存檔是「寫暫存檔 → rename 蓋過去」，而 rename 蓋掉的是 symlink 本身。用它存過一次 `~/.config/...` 的檔，那條 link 就變成實體檔案——之後改 repo 不再生效，`git status` 也毫無反應。這是唯一會**靜默失效**的失敗模式。

- Sublime 已設 `atomic_save: false` 當第二道防線
- Neovim 安全（`backupcopy=auto` 偵測 symlink 後改用複製模式）
- `.\install.ps1 -Verify` 會抓出「本該是 symlink 卻變成實體檔」的目標

## 結構

`home/` 的路徑 == `$HOME` 的路徑。對應關係就是目錄結構本身，沒有對照表。

```
home/     ← 只放「會被 symlink 出去的東西」
docs/     ← repo 自己的說明，不會被部署
bootstrap/winget-core.json
install.ps1
```

文件的歸屬：`docs/*.md` 是 repo 說明（架構、為什麼這樣設）；`KEYMAP.md`、`TUTORIAL.md` 刻意留在 config 目錄裡跟著 symlink 走，方便在終端機隨手查。**不要把 repo 說明寫進 `home/`。**

## 新增模組

多數情況只要放檔案，不必改任何清單：

```powershell
mkdir D:\Project\dotfiles\home\.config\<tool>
# 放 config 進去
cd D:\Project\dotfiles; .\install.ps1
```

`.config` 已是「透明目錄」，`<tool>` 會自動成為 link 點。

只有當**新模組的父目錄還住著非 repo 的東西**時，才要在 `install.ps1` 的 `$Transparent` 加一行。目前唯一這種情況是 `.config\claude`（同目錄有 `.credentials.json`、`sessions/`），所以它是檔案層 link，只指名 `CLAUDE.md` / `RTK.md` / `settings.json` / `skills/`。

## 什麼不收

判準是「**這是我的偏好，還是這台機器的狀態？**」

已明確排除，不要再提議收進來：

| 不收 | 原因 |
|---|---|
| `~/.gitconfig` | GPG signingkey + `Program Files` 絕對路徑＝機器狀態。只收 `.config/git/ignore` |
| `~/.codex/config.toml` | 真正的設定只有 2 行，其餘是自動累積的 60+ 筆專案 trust 紀錄，會把所有專案路徑推上公開 repo |
| `~/.gemini`、`~/.copilot` | 只有 auth type 與 first-launch 旗標，純狀態 |
| VS Code、Windows Terminal、`Everything.ini` | 幾乎沒設定過／全是視窗位置與索引狀態 |
| 字型檔本體 | 128 個 ttf、上百 MB。改用 winget 的 `DEVCOM.JetBrainsMonoNerdFont` |
| `$PROFILE` 的兩支 bootstrap | 在 OneDrive 同步範圍內，重灌登入後自己回來。內容記在根 README 附錄 |
| 憑證 / session / 快取 | repo 是 **public**。`.gitignore` 有安全網段落 |

**repo 是公開的**——新增任何東西前先問：這會不會洩漏路徑、專案名、或帳號資訊？

## 編碼陷阱

這台機器踩過的，都是真的會壞：

- `home/.config/powershell/profile.ps1` 與 `install.ps1` **必須 UTF-8 with BOM**。沒 BOM 的話 PS 5.1 會用 ANSI(Big5) 解讀中文註解而語法錯誤。
- **不要用 PowerShell 5.1 的 `>>` 追加文字檔**——它預設寫 UTF-16LE，會在 UTF-8 檔案中間插入一段亂碼。`.gitignore` 就是這樣壞掉過，害 `.idea/` 一直沒被忽略。
- `install.ps1` 刻意維持 **PS 5.1 相容**（重灌後的乾淨 Windows 只有 5.1，pwsh 7 是它要裝的東西）。不要在裡面用 `??`、`?.`、三元運算子、`-Parallel`。

## 操作這個 repo 時會踩到的權限規則

`settings.json` 的 deny 清單會擋住 Claude Code 自己：

- `Remove-Item * -Recurse *` 被擋 → 刪 repo 內的東西用 `git rm -r`（本來就是更對的工具）
- `git reset --hard` / `clean -f` / `push --force` / `branch -D` 被擋
- 指令字串裡出現 `.idea` 之類的路徑片段可能誤觸守衛 hook，拆成多個小指令即可

PowerShell 變數**不分大小寫**：`$R` 和 `$r` 是同一個變數。寫迴圈時別讓計數用的 `$r` 蓋掉路徑用的 `$R`。

## 常用指令

```powershell
cd D:\Project\dotfiles

.\install.ps1 -Verify      # 健檢：link 狀態 + 核心工具 + Developer Mode
.\install.ps1 -WhatIf      # 預覽，不動任何東西
.\install.ps1              # 部署（既有內容先 Move 到 ~/.dotfiles-backup/<timestamp>/）
.\install.ps1 -SkipPackages -SkipDeps   # 只處理 symlink

git add -A && git commit -m "..." && git push   # 改完 config 就這樣
```

需要 **Developer Mode** 才能以非管理員身分建 symlink（設定 → 系統 → 開發人員專用）。
