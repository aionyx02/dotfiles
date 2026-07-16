-- =====================================================================
--  WezTerm 單檔終極配置  ·  Windows 極簡科技冷色魔改版
--  特色：Mica 深色墨鏡毛玻璃 / 解決中文亂碼 / 圓角膠囊懸浮分頁 / Tmux 分屏
-- =====================================================================

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- 極簡冷色調色盤 (Cyberpunk / Tech Minimalist)
local M = {
  base = '#181825', mantle = '#11111b', crust = '#0d0e16',
  text = '#cdd6f4', subtext0 = '#a6adc8', overlay0 = '#6c7086',
  surface0 = '#2a2b3d', surface1 = '#3b3c54',
  blue = '#7dcfff',     -- 冰藍色 (Active 激活元素使用)
  sapphire = '#74c7ec', teal = '#73daca', green = '#9ece6a',
  peach = '#ff9e64', yellow = '#e0af68', red = '#f7768e',
}

--------------------------------------------------------------------
-- 1. 頂級毛玻璃通透 (Glass & Background)
--------------------------------------------------------------------
-- ★ 恆定通透模式:Windows 的 Acrylic/Mica 系統毛玻璃「一失焦就會被 DWM 換成半實色」,
--   這是系統原生行為、無法用設定關掉。你要「聚焦/失焦通透度完全一致」,就必須關掉系統毛玻璃,
--   改用純視窗透明(下面的 window_background_opacity)——它由視窗 alpha 控制,恆定不隨聚焦改變。
--   代價:背景是「清晰」的桌面/後方視窗,而非磨砂模糊。想要磨砂玻璃就改回 'Acrylic'(但會有失焦變色)。
config.win32_system_backdrop = 'Disable'
config.window_background_opacity = 0.9  -- ★ 純透明度:越小越通透。若清晰背景太干擾閱讀,調高到 0.7~0.85
config.text_background_opacity = 1.0      -- 鎖定文字底色不透明，確保對比度極高
-- 註:先前的 config.background 徑向漸層(景深暗角)會在底部渲染出破圖,且讓背景看起來不均勻變色,
--     已整段移除,背景恢復成單純的 Acrylic 玻璃。

--------------------------------------------------------------------
-- 2. 配色美學 (已合併 table，徹底解決覆寫導致不透明的問題！)
--------------------------------------------------------------------
config.color_scheme = 'Catppuccin Mocha'

