-- =====================================================================
--  tokyonight：與 WezTerm、starship 配色一致
--
--  style = 'night' 的背景色為 #1a1b26，與 wezterm.lua 中自訂的
--    ['Tokyo Night'] background 相同。
--
--  transparent 保持 false（不透明）。WezTerm 的 window_background_opacity 為 0.90，
--    開啟 transparent 雖可延續透明效果，但程式碼會直接疊在桌面背景上，
--    背景明亮時文字難以辨識（與 wezterm.lua 中分頁列背景色的考量相同）；
--    CursorLine、Visual、Search 等依靠背景色區分的元素也會變得不明顯。
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
