# Sublime Text

`%APPDATA%\Sublime Text\Packages\User` 整包 symlink。15 個檔、約 23 KB。

Sublime 是 `settings.json` 裡設定的 `EDITOR`（`subl -w`），也是 `yazi.toml` 的 edit opener，所以它的路徑會被 `profile.ps1` 補進 PATH。

---

## ★ `atomic_save: false` 是必要設定，不是偏好

Sublime 預設的原子存檔是「寫暫存檔 → rename 蓋過去」。rename 蓋掉的是 **symlink 本身**，不是它指向的目標。

也就是說：只要用 Sublime 存過一次 `~/.config/...` 底下的檔案，那條 symlink 就會被默默換成一個實體檔案。之後在 repo 裡改再也不會生效，而且 `git status` 毫無反應——這是這套 dotfiles 唯一會**靜默失效**的失敗模式。

因此 `Preferences.sublime-settings` 明確關掉它。非原子寫入的風險（寫到一半崩潰）對這些小檔、又有 git 的情況可以接受。

三道防線：

1. 日常改 config 在 repo 目錄裡改（那裡是實體檔案，任何編輯器都不會出事）
2. `atomic_save: false`
3. `install.ps1 -Verify` 會抓出「本該是 symlink 卻變成實體檔」的目標

> Neovim 沒有這個問題：`backupcopy=auto` 會偵測 symlink 並自動改用複製模式。

---

## 內容

| 檔案 | 說明 |
|---|---|
| `Preferences.sublime-settings` | 主設定 |
| `Tokyo Night.sublime-color-scheme` | **自製**配色，色值同步自 `wezterm.lua` |
| `Adaptive.sublime-theme` | UI 微調 |
| `Default (Windows).sublime-keymap` | 鍵位 |
| `C++17.sublime-build` + `sublime-cpp-build.ps1` | C++17 build system |
| `{JSON,Lua,Markdown,Python,YAML}.sublime-settings` | 各語言個別設定 |
| `markdown.css`、`MarkdownPreview.sublime-settings` | Markdown 預覽 |

## 幾個非顯而易見的設定

- **`font_face` 用 JetBrains Mono NL**（無連字版）——設定檔裡的 `!=`、`=>` 被畫成連字符號會看不出實際字元。
- **`theme: Adaptive`** 會從配色方案的背景色推導整個 UI 的顏色，所以側邊欄與上下 bar 自動跟著 Tokyo Night 走。用 `Default Dark` 的話它有自己一套獨立灰階，那才是「灰底配深藍編輯區」的成因。
- **`show_encoding` / `show_line_endings`** Sublime 預設是關的，這裡刻意打開：中文檔開成 Big5 會亂碼，狀態列是唯一的即時線索；CRLF 混進 repo 會造成「整檔皆變」的假 diff。
- **`folder_exclude_patterns`** — `D:\Project\python` 有 27 萬+ 檔案，沒有這些排除規則 `Ctrl+P` 會被 `node_modules` 灌爆。

## Package Control

`Package Control.last-run`、`oscrypto-ca-bundle.crt`、`*.cache` 是執行期狀態不是設定，已在 `.gitignore` 排除。
