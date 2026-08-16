# dotfiles

> Windows 個人化配置 · WezTerm + Starship + PowerShell + Yazi + Neovim + Claude Code + Sublime Text

用 **symlink** 部署。磁碟上每份 config 的位元組只存在一份，就在這個 repo 裡；`$HOME` 底下的對應位置只是指標。

所以「改 config」和「改 repo」是同一件事——**沒有同步指令，也不可能漂移**。

---

## 架構

```
D:\Project\dotfiles\home\.config\wezterm\wezterm.lua   ← 真實檔案（唯一一份）
          ▲
          │  symlink
          │
C:\Users\shawn\.config\wezterm\                        ← 不是資料夾，是指標
```

`home/` 底下的路徑就是 `$HOME` 底下的路徑。**對應關係即目錄結構本身**，沒有另外一張要維護的對照表。

```
dotfiles/
├─ home/                          ← 結構 == $HOME 結構
│  │                                 ★ 只放「會被 symlink 出去的東西」，本 repo 的文件不放這裡
│  ├─ .config/
│  │  ├─ wezterm/                 wezterm.lua · KEYMAP.md
│  │  ├─ nvim/                    init.lua · lua/ · TUTORIAL.md
│  │  ├─ yazi/                    yazi/keymap/theme.toml · flavors/ · plugins/ · TUTORIAL.md
│  │  ├─ powershell/              profile.ps1（5.1 與 7 共用）
│  │  ├─ git/                     ignore
│  │  ├─ ccstatusline/            settings.json
│  │  ├─ claude/                  CLAUDE.md · RTK.md · settings.json · skills/
│  │  └─ starship-tokyo-night-{user,jetbrains}.toml
│  └─ AppData/Roaming/Sublime Text/Packages/User/
├─ docs/                          ← repo 自己的模組說明（不會被部署出去）
├─ skills/dotfiles/               ← 本 repo 的維護規則。專案專用，不進全域 skills
├─ bootstrap/
│  └─ winget-core.json            重灌時要裝的 17 個套件
├─ install.ps1                    部署 / 健檢
└─ README.md
```

`KEYMAP.md` 與 `TUTORIAL.md` 是例外——它們是隨身文件，刻意跟著 config 一起被 symlink 到 live 端，這樣在終端機裡隨手就查得到。repo 自身的說明（架構、為什麼這樣設）放 `docs/`。

---

## 快速開始（重灌後）

```powershell
# 0. 先開 Developer Mode：設定 → 系統 → 開發人員專用
#    （否則非管理員無法建立 symlink）

git clone https://github.com/aionyx02/dotfiles D:\Project\dotfiles
cd D:\Project\dotfiles

.\install.ps1 -WhatIf     # 先看它打算做什麼
.\install.ps1             # 真的執行
.\install.ps1 -Verify     # 開新視窗後確認全綠
```

`install.ps1` 分三階段，後兩階段**寬容失敗**（單項失敗只警告，不中斷）：

| 階段 | 做什麼 | 失敗的後果 |
|---|---|---|
| 1 | 建立 14 條 symlink，既有內容先 **Move**（不是複製、不是刪）到 `~/.dotfiles-backup/<timestamp>/` | 中斷——這是核心 |
| 2 | `winget` 裝 `bootstrap/winget-core.json` 的 17 個套件 | 該工具不可用，其餘照常 |
| 3 | `npm i -g ccstatusline`、`cargo install --git .../rtk` | Claude Code 的狀態列與 hook 失效，終端機本身不受影響 |

腳本**冪等**：重跑時已正確的 link 直接跳過。它刻意維持 PowerShell 5.1 相容，因為重灌後的乾淨 Windows 只有 5.1（pwsh 7 正是它要裝的東西之一）。

---

## ★ 日常維護

### 改 config 請在 **repo 目錄裡**改

```
D:\Project\dotfiles\home\.config\...     ← 改這裡
```

不是因為需要同步（不需要），而是因為有些編輯器會**打斷 symlink**：

Sublime Text 這類編輯器的「原子存檔」是寫暫存檔再 rename 蓋過去，而 rename 蓋掉的是 **symlink 本身**、不是它指向的目標。只要用它存過一次 `~/.config/...` 底下的檔，那條 link 就會被默默換成實體檔案——之後在 repo 裡改再也不會生效，`git status` 也毫無反應。這是唯一會**靜默失效**的失敗模式。

- 本 repo 的 Sublime 設定已加上 `"atomic_save": false` 當第二道防線
- Neovim 沒有這個問題（`backupcopy=auto` 會偵測 symlink 並改用複製模式）
- `install.ps1 -Verify` 會抓出「本該是 symlink 卻變成實體檔」的目標

### 改完之後

```powershell
cd D:\Project\dotfiles
git add -A && git commit -m "..." && git push
```

就這樣。**不需要任何 install / sync / copy 指令。**

### `install.ps1` 只在三種時候跑

