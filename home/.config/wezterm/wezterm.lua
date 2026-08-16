-- =====================================================================
--  WezTerm 單檔終極配置  ·  Windows 極簡科技冷色魔改版
--  特色：Mica 深色墨鏡毛玻璃 / 解決中文亂碼 / 圓角膠囊懸浮分頁 / Tmux 分屏
-- =====================================================================

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Tokyo Night (Night variant)
local M = {
  base = '#1a1b26', mantle = '#16161e', crust = '#101014',
  text = '#c0caf5', subtext0 = '#a9b1d6', overlay0 = '#565f89',
  surface0 = '#24283b', surface1 = '#414868',
  blue = '#7aa2f7',
  sapphire = '#7dcfff', teal = '#73daca', green = '#9ece6a',
  peach = '#ff9e64', yellow = '#e0af68', red = '#f7768e',
}

--------------------------------------------------------------------
-- 1. 頂級毛玻璃通透 (Glass & Background)
--------------------------------------------------------------------
-- Windows Acrylic 在失焦時可能被 DWM 換成近似實色；使用純 alpha 透明避開該行為。
-- 這會直接顯示後方視窗而不模糊，但聚焦與失焦的透明度保持一致。
config.win32_system_backdrop = 'Disable'
config.window_background_opacity = 0.90  -- 保留玻璃感，同時維持 Tokyo Night 對比
config.text_background_opacity = 1.0     -- Powerline 色塊保持實色，避免視覺重疊

--------------------------------------------------------------------
-- 2. 配色美學 (已合併 table，徹底解決覆寫導致不透明的問題！)
--------------------------------------------------------------------
config.color_schemes = {
  ['Tokyo Night'] = {
    foreground = '#a9b1d6',
    background = '#1a1b26',
    cursor_bg = '#c0caf5',
    cursor_fg = '#1a1b26',
    cursor_border = '#c0caf5',
    selection_bg = '#33467c',
    selection_fg = '#c0caf5',
    ansi = {
      '#414868', '#f7768e', '#73daca', '#e0af68',
      '#7aa2f7', '#bb9af7', '#7dcfff', '#c0caf5',
    },
    brights = {
      '#565f89', '#f7768e', '#73daca', '#e0af68',
      '#7aa2f7', '#bb9af7', '#7dcfff', '#a9b1d6',
    },
  },
}
config.color_scheme = 'Tokyo Night'

-- ★ 頂條襯底:整條 bar 唯一的可讀性來源。
--   原本設 rgba(0,0,0,0) = 完全零填色,是整個視窗最透的一塊(其他地方至少還有
--   window_background_opacity 0.90 的底),導致狀態列細字直接飄在桌面上、背後一亮就消失。
--   給它一層比視窗本體更實的深色,讀起來像刻意的標題列而非破洞。
--   ↓ 只要調這個 alpha 就能在「通透」與「清楚」之間找平衡 (0.70 較通透 / 0.95 近實色)
local BAR_BG = 'rgba(16, 17, 22, 0.85)'

config.colors = {
  tab_bar = {
    background = BAR_BG,
  },
}

--------------------------------------------------------------------
-- 3. 告別傳統邊框 + 呼吸感留白
--------------------------------------------------------------------
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_button_style = 'Windows'
config.integrated_title_buttons = { 'Hide', 'Maximize', 'Close' }
config.window_padding = { left = 16, right = 16, top = 14, bottom = 12 }
config.inactive_pane_hsb = { saturation = 0.65, brightness = 0.42 }  -- ★#1 非焦點分屏壓更暗,當前分屏像聚光燈(數字越小越暗)

