-- =====================================================================
--  WezTerm 設定（Windows）
--  內容：半透明背景、Tokyo Night 配色、UTF-8 編碼、圓角分頁列、
--        類 tmux 的分割窗格鍵位
-- =====================================================================

local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Tokyo Night（Night 變體）色票，供配色表、分頁列與狀態列引用
local M = {
  base = '#1a1b26', mantle = '#16161e', crust = '#101014',
  text = '#c0caf5', subtext0 = '#a9b1d6', overlay0 = '#565f89',
  surface0 = '#24283b', surface1 = '#414868', selection = '#33467c',
  blue = '#7aa2f7', magenta = '#bb9af7',
  sapphire = '#7dcfff', teal = '#73daca', green = '#9ece6a',
  peach = '#ff9e64', yellow = '#e0af68', red = '#f7768e',
}

-- 視窗背景透明度；Ctrl+Shift+B 在此值與 1.0 之間切換
local OPACITY = 0.90

--------------------------------------------------------------------
-- 1. 視窗透明度
--------------------------------------------------------------------
-- 不使用 Windows Acrylic：失焦時 DWM 可能將其換成近似實色。
-- 改用純 alpha 透明，後方視窗不模糊，但聚焦與失焦的透明度一致。
config.win32_system_backdrop = 'Disable'
config.window_background_opacity = OPACITY  -- 保留透明感，同時維持 Tokyo Night 的對比
config.text_background_opacity = 1.0        -- Powerline 色塊保持不透明，避免與背景重疊

--------------------------------------------------------------------
-- 2. 配色
--------------------------------------------------------------------
-- 注意：配色須集中在同一個 table 內定義；分開覆寫會導致背景變為不透明。
-- ANSI 的綠色一格使用 M.teal 而非 M.green。
config.color_schemes = {
  ['Tokyo Night'] = {
    foreground = M.subtext0,
    background = M.base,
    cursor_bg = M.text,
    cursor_fg = M.base,
    cursor_border = M.text,
    selection_bg = M.selection,
    selection_fg = M.text,
    ansi = {
      M.surface1, M.red, M.teal, M.yellow,
      M.blue, M.magenta, M.sapphire, M.text,
    },
    brights = {
      M.overlay0, M.red, M.teal, M.yellow,
      M.blue, M.magenta, M.sapphire, M.subtext0,
    },
  },
}
config.color_scheme = 'Tokyo Night'

-- 分頁列背景色。
-- 若設為完全透明，分頁列會比視窗本體（0.90）更透，
-- 狀態列文字在明亮的桌面背景上將難以辨識，因此使用較不透明的深色。
-- 調整 alpha 即可在透明感與可讀性之間取捨（0.70 較透明，0.95 接近不透明）。
local BAR_BG = 'rgba(16, 17, 22, 0.85)'

config.colors = {
  tab_bar = {
    background = BAR_BG,
  },
}

--------------------------------------------------------------------
-- 3. 視窗外框與內距
--------------------------------------------------------------------
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.integrated_title_button_style = 'Windows'
config.integrated_title_buttons = { 'Hide', 'Maximize', 'Close' }
config.window_padding = { left = 16, right = 16, top = 14, bottom = 12 }
config.inactive_pane_hsb = { saturation = 0.65, brightness = 0.42 }  -- 調暗非作用中的窗格以突顯目前窗格（數值越小越暗）

