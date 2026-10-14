-- =====================================================================
--  fzf-lua：模糊搜尋檔案與全文搜尋
--
--  不使用 telescope：telescope 需要 telescope-fzf-native 才夠快，
--    而該套件須以 make 或 cmake 編譯，本機皆未安裝。
--    fzf-lua 直接呼叫 PATH 上的 fzf.exe、rg.exe、fd.exe，不需編譯。
--
--  鍵位定義於 lua/keymaps.lua，所有自訂鍵位集中在同一個檔案以便查閱。
-- =====================================================================

return {
  plugin = { src = 'https://github.com/ibhagwan/fzf-lua' },

  config = function()
    require('fzf-lua').setup({
      -- fzf 視窗配色依目前的 colorscheme 產生，
      -- 避免在 Tokyo Night 中出現預設的綠色清單。
      fzf_colors = true,

      winopts = {
        height = 0.85,
        width = 0.85,
        preview = {
          -- 使用內建預覽器，不依賴 bat（本機未安裝）。
          default = 'builtin',
          layout = 'vertical',
          vertical = 'down:50%',
        },
      },
    })
  end,
}