--------------------------------------------------------------------
-- 4. 字型與排版 (已修復找不到字體報錯 & 中文退化問題)
--------------------------------------------------------------------
-- 以 WezTerm 內建 JetBrains Mono 打頭陣保證不報錯；微軟雅黑緊跟其後鎖住中文編碼
config.font = wezterm.font_with_fallback {
  -- ★文字1+4:字重加粗到 Medium(透明背景上更紮實不發虛)+ 開啟斜線零 'zero'(0 與 O 一眼分辨)
  { family = 'JetBrains Mono', weight = 'Medium', harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1', 'zero' } },
  { family = 'JetBrainsMono NF', weight = 'Medium', harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1', 'zero' } },
  'Microsoft YaHei',            -- 中文第一順位後援，徹底解決方形框與字距錯誤
  'Symbols Nerd Font Mono',
  'Segoe UI Emoji',
}
config.font_size = 11.5
-- ★ 不要設 config.dpi！(曾設為 120.0，是破圖/疊影/背景穿透的元凶)
--   硬鎖 DPI 會廢掉 WezTerm 的 per-monitor DPI 感知：視窗放大或跨螢幕時，
--   實體像素尺寸與算繪視埠對不上，swapchain 會有一塊區域從未被繪製。
--   在透明視窗上，那塊區域不是黑色，而是被 DWM 合成成後方的視窗內容。
--   代價：跨不同縮放的螢幕時會重建 glyph atlas，拖曳瞬間可能微頓 —— 這是正確行為。
config.line_height = 1.15       -- 寬鬆行高，增加排版呼吸感
-- ★文字2:前景文字亮度微提,讓字在通透背景上更「浮出」、不被後方桌面吃掉(1.0=原始)
--   注意:數值拉太高(如 1.08)會把抗鋸齒的灰階漸層一起推到頂而「削平」,
--   字緣的過渡階數變少 → 看起來反而像鋸齒/低解析。1.02 是有提亮又不削 AA 的平衡點。
config.foreground_text_hsb = { hue = 1.0, saturation = 1.0, brightness = 1.02 }

--------------------------------------------------------------------
-- 5. 游標：平滑閃爍
--------------------------------------------------------------------
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'EaseInOut'
config.cursor_blink_ease_out = 'EaseInOut'

--------------------------------------------------------------------
-- 6. 靈魂細節 A：圓角膠囊分頁 (懸浮極簡科技風)
--------------------------------------------------------------------
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
-- ★ 頂條常駐:因為 window_decorations 用 INTEGRATED_BUTTONS(視窗按鈕在頂條裡),
--   若單分頁把頂條藏了,按鈕與拖曳把手會一起消失 → 不能移動/關閉(先前那個 bug)。
--   故設 false 讓薄頂條常駐(背景已透明,幾乎不占玻璃),保留拖曳與視窗按鈕。
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 26

local process_icons = {
  ['powershell.exe'] = wezterm.nerdfonts.md_powershell,
  ['pwsh.exe']       = wezterm.nerdfonts.md_powershell,
  ['cmd.exe']        = wezterm.nerdfonts.md_console,
  ['wsl.exe']        = wezterm.nerdfonts.cod_terminal_bash,
  ['wslhost.exe']    = '',
  ['ubuntu.exe']     = '',
  ['bash']           = wezterm.nerdfonts.cod_terminal_bash,
  ['nvim']           = wezterm.nerdfonts.custom_vim,
  ['vim']            = wezterm.nerdfonts.custom_vim,
  ['node']           = wezterm.nerdfonts.md_nodejs,
  ['python']         = wezterm.nerdfonts.md_language_python,
  ['python.exe']     = wezterm.nerdfonts.md_language_python,
  ['cargo']          = wezterm.nerdfonts.dev_rust,
  ['lua']            = wezterm.nerdfonts.md_language_lua,
  ['docker']         = wezterm.nerdfonts.md_docker,
  ['git']            = wezterm.nerdfonts.md_git,
  ['ssh']            = wezterm.nerdfonts.md_console_network,
  ['go']             = wezterm.nerdfonts.md_language_go,
}
local LEFT_EDGE = wezterm.nerdfonts.ple_left_half_circle_thick
local RIGHT_EDGE = wezterm.nerdfonts.ple_right_half_circle_thick

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  -- ★#4 rim = 膠囊兩端半圓的顏色;激活時用比膠囊更亮的冰藍做「鑲邊發光」
  local bg, fg, rim = M.surface0, M.subtext0, M.surface0   -- 未激活：暗灰低調
  if tab.is_active then
    bg, fg, rim = M.blue, M.crust, '#a6e3ff'               -- 激活：冰藍膠囊 + 更亮鑲邊發光 + 粗體
  elseif hover then
    bg, fg, rim = M.surface1, M.text, M.surface1
  end
  local proc = (tab.active_pane.foreground_process_name or ''):gsub('.*[/\\]', ''):lower()
  local icon = process_icons[proc] or wezterm.nerdfonts.md_console_line
  local title = (tab.active_pane.title or ''):gsub('%.exe$', '')
  if proc == 'wslhost.exe' or proc == 'wsl.exe' or proc == 'ubuntu.exe' then
    icon = ''
    title = 'Ubuntu'
  end
  -- 依顯示寬度截斷，不會像 string.sub 一樣切壞中文 UTF-8。
  title = wezterm.truncate_right(title, 16)
  return {
    { Background = { Color = BAR_BG } }, { Foreground = { Color = rim } }, { Text = LEFT_EDGE },
    { Background = { Color = bg } }, { Foreground = { Color = fg } },
    { Attribute = { Intensity = tab.is_active and 'Bold' or 'Normal' } },
    { Text = string.format(' %d  %s  %s ', tab.tab_index + 1, icon, title) },
    { Attribute = { Intensity = 'Normal' } },
    { Background = { Color = BAR_BG } }, { Foreground = { Color = rim } }, { Text = RIGHT_EDGE },
    { Text = ' ' },
  }
end)

--------------------------------------------------------------------
-- 6b. 靈魂細節 B：現代化狀態列 (冷色調系統資訊)
--------------------------------------------------------------------
wezterm.on('update-status', function(window, pane)
  local status_proc = (pane:get_foreground_process_name() or ''):gsub('.*[/\\]', ''):lower()
  local system_icon = wezterm.nerdfonts.md_microsoft_windows
  local system_name = 'Windows'
  if status_proc == 'wslhost.exe' or status_proc == 'wsl.exe' or status_proc == 'ubuntu.exe' then
    system_icon = ''
    system_name = 'Ubuntu'
  end
  window:set_left_status(wezterm.format {
    { Foreground = { Color = M.blue } },
    { Text = '  ' .. system_icon .. '  ' .. system_name .. '  ·  ' .. window:active_workspace() .. '  ' },
  })

  local cwd = ''
  local uri = pane:get_current_working_dir()
  if uri then
    cwd = type(uri) == 'userdata' and (uri.file_path or '') or tostring(uri):gsub('^file://[^/]*', '')
    cwd = cwd:gsub('[/\\]$', ''):gsub('.*[/\\]', '')
  end
  local time = wezterm.strftime '%m/%d %H:%M'
  local bat = ''
  for _, b in ipairs(wezterm.battery_info()) do
    local ic = b.state == 'Charging' and wezterm.nerdfonts.md_battery_charging_high or wezterm.nerdfonts.md_battery
    bat = string.format('%s %.0f%%', ic, b.state_of_charge * 100)
  end

  local cells = {}
  if cwd ~= '' then
    table.insert(cells, { Foreground = { Color = M.sapphire } })
    table.insert(cells, { Text = wezterm.nerdfonts.md_folder .. ' ' .. cwd .. '   ' })
  end
  table.insert(cells, { Foreground = { Color = M.teal } })
  table.insert(cells, { Text = wezterm.nerdfonts.md_clock_outline .. ' ' .. time .. '   ' })
  if bat ~= '' then
    table.insert(cells, { Foreground = { Color = M.green } })
    table.insert(cells, { Text = bat .. '  ' })
  end
  window:set_right_status(wezterm.format(cells))
end)

-- 不註冊 window-focus-changed：聚焦與失焦都使用同一個 0.72 透明度。

--------------------------------------------------------------------
-- 7. HiDPI / 高刷新率 / 渲染強化 (已移除廢棄指令)
--------------------------------------------------------------------
-- ★ 本機是混合顯卡 (NVIDIA RTX 4060 Laptop + Intel UHD)，且螢幕由 Intel 驅動。
--   舊設定 front_end='OpenGL' + prefer_egl=true 會走 ANGLE/D3D11：
--   混合顯卡上 resize 重建 swapchain 容易殘留舊 buffer → 疊影/破圖。
--   改用 WebGpu(此版本的預設後端)，並用 LowPower 明確挑 Intel 內顯 ——
--   讓算繪與畫面輸出在同一張卡上，避免跨 adapter 呈現造成 alpha 失效。
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'LowPower'

-- ★ max_fps 120 → 60(官方預設)。
--   LowPower 是刻意挑 Intel 內顯(理由見上)，那張卡要在 191 PPI @150% 的面板上
--   推一個 0.90 透明的視窗 —— 而透明視窗每一幀都要 DWM 合成整個視窗。
--   TUI 從 60 拉到 120 幀肉眼看不出差別，GPU 與合成器的工作量卻是兩倍。
config.max_fps = 60

-- ★ animation_fps 60 → 10(官方預設)。這個值只管一件事：
--   閃爍游標 / 閃爍文字 / visual bell 的「緩動」算繪幀率。
--   配上下面的 EaseInOut，等於這個透明視窗每秒被重繪 60 次跑緩動動畫 ——
--   而且是在完全沒有操作的時候也一直跑。回到預設的 10 已經砍掉 6/7 的
--   閒置重繪，同時保留你要的平滑閃爍。
--   若之後測下來還想再壓：官方對低算繪資源環境的建議是
--     animation_fps = 1 + cursor_blink_ease_in/out = 'Constant'
--   那會完全關掉緩動、變成乾淨的開/關閃爍，是本檔案裡最後一格可壓的空間。
config.animation_fps = 10

-- ★ 191 PPI 面板 @150% 縮放 = 等效 144 DPI，屬於高 DPI 環境。
--   高 DPI 下 hinting 反而有害:它會把字元輪廓「掰」去對齊像素格,
--   在每 em 有足夠像素時只是徒然扭曲字形。關掉才拿得到字體設計的真實曲線。
config.freetype_load_flags = 'NO_HINTING'
config.freetype_load_target = 'Light'
-- ★ 透明背景上用 LCD 次像素抗鋸齒(HorizontalLcd)字緣會出現彩色毛邊(色散);
--   原因:次像素算繪必須確知背景色才能正確分配 RGB 子像素能量,
--   而透明視窗的背景是 DWM 事後合成的 → 資訊上不可能算對,不是調參數能解的。
--   故維持 'Normal'(灰階抗鋸齒)。想用 HorizontalLcd 就得先把透明度關掉。
config.freetype_render_target = 'Normal'

-- ★ update-status 預設每 1 秒重跑一次,而它裡面有 battery_info()(Windows 上是同步查詢)
--   和 get_foreground_process_name()。右側只顯示到「分鐘」,2 秒更新一次看不出差別,
--   但背景輪詢直接砍半。
config.status_update_interval = 2000

-- ★ 有工具會印出 U+EA12 / U+EA54 這類碼位。它們落在 Nerd Fonts 的
--   Devicons(…E8EF) 與 Codicons(EA60…) 之間的未分配空隙 —— 不存在於任何 Nerd Font,
--   所以「再裝一套字型」永遠救不了,只會一直跳彈窗。字仍會顯示成佔位方框。
--   (已驗證 E5FA/E702/EA60/EA71/F07B/F17A 都正常命中 JetBrainsMono Nerd Font,
--    字型安裝本身是好的。)
config.warn_about_missing_glyphs = false

config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_function = 'EaseIn',  fade_in_duration_ms = 75,
  fade_out_function = 'EaseOut', fade_out_duration_ms = 150,
  target = 'CursorColor',
}
config.scrollback_lines = 20000
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- 關掉檢查與更新提示 (已刪除 deprecated 的 show_update_window)
config.check_for_updates = false