-- ★ 突破重點②(釐清誤解):color_scheme 的背景「不會」鎖死透明度。config.colors 本來就會
--   覆寫主題,而視窗穿透是由上面的 window_background_opacity「全域」控制,與主題背景色無關。
--   先前 background = 'rgba(...,0.45)' 的 alpha 對「視窗穿透」其實無效(甚至干擾合成),已移除,
--   把背景層 100% 交還給 Windows 的 Acrylic 物理毛玻璃引擎。
config.colors = {
  -- ★優化2:冷霧藍底,呼應冰裂桌布(此為底色;實際穿透度由 window_background_opacity 決定)
  background = 'rgba(15, 18, 28, 0.45)',
  -- ★優化2:冰螢光青藍游標 + 三稜鏡折射感
  cursor_bg = '#00e5ff',
  cursor_fg = M.crust,
  cursor_border = '#00e5ff',
  -- ★優化2:30% 透明冰藍選取框
  selection_bg = 'rgba(0, 229, 255, 0.3)',
  selection_fg = M.text,
  tab_bar = {
    background = 'rgba(0, 0, 0, 0)',   -- 分頁列透明,膠囊懸浮於玻璃
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
config.line_height = 1.15       -- 寬鬆行高，增加排版呼吸感
-- ★文字2:前景文字亮度微提,讓字在通透背景上更「浮出」、不被後方桌面吃掉(1.0=原始)
config.foreground_text_hsb = { hue = 1.0, saturation = 1.0, brightness = 1.08 }

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
  if #title > 16 then title = title:sub(1, 15) .. '…' end
  return {
    { Background = { Color = 'rgba(0,0,0,0)' } }, { Foreground = { Color = rim } }, { Text = LEFT_EDGE },
    { Background = { Color = bg } }, { Foreground = { Color = fg } },
    { Attribute = { Intensity = tab.is_active and 'Bold' or 'Normal' } },
    { Text = string.format(' %d  %s  %s ', tab.tab_index + 1, icon, title) },
    { Attribute = { Intensity = 'Normal' } },
    { Background = { Color = 'rgba(0,0,0,0)' } }, { Foreground = { Color = rim } }, { Text = RIGHT_EDGE },
    { Text = ' ' },
  }
end)

--------------------------------------------------------------------
-- 6b. 靈魂細節 B：現代化狀態列 (冷色調系統資訊)
--------------------------------------------------------------------
wezterm.on('update-status', function(window, pane)
  window:set_left_status(wezterm.format {
    { Foreground = { Color = M.blue } },
    { Text = '  ' .. wezterm.nerdfonts.md_microsoft_windows .. '  ' .. window:active_workspace() .. '  ' },
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

-- 6c.(已移除)先前的 window-focus-changed 會在失焦時把透明度降到 0.45,
--     依你要求拿掉,讓通透度「恆定」為上方的 window_background_opacity = 0.6,
--     聚焦/失焦都不再變色。

--------------------------------------------------------------------
-- 7. HiDPI / 高刷新率 / 渲染強化 (已移除廢棄指令)
--------------------------------------------------------------------
-- ★ 多螢幕拖曳優化:你有 144Hz+240Hz、150%+125% 兩種截然不同的螢幕,OpenGL 在「跨 DPI
--   拖曳」時會嚴重卡頓。改用 WebGpu(跨螢幕/跨縮放的重繪順很多),並用 LowPower 綁 Intel 內顯
--   (內顯驅動桌面合成,避免混顯跨卡複製造成的拖曳延遲)。
--   ※ 因為背景已改 win32_system_backdrop='Disable'(純視窗透明),WebGpu 不再有先前的純黑問題。
--   ┌ 若 WebGpu 下透明竟失效或閃退,退回這個階梯:
--   │  1) front_end='WebGpu' + webgpu_power_preference='LowPower'   ← 目前設定,拖曳最順
--   │  2) front_end='WebGpu' + webgpu_power_preference='HighPerformance' ← 走 NVIDIA,最快但拖曳可能更頓
--   │  3) front_end='OpenGL'                            ← 最穩保底,但多螢幕拖曳會頓
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'LowPower'  -- 綁 Intel 內顯:多螢幕拖曳更順 + 純透明照樣生效
config.max_fps = 120  -- 兩螢幕刷新率不同(144/240),鎖 120 讓合成負擔更平穩、拖曳更不易頓
config.animation_fps = 60

config.freetype_load_target = 'Light'
-- ★ 透明背景上用 LCD 次像素抗鋸齒(HorizontalLcd)字緣會出現彩色毛邊(色散);
--   毛玻璃生效後改用 'Normal'(灰階抗鋸齒)最乾淨。想更銳利可自行試回 'HorizontalLcd'。
config.freetype_render_target = 'Normal'

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
local ps_utf8 = '[Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::InputEncoding=[Text.Encoding]::UTF8; chcp 65001 > $null'
config.default_prog = { 'powershell.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 }

-- 全方位的編碼環境變數鎮壓，保證底層 POSIX 工具與編譯輸出中文零亂碼
config.set_environment_variables = { 
  LANG = 'en_US.UTF-8',
  LC_ALL = 'en_US.UTF-8',
  LESSCHARSET = 'utf-8',
  PYTHONIOENCODING = 'utf-8'
}

config.launch_menu = {
  { label = 'PowerShell', args = { 'powershell.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 } },
  { label = 'CMD',        args = { 'cmd.exe', '/k', 'chcp 65001 > nul' } },
}

--------------------------------------------------------------------
-- 9. 順手多工熱鍵 (Tmux 式分屏 / 毫秒秒切 / 調整大小)
--------------------------------------------------------------------
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
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
}

--------------------------------------------------------------------
-- 10. 滑鼠：選取自動複製 + 點擊開連結
--------------------------------------------------------------------
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE',
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor 'ClipboardAndPrimarySelection' },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor },
  { event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.Nop },
}

config.window_close_confirmation = 'NeverPrompt'

return config