-- =====================================================================
--  fzf-lua — 模糊找檔案 / 全文搜尋
--
--  ★ 為什麼是 fzf-lua 而不是 telescope：telescope 要快就得裝
--    telescope-fzf-native，那需要 make 或 cmake 編譯，這台機器兩個都沒有。
--    fzf-lua 直接呼叫你 PATH 上已經有的 fzf.exe / rg.exe / fd.exe，零編譯。
--
--  ★ 鍵位定義在 lua/keymaps.lua，不在這裡 —— 所有自訂鍵集中在同一個檔案，
--    要查「我到底綁了什麼」只看那一個檔就好。
-- =====================================================================

return {
  plugin = { src = 'https://github.com/ibhagwan/fzf-lua' },

  config = function()
    require('fzf-lua').setup({
      -- fzf 視窗的配色直接從當前 colorscheme 推導，才不會在 Tokyo Night
      -- 裡跳出一塊預設綠色的清單。
      fzf_colors = true,

      winopts = {
        height = 0.85,
        width = 0.85,
        preview = {
          -- 內建預覽器，不依賴 bat(這台沒裝)。
          default = 'builtin',
          layout = 'vertical',
          vertical = 'down:50%',
        },
      },
    })
  end,
}
