# my-wezterm

> WezTerm + Starship 終端機終極配置 · Windows 極簡科技冷色魔改版

一份為 Windows 打造的 WezTerm 單檔配置，搭配 Starship 提示字元。主打**恆定通透毛玻璃**、**圓角膠囊懸浮分頁**、**Tmux 式分屏熱鍵**，以及**徹底解決 Python / Git 中文亂碼**的 UTF-8 環境鎮壓。

配色採用 Catppuccin Mocha 冷色調（冰藍 / 青綠），與 Starship 的石板灰漸層提示列一氣呵成。

---

## ✨ 特色

- **恆定通透玻璃** — 關掉 Windows 系統 Mica/Acrylic（避免失焦被 DWM 換成半實色），改用純視窗透明，聚焦 / 失焦通透度完全一致。
- **圓角膠囊分頁** — 懸浮於透明玻璃上的膠囊分頁，激活時冰藍鑲邊發光，並依前景程序自動顯示 Nerd Font 圖示（PowerShell / Python / Git / Docker …）。
- **現代化狀態列** — 左側顯示 workspace，右側顯示當前目錄、時間與電池電量。
- **Tmux 式分屏** — `Alt+Shift+|` / `-` 分屏，`Alt+HJKL` 秒切，`Alt+Shift+HJKL` 調整大小。
- **多螢幕 / 高刷新率優化** — WebGpu + LowPower 綁內顯，解決跨 DPI（150% / 125%）、跨刷新率（144Hz / 240Hz）拖曳卡頓。
- **中文零亂碼** — 強制全域 UTF-8（`chcp 65001` + `PYTHONIOENCODING` 等環境變數），Microsoft YaHei 後援字型鎖住中文編碼。

---

## 📦 需求

| 項目 | 說明 |
|------|------|
| [WezTerm](https://wezfurlong.org/wezterm/) | 終端機本體 |
| [Starship](https://starship.rs/) | 跨平台提示字元 |
| [JetBrains Mono](https://www.jetbrains.com/lp/mono/) / Nerd Font | 主字型（含連字與斜線零） |
| [Microsoft YaHei](https://zh.wikipedia.org/wiki/微软雅黑体) | 中文後援字型（Windows 內建） |
| Symbols Nerd Font | 狀態列與分頁圖示 |

> 分頁圖示與狀態列需要 Nerd Font 字符支援。建議安裝 [JetBrainsMono Nerd Font](https://www.nerdfonts.com/font-downloads)。

---

## 🚀 安裝

### 1. WezTerm 配置

將 `wezterm/wezterm.lua` 放到 WezTerm 的設定路徑：

```powershell
# Windows 預設會讀取此路徑
copy wezterm\wezterm.lua "$env:USERPROFILE\.wezterm.lua"
```

或放到 `%USERPROFILE%\.config\wezterm\wezterm.lua`。

### 2. Starship 配置

```powershell
copy starship.toml "$env:USERPROFILE\.config\starship.toml"
```

WezTerm 已設定 PowerShell 為預設 shell，只要在 PowerShell profile 加入啟動即可：

```powershell
# 於 $PROFILE 中加入
Invoke-Expression (&starship init powershell)
```

---

## ⌨️ 熱鍵一覽

### 分屏（Panes）

| 快捷鍵 | 功能 |
|--------|------|
| `Alt+Shift+\|` 或 `\` | 左右分屏 |
| `Alt+Shift+-` | 上下分屏 |
| `Alt+H/J/K/L` 或方向鍵 | 切換分屏 |
| `Alt+Shift+H/J/K/L` | 調整分屏大小 |
| `Alt+Z` | 分屏最大化切換（Zoom） |
| `Alt+W` | 關閉當前分屏 |
| `Ctrl+Shift+Space` | 跳出字母標號，瞬移到指定分屏 |

### 分頁（Tabs）

| 快捷鍵 | 功能 |
|--------|------|
| `Ctrl+Shift+T` | 新分頁 |
| `Ctrl+Shift+W` | 關閉分頁 |
| `Ctrl+1` ~ `Ctrl+8` | 跳到第 N 個分頁 |
| `Ctrl+9` | 跳到最後一個分頁 |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | 前後切換分頁 |
| `Alt+[` / `Alt+]` | 前後切換分頁 |

### 其他

| 快捷鍵 | 功能 |
|--------|------|
| `Ctrl+Shift+C` / `Ctrl+Shift+V` | 複製 / 貼上 |
| `Ctrl+Shift+P` | 指令面板 |
| 選取文字 | 自動複製到剪貼簿 |
| `Ctrl+左鍵` | 開啟連結 |

---

## 🎨 自訂

- **通透度** — 調整 `wezterm.lua` 的 `window_background_opacity`（越小越通透；清晰背景太干擾可調高到 `0.7~0.85`）。想要磨砂模糊效果可把 `win32_system_backdrop` 改回 `'Acrylic'`（但失焦會變色）。
- **配色** — WezTerm 改 `config.color_scheme`；Starship 改 `starship.toml` 中各段的 `bg` 十六進位色碼（記得同步 `format` 裡對應的箭頭顏色）。
- **字型大小** — 調整 `config.font_size`（預設 `11.5`）。
- **渲染後端** — 若 WebGpu 下透明失效或閃退，可依 `wezterm.lua` 註解的階梯退回 `OpenGL`。

---

## 📁 結構

```
my-wezterm/
├── wezterm/
│   └── wezterm.lua    # WezTerm 單檔配置
├── starship.toml      # Starship 提示字元配置
└── .gitignore
```

aionyxhuang@gmail.com
