# WezTerm

Windows 極簡科技冷色配置。單檔 `wezterm.lua`，配色 Tokyo Night，與 Starship 的提示列、Sublime 的自製配色一氣呵成。

> **鍵盤操作全部在 [KEYMAP.md](../home/.config/wezterm/KEYMAP.md)**（10 章、含 Copy Mode / Search Mode 完整鍵表與已知衝突）。本檔只講設定本身。

---

## 特色

- **恆定通透玻璃** — Windows 的 Acrylic/Mica 一失焦就會被 DWM 換成半實色，這是系統原生行為、關不掉。因此改用 `win32_system_backdrop = 'Disable'` + `window_background_opacity = 0.90` 的純視窗透明：由視窗 alpha 控制，聚焦／失焦完全一致。代價是背景「清晰」而非磨砂。
- **圓角膠囊分頁** — 自繪的懸浮膠囊分頁，激活時鑲邊發光，並依前景程序自動顯示 Nerd Font 圖示。
- **整合式標題列** — `INTEGRATED_BUTTONS|RESIZE` 去掉傳統邊框，視窗控制鍵嵌進分頁列。
- **聚光燈式分屏** — `inactive_pane_hsb` 把非焦點分屏壓到 brightness 0.42，當前分屏像被打光。
- **Tmux 式分屏熱鍵** — `Alt+Shift+|` / `-` 分屏，`Alt+HJKL` 秒切，`Alt+Shift+HJKL` 調整大小。
- **多螢幕 / 高刷新率優化** — `WebGpu` + `LowPower` 綁內顯，解決跨 DPI（150%／125%）、跨刷新率（144Hz／240Hz）的拖曳卡頓。
- **中文零亂碼** — `default_prog` 啟動時就壓下 `chcp 65001` 與 `[Console]::OutputEncoding`，並用 `set_environment_variables` 補上 `PYTHONIOENCODING` 等；字型後援鎖 Microsoft YaHei。

## 需求

| 項目 | 用途 | winget ID |
|------|------|-----------|
| WezTerm | 終端機本體 | `wez.wezterm` |
| PowerShell 7 | `default_prog` 指定 `pwsh.exe` | `Microsoft.PowerShell` |
| JetBrainsMono Nerd Font | 主字型 + 分頁／狀態列圖示 | `DEVCOM.JetBrainsMonoNerdFont` |
| Microsoft YaHei | 中文後援字型 | Windows 內建 |
| Starship | 提示字元 | `Starship.Starship` |

## 常見自訂

| 想改什麼 | 改哪裡 |
|---|---|
| 通透度 | `window_background_opacity`（越小越通透；清晰背景太干擾可調到 `0.7`～`0.85`） |
| 想要磨砂模糊 | `win32_system_backdrop` 改回 `'Acrylic'`——但會恢復「失焦變色」 |
| 配色 | `config.color_schemes` 的自訂表（`config.colors` 會覆寫它，兩邊要同步） |
| 字型大小 | `config.font_size`（預設 `11.5`） |
| 非焦點分屏的暗度 | `inactive_pane_hsb.brightness`（越小越暗） |
| 渲染後端 | `front_end`。WebGpu 下若透明失效或閃退，依檔內註解的階梯退回 `'OpenGL'` |

## 注意

`max_fps` 曾設 120（想配合 144Hz），後來調回官方預設 60——雙螢幕刷新率不同時，鎖高 fps 反而讓合成負擔不穩。檔內註解有記錄。