1. 新機器 / 重灌後第一次部署
2. 新增了一個模組，需要多一條 link
3. 某條 link 斷了要修

---

## 新增一個模組

多數情況下**只要放檔案**：

```powershell
# 例：加入 bat 的設定
mkdir D:\Project\dotfiles\home\.config\bat
# ... 把 config 放進去 ...
cd D:\Project\dotfiles; .\install.ps1
```

`.config` 已經是「透明目錄」，所以 `bat` 會自動成為一個新的 link 點，不必改任何清單。

只有當**新模組的父目錄還住著不屬於這個 repo 的東西**時，才需要在 `install.ps1` 的 `$Transparent` 加一行——例如 `~/.config/claude/` 底下有 `.credentials.json` 與 sessions，所以它是透明的，只有指名的 4 個項目會被 link。

---

## 模組

| 模組 | 說明 | 文件 |
|---|---|---|
| **WezTerm** | 恆定通透玻璃、圓角膠囊分頁、Tmux 式分屏、UTF-8 中文鎮壓 | [設定說明](docs/wezterm.md) · [完整鍵表](home/.config/wezterm/KEYMAP.md) |
| **Starship** | Tokyo Night 提示列，依終端機自動切換兩套配置 | [見 PowerShell](docs/powershell.md#starship兩套配置自動切換) |
| **PowerShell** | 5.1 與 7 共用的 profile，快取式啟動（不 spawn 外部程序） | [說明](docs/powershell.md) |
| **Yazi** | 檔案管理器，含 tokyo-night flavor 與 9 個 plugin | [實戰手冊](home/.config/yazi/TUTORIAL.md) |
| **Neovim** | `vim.pack` 管理，fzf-lua / gitsigns / yazi 整合 | [入門手冊](home/.config/nvim/TUTORIAL.md) |
| **Claude Code** | 全域指示、權限規則、狀態列、40+ skills | [說明](docs/claude.md) |
| **ccstatusline** | Claude Code 的狀態列外觀 | [見 Claude Code](docs/claude.md) |
| **Sublime Text** | 自製 Tokyo Night 配色（與 wezterm 同步）、C++17 build | [說明](docs/sublime.md) |
| **Git** | 全域 ignore | — |

### 這裡**不**收什麼

| 不收 | 原因 |
|---|---|
| `~/.gitconfig` | 含 GPG signingkey 與 `Program Files` 絕對路徑，是「這台機器的真相」而非「你的偏好」 |
| `~/.codex/config.toml` | 7 KB 裡真正的設定只有 2 行，其餘是自動累積的 60+ 筆專案 trust 紀錄，會把所有專案路徑推上公開 repo |
| `~/.gemini`、`~/.copilot` | 內容只有 auth type 與 first-launch 旗標，純狀態、零個人化 |
| VS Code、Windows Terminal | 幾乎沒設定過；VS Code 另有內建 Settings Sync |
| `Everything.ini` | 20 KB 全是視窗位置與索引狀態 |
| 憑證、session、快取 | 見 `.gitignore` 的「安全網」段 |
| 字型檔本體 | 128 個 ttf、上百 MB；改由 winget 的 `DEVCOM.JetBrainsMonoNerdFont` 安裝 |

`$PROFILE` 的兩支 bootstrap（`Documents\PowerShell\` 與 `Documents\WindowsPowerShell\`）也不在此管理——它們在 OneDrive 同步範圍內，重灌登入後會自己回來。內容見下方附錄。

---

## 疑難排解

| 症狀 | 原因與處置 |
|---|---|
| `install.ps1` 說無法建立 symlink | Developer Mode 沒開，或不是管理員。設定 → 系統 → 開發人員專用 |
| 某個項目「失敗」 | 多半是檔案正被程式開著（wezterm / Claude Code）。關掉後重跑即可，腳本冪等 |
| 改了 repo 但沒生效 | 跑 `-Verify`。多半是那條 link 被原子存檔打斷了，重跑 `install.ps1` 修復 |
| 想找回舊版本 | 全在 git history。Catppuccin 版：`git show a76c5b2:wezterm/wezterm.lua` |
| 想找回 install 覆蓋掉的東西 | `~/.dotfiles-backup/<timestamp>/`，原目錄結構完整保留 |

---

## 附錄：`$PROFILE` bootstrap

不由本 repo 管理（見上）。萬一遺失，這兩支各建一個：

`Documents\PowerShell\Microsoft.PowerShell_profile.ps1`（pwsh 7）
```powershell
# Shared config lives in one place for both PowerShell 5.1 and 7
$shared = Join-Path $HOME '.config\powershell\profile.ps1'
if (Test-Path $shared) { . $shared }
$env:CLAUDE_CONFIG_DIR="$HOME\.config\claude"
```

`Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`（PS 5.1）——同上，但**不含**最後一行。

兩支都要存成 **UTF-8 with BOM**。

---

aionyxhuang@gmail.com
