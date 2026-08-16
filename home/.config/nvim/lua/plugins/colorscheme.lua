-- =====================================================================
--  tokyonight — 對齊 WezTerm 與 starship
--
--  ★ style = 'night' 的背景色是 #1a1b26，跟你 wezterm.lua 裡自訂的
--    ['Tokyo Night'] 那組 background 完全同一個色號，所以兩邊接得上。
--
--  ★ transparent 保持 false(實色)。你的 WezTerm 是 window_background_opacity
--    = 0.90 的玻璃，開 transparent 會讓玻璃感延伸進 nvim，但代價是整片
--    程式碼都飄在桌面上 —— 你在 wezterm.lua 裡替 tab bar 加襯底時已經寫過
--    這個坑(細字背後一亮就消失)。而且 CursorLine / Visual / Search 這些
--    靠背景色區分的東西會一起變弱。
-- =====================================================================

return {
  plugin = { src = 'https://github.com/folke/tokyonight.nvim' },

  config = function()
    require('tokyonight').setup({
      style = 'night',
      transparent = false,
      styles = {
        sidebars = 'dark',
        floats = 'dark',
      },
    })

    vim.cmd.colorscheme('tokyonight-night')
  end,
}