--------------------------------------------------------------------
-- 8. 終端核心與編碼修復 (強制全域 UTF-8，杜絕 Python/Git 中文亂碼)
--------------------------------------------------------------------
-- ★ 原本結尾還有 `chcp 65001 > $null`,已移除:那是一次多餘的 process spawn(~34ms/分頁)。
--   .NET 的 [Console]::OutputEncoding / InputEncoding setter 內部就會呼叫
--   SetConsoleOutputCP / SetConsoleCP(65001),效果完全等同 chcp。
--   (實測:父行程 cp=950 時,只設這兩行,子行程的 chcp 回報 65001;不設則停在 950。)
local ps_utf8 = '[Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::InputEncoding=[Text.Encoding]::UTF8'
-- pwsh.exe = PowerShell 7（與系統內建的 5.1 powershell.exe 並存，不是取代）
config.default_prog = { 'pwsh.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 }

-- 全方位的編碼環境變數鎮壓，保證底層 POSIX 工具與編譯輸出中文零亂碼
config.set_environment_variables = { 
  LANG = 'en_US.UTF-8',
  LC_ALL = 'en_US.UTF-8',
  LESSCHARSET = 'utf-8',
  PYTHONIOENCODING = 'utf-8'
}

config.launch_menu = {
  { label = 'PowerShell 7',   args = { 'pwsh.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 } },
  { label = 'Windows PowerShell 5.1', args = { 'powershell.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 } },
  { label = 'Ubuntu (WSL)', args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' } },
  { label = 'CMD',        args = { 'cmd.exe', '/k', 'chcp 65001 > nul' } },
}

--------------------------------------------------------------------
-- 9. 順手多工熱鍵 (Tmux 式分屏 / 毫秒秒切 / 調整大小)
--------------------------------------------------------------------
-- Ctrl+C：有反白文字時複製；沒有選取時才把 Ctrl+C 傳給 shell 中斷工作。
local copy_selection_or_interrupt = wezterm.action_callback(function(window, pane)
  local selection = window:get_selection_text_for_pane(pane)
  if selection and selection ~= '' then
    window:perform_action(act.CopyTo 'Clipboard', pane)
  else
    window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
  end
end)

-- ★ Ctrl+V 曾經短暫做過「前景行程是 yazi 就放行」的特例，已於 2026-08-09 移除 ——
--   yazi 那邊的 <C-v> 綁定在鍵位瘦身時砍掉了(貼上統一走 p)，特例失去服務對象。
--
--   但那個 bug 值得記著，因為它會再發生：無條件的 PasteFrom 會把剪貼簿
--   「文字」送進前景 TUI，而 yazi 這類程式把每個字元都當按鍵解讀 ——
--   剪貼簿裡若有路徑，那個 : 就是 shell --block --interactive，於是憑空
--   跳出一個提示字元、後面的字全被打進去，看起來就像整個程式卡住/亂掉。
--   所以：日後若又想在某個 TUI 裡用 Ctrl+V，別直接改成無條件 SendKey，
--   照 copy_selection_or_interrupt 的模式用 action_callback 判斷前景行程。

config.keys = {
  -- 分屏 (| 直線=左右並排 / - 橫線=上下並排)
  { key = '|',  mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '\\', mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-',  mods = 'ALT|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  { key = '_',  mods = 'ALT|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  -- 分屏間秒切 (Alt + HJKL 及 方向鍵)
  { key = 'h', mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'LeftArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'DownArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'UpArrow',    mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  -- 鍵盤調整分屏大小 (Alt + Shift + HJKL)
  { key = 'h', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 4 } },
  { key = 'j', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 4 } },
  { key = 'k', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 4 } },
  { key = 'l', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 4 } },
  -- 分頁 / 分區管理
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
  { key = 'w', mods = 'ALT',        action = act.CloseCurrentPane { confirm = false } },
  { key = 'z', mods = 'ALT',        action = act.TogglePaneZoomState },
  { key = 'Tab', mods = 'CTRL',        action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT',  action = act.ActivateTabRelative(-1) },
  -- ★ 直接跳到第 N 個分頁 (Ctrl+1~8),Ctrl+9 = 最後一個
  { key = '1', mods = 'CTRL', action = act.ActivateTab(0) },
  { key = '2', mods = 'CTRL', action = act.ActivateTab(1) },
  { key = '3', mods = 'CTRL', action = act.ActivateTab(2) },
  { key = '4', mods = 'CTRL', action = act.ActivateTab(3) },
  { key = '5', mods = 'CTRL', action = act.ActivateTab(4) },
  { key = '6', mods = 'CTRL', action = act.ActivateTab(5) },
  { key = '7', mods = 'CTRL', action = act.ActivateTab(6) },
  { key = '8', mods = 'CTRL', action = act.ActivateTab(7) },
  { key = '9', mods = 'CTRL', action = act.ActivateTab(-1) },
  -- ★ 分頁前後快切
  { key = '[', mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = ']', mods = 'ALT', action = act.ActivateTabRelative(1) },
  -- ★ 分屏標號跳轉:跳出大字母,按字母瞬移到該分屏
  { key = ' ', mods = 'CTRL|SHIFT', action = act.PaneSelect { alphabet = 'asdfghjkl' } },
  -- 複製 / 貼上 / 指令面板
  -- Ctrl+V 由 WezTerm 直接貼文字，避免前景 CLI 把它解讀成「貼上圖片」。
  { key = 'c', mods = 'CTRL',       action = copy_selection_or_interrupt },
  { key = 'v', mods = 'CTRL',       action = act.PasteFrom 'Clipboard' },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'Insert', mods = 'CTRL',  action = act.CopyTo 'Clipboard' },
  { key = 'Insert', mods = 'SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
  -- ★ 透明度即時切換 (Ctrl+Shift+B):在 0.90(玻璃) 與 1.0(實色) 之間來回,不必改設定檔重載。
  --   透明視窗每一幀都要 DWM 合成整個視窗,是 Windows 上打字延遲的常見來源。
  --   兩邊各打幾行字比一比:有感 → 這是你的取捨;沒感 → 這條嫌疑可以直接排除。
  { key = 'b', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, _)
      local o = window:get_config_overrides() or {}
      o.window_background_opacity = (o.window_background_opacity == 1.0) and 0.90 or 1.0
      window:set_config_overrides(o)
    end) },
}

--------------------------------------------------------------------
-- 10. 滑鼠：選取自動複製 + 點擊開連結
--------------------------------------------------------------------
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE',
    -- Windows 沒有 X11 Primary Selection；只寫系統 Clipboard 可減少非同步競爭。
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor 'Clipboard' },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor },
  { event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.Nop },
}

config.window_close_confirmation = 'NeverPrompt'

return config