--------------------------------------------------------------------
-- 4. 字型與排版
--------------------------------------------------------------------
-- 首選 WezTerm 內建的 JetBrains Mono，確保字型一定存在；
-- 中文由 Microsoft YaHei 遞補，避免顯示為方框或字距錯亂。
config.font = wezterm.font_with_fallback {
  -- 字重 Medium：在透明背景上較清晰；'zero'：斜線 0，便於區分 0 與 O
  { family = 'JetBrains Mono', weight = 'Medium', harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1', 'zero' } },
  { family = 'JetBrainsMono NF', weight = 'Medium', harfbuzz_features = { 'calt=1', 'clig=1', 'liga=1', 'zero' } },
  'Microsoft YaHei',            -- 中文遞補字型
  'Symbols Nerd Font Mono',
  'Segoe UI Emoji',
}
config.font_size = 11.5
-- 注意：不要設定 config.dpi。
--   固定 DPI 會停用 WezTerm 的 per-monitor DPI 感知，視窗縮放或跨螢幕時
--   實體像素與算繪視埠不一致，swapchain 會留下未繪製的區域；
--   在透明視窗上，該區域會顯示後方視窗內容，造成破圖與疊影。
--   跨不同縮放比例的螢幕時會重建 glyph atlas，拖曳時短暫停頓屬正常現象。
config.line_height = 1.15       -- 略為加大行高
-- 略為提高前景文字亮度，使文字在透明背景上更清楚（1.0 為原始亮度）。
--   數值過高（如 1.08）會壓縮抗鋸齒的灰階層次，字緣反而出現鋸齒；
--   1.02 可提亮且不影響抗鋸齒。
config.foreground_text_hsb = { hue = 1.0, saturation = 1.0, brightness = 1.02 }

--------------------------------------------------------------------
-- 5. 游標
--------------------------------------------------------------------
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'EaseInOut'
config.cursor_blink_ease_out = 'EaseInOut'

--------------------------------------------------------------------
-- 6. 分頁列：圓角分頁
--------------------------------------------------------------------
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
-- 注意：分頁列必須常駐。
--   window_decorations 使用 INTEGRATED_BUTTONS，視窗按鈕與拖曳區都在分頁列上；
--   只有一個分頁時若隱藏分頁列，視窗將無法移動或關閉。
config.hide_tab_bar_if_only_one_tab = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 26

-- 取得行程名稱：去除路徑與 .exe 並轉為小寫。
-- Windows 回傳的名稱帶有 .exe（如 nvim.exe），須先去除才能對應下方的表。
local function process_name(path)
  return ((path or ''):gsub('.*[/\\]', ''):lower():gsub('%.exe$', ''))
end

-- 這些行程代表 WSL 分頁，分頁標題與狀態列一律顯示為 Ubuntu
local WSL_PROCS = { wsl = true, wslhost = true, ubuntu = true }

-- 行程名稱（不含 .exe）對應的分頁圖示
local process_icons = {
  ['powershell']     = wezterm.nerdfonts.md_powershell,
  ['pwsh']           = wezterm.nerdfonts.md_powershell,
  ['cmd']            = wezterm.nerdfonts.md_console,
  ['wsl']            = wezterm.nerdfonts.cod_terminal_bash,
  ['wslhost']        = '',
  ['ubuntu']         = '',
  ['bash']           = wezterm.nerdfonts.cod_terminal_bash,
  ['nvim']           = wezterm.nerdfonts.custom_vim,
  ['vim']            = wezterm.nerdfonts.custom_vim,
  ['node']           = wezterm.nerdfonts.md_nodejs,
  ['python']         = wezterm.nerdfonts.md_language_python,
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
  -- rim：分頁兩端半圓的顏色；作用中的分頁使用較亮的藍色作為外緣
  local bg, fg, rim = M.surface0, M.subtext0, M.surface0   -- 非作用中：暗灰
  if tab.is_active then
    bg, fg, rim = M.blue, M.crust, '#a6e3ff'               -- 作用中：藍底、亮藍外緣、粗體
  elseif hover then
    bg, fg, rim = M.surface1, M.text, M.surface1
  end
  local proc = process_name(tab.active_pane.foreground_process_name)
  local icon = process_icons[proc] or wezterm.nerdfonts.md_console_line
  local title = (tab.active_pane.title or ''):gsub('%.exe$', '')
  if WSL_PROCS[proc] then
    icon = ''
    title = 'Ubuntu'
  end
  -- 依顯示寬度截斷；string.sub 以位元組計算，會切壞中文的 UTF-8 編碼。
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
-- 6b. 狀態列：系統、工作區、目前目錄、時間、電量
--------------------------------------------------------------------
wezterm.on('update-status', function(window, pane)
  local status_proc = process_name(pane:get_foreground_process_name())
  local system_icon = wezterm.nerdfonts.md_microsoft_windows
  local system_name = 'Windows'
  if WSL_PROCS[status_proc] then
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

-- 不註冊 window-focus-changed：聚焦與失焦使用相同的透明度。

--------------------------------------------------------------------
-- 7. 算繪與效能
--------------------------------------------------------------------
-- 本機為混合顯卡（NVIDIA RTX 4060 Laptop + Intel UHD），螢幕由 Intel 內顯輸出。
--   OpenGL 前端（搭配 prefer_egl）經由 ANGLE/D3D11，在混合顯卡上調整視窗大小時
--   容易殘留舊的 buffer，造成疊影與破圖。
--   因此使用 WebGpu（此版本的預設前端），並以 LowPower 指定 Intel 內顯，
--   讓算繪與輸出在同一張顯卡上，避免跨 adapter 導致 alpha 失效。
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'LowPower'

-- 使用官方預設的 60 fps。
--   Intel 內顯需在 191 PPI、150% 縮放的面板上算繪透明視窗，且每一幀都要由 DWM 合成；
--   終端機程式在 120 fps 下看不出差異，GPU 與合成器的負載卻加倍。
config.max_fps = 60

-- 使用官方預設的 10 fps。
--   此值僅控制閃爍游標、閃爍文字與 visual bell 的緩動動畫幀率；
--   搭配 EaseInOut 時，即使沒有任何操作也會持續以此幀率重繪。
--   若需進一步降低負載，官方建議低資源環境使用
--     animation_fps = 1，並將 cursor_blink_ease_in / out 設為 'Constant'，
--   此時游標改為無緩動的開關閃爍。
config.animation_fps = 10

-- 191 PPI 面板在 150% 縮放下等效 144 DPI，屬於高 DPI 環境。
--   高 DPI 下 hinting 會將字形輪廓強制對齊像素格而扭曲字形，因此關閉。
config.freetype_load_flags = 'NO_HINTING'
config.freetype_load_target = 'Light'
-- 使用灰階抗鋸齒（'Normal'），不使用 HorizontalLcd。
--   次像素抗鋸齒需要已知背景色才能正確分配 RGB 子像素，
--   但透明視窗的背景由 DWM 事後合成，字緣會出現彩色毛邊；
--   若要改用 HorizontalLcd，須先關閉透明度。
config.freetype_render_target = 'Normal'

-- update-status 預設每秒執行一次，其中 battery_info()（Windows 上為同步查詢）
--   與 get_foreground_process_name() 都有成本；狀態列只顯示到分鐘，
--   改為每 2 秒更新即可將輪詢次數減半。
config.status_update_interval = 2000

-- 關閉缺字警告。
--   部分工具會輸出 U+EA12、U+EA54 等碼位，這些碼位位於 Nerd Fonts 的
--   Devicons（至 E8EF）與 Codicons（自 EA60）之間的未分配區段，任何字型都不包含，
--   安裝其他字型也無法解決，只會反覆跳出警告；該字元仍會顯示為方框。
--   已確認 E5FA、E702、EA60、EA71、F07B、F17A 均可由 JetBrainsMono Nerd Font 正常顯示。
config.warn_about_missing_glyphs = false

config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_function = 'EaseIn',  fade_in_duration_ms = 75,
  fade_out_function = 'EaseOut', fade_out_duration_ms = 150,
  target = 'CursorColor',
}
config.scrollback_lines = 20000
config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- 關閉更新檢查與提示
config.check_for_updates = false

--------------------------------------------------------------------
-- 8. Shell 與編碼（統一使用 UTF-8，避免 Python、Git 的中文亂碼）
--------------------------------------------------------------------
-- 設定 [Console]::OutputEncoding / InputEncoding 時，.NET 內部即會呼叫
--   SetConsoleOutputCP / SetConsoleCP(65001)，效果等同 chcp 65001，
--   因此不需要再執行 chcp（每個分頁可省下一次約 34ms 的行程啟動）。
--   已驗證：父行程為 cp950 時，設定後子行程的 chcp 回報 65001。
local ps_utf8 = '[Console]::OutputEncoding=[Text.Encoding]::UTF8; [Console]::InputEncoding=[Text.Encoding]::UTF8'
-- pwsh.exe 為 PowerShell 7，與系統內建的 powershell.exe（5.1）並存
local pwsh_args = { 'pwsh.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 }
config.default_prog = pwsh_args

-- 讓 POSIX 工具與編譯器輸出一律使用 UTF-8
config.set_environment_variables = { 
  LANG = 'en_US.UTF-8',
  LC_ALL = 'en_US.UTF-8',
  LESSCHARSET = 'utf-8',
  PYTHONIOENCODING = 'utf-8'
}

config.launch_menu = {
  { label = 'PowerShell 7',   args = pwsh_args },
  { label = 'Windows PowerShell 5.1', args = { 'powershell.exe', '-NoLogo', '-NoExit', '-Command', ps_utf8 } },
  { label = 'Ubuntu (WSL)', args = { 'wsl.exe', '-d', 'Ubuntu', '--cd', '~' } },
  { label = 'CMD',        args = { 'cmd.exe', '/k', 'chcp 65001 > nul' } },
}

--------------------------------------------------------------------
-- 9. 鍵位：分割窗格、切換、調整大小、分頁
--------------------------------------------------------------------
-- Ctrl+C：有選取文字時複製；沒有選取時將 Ctrl+C 傳給前景程式以中斷執行。
local copy_selection_or_interrupt = wezterm.action_callback(function(window, pane)
  local selection = window:get_selection_text_for_pane(pane)
  if selection and selection ~= '' then
    window:perform_action(act.CopyTo 'Clipboard', pane)
  else
    window:perform_action(act.SendKey { key = 'c', mods = 'CTRL' }, pane)
  end
end)

-- 注意：Ctrl+V 以 PasteFrom 將剪貼簿文字送入前景程式。
--   yazi 等 TUI 會將每個字元當成按鍵解讀，例如路徑中的「:」會開啟 shell 指令提示，
--   其後的字元全被輸入到提示中。若需讓特定 TUI 自行處理 Ctrl+V，
--   請比照 copy_selection_or_interrupt，以 action_callback 判斷前景行程，
--   不要改成無條件的 SendKey。

config.keys = {
  -- 分割窗格（| 為左右並排，- 為上下並排）
  { key = '|',  mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '\\', mods = 'ALT|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-',  mods = 'ALT|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  { key = '_',  mods = 'ALT|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },
  -- 切換窗格（Alt + HJKL 或方向鍵）
  { key = 'h', mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  { key = 'LeftArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Left' },
  { key = 'DownArrow',  mods = 'ALT', action = act.ActivatePaneDirection 'Down' },
  { key = 'UpArrow',    mods = 'ALT', action = act.ActivatePaneDirection 'Up' },
  { key = 'RightArrow', mods = 'ALT', action = act.ActivatePaneDirection 'Right' },
  -- 調整窗格大小（Alt + Shift + HJKL）
  { key = 'h', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Left', 4 } },
  { key = 'j', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Down', 4 } },
  { key = 'k', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Up', 4 } },
  { key = 'l', mods = 'ALT|SHIFT', action = act.AdjustPaneSize { 'Right', 4 } },
  -- 分頁與窗格管理
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
  { key = 'w', mods = 'ALT',        action = act.CloseCurrentPane { confirm = false } },
  { key = 'z', mods = 'ALT',        action = act.TogglePaneZoomState },
  { key = 'Tab', mods = 'CTRL',        action = act.ActivateTabRelative(1) },
  { key = 'Tab', mods = 'CTRL|SHIFT',  action = act.ActivateTabRelative(-1) },
  -- 跳到第 N 個分頁（Ctrl+1～8），Ctrl+9 為最後一個分頁
  { key = '1', mods = 'CTRL', action = act.ActivateTab(0) },
  { key = '2', mods = 'CTRL', action = act.ActivateTab(1) },
  { key = '3', mods = 'CTRL', action = act.ActivateTab(2) },
  { key = '4', mods = 'CTRL', action = act.ActivateTab(3) },
  { key = '5', mods = 'CTRL', action = act.ActivateTab(4) },
  { key = '6', mods = 'CTRL', action = act.ActivateTab(5) },
  { key = '7', mods = 'CTRL', action = act.ActivateTab(6) },
  { key = '8', mods = 'CTRL', action = act.ActivateTab(7) },
  { key = '9', mods = 'CTRL', action = act.ActivateTab(-1) },
  -- 切換到上一個／下一個分頁
  { key = '[', mods = 'ALT', action = act.ActivateTabRelative(-1) },
  { key = ']', mods = 'ALT', action = act.ActivateTabRelative(1) },
  -- 窗格選取：每個窗格顯示一個字母，按下對應字母即切換到該窗格
  { key = ' ', mods = 'CTRL|SHIFT', action = act.PaneSelect { alphabet = 'asdfghjkl' } },
  -- 複製、貼上、指令面板
  -- Ctrl+V 由 WezTerm 直接貼上文字，避免前景 CLI 將其解讀為貼上圖片。
  { key = 'c', mods = 'CTRL',       action = copy_selection_or_interrupt },
  { key = 'v', mods = 'CTRL',       action = act.PasteFrom 'Clipboard' },
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'Insert', mods = 'CTRL',  action = act.CopyTo 'Clipboard' },
  { key = 'Insert', mods = 'SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
  -- Ctrl+Shift+B：切換透明度（OPACITY 與 1.0），不需修改設定檔。
  --   透明視窗每一幀都需 DWM 合成，是 Windows 上輸入延遲的常見原因；
  --   可藉此比較兩種狀態下的輸入延遲。
  { key = 'b', mods = 'CTRL|SHIFT', action = wezterm.action_callback(function(window, _)
      local o = window:get_config_overrides() or {}
      o.window_background_opacity = (o.window_background_opacity == 1.0) and OPACITY or 1.0
      window:set_config_overrides(o)
    end) },
}

--------------------------------------------------------------------
-- 10. 滑鼠：選取即複製、Ctrl+點擊開啟連結
--------------------------------------------------------------------
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'NONE',
    -- Windows 沒有 X11 Primary Selection；只寫入系統剪貼簿，減少非同步競爭。
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor 'Clipboard' },
  { event = { Up = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.OpenLinkAtMouseCursor },
  { event = { Down = { streak = 1, button = 'Left' } }, mods = 'CTRL',
    action = act.Nop },
}

config.window_close_confirmation = 'NeverPrompt'

return config
