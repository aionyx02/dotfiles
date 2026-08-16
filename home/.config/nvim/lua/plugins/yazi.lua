-- =====================================================================
--  yazi.nvim — 在 nvim 裡叫出你已經很熟的 yazi 來換檔案
--
--  ★ plenary 是 yazi.nvim 的依賴(用來解析路徑)。lazy.nvim 會自動幫使用者
--    裝依賴，但我們用的是內建的 vim.pack，所以要自己列出來 —— 這是
--    yazi.nvim 的 README 明講的。所以這個功能實際成本是 2 個外掛。
--
--  ★ Windows 支援：作者明確標示最低需求是 Windows 11(這台符合)。
--    有問題時打 :checkhealth yazi 會告訴你 yazi 版本、依賴到不到位。
--
--  ★ 已知的小洞：yazi.nvim 的「複製相對路徑」功能需要 realpath 這個指令，
--    Windows 上你的 PATH 沒有(Git for Windows 有附但沒暴露出來)。
--    其他功能都不受影響。
--
--  ★ open_for_directories 保持 false(預設)。開了會讓 `nvim 某目錄`
--    直接跳 yazi、取代 nvim 內建的 netrw —— 那是覆蓋原生行為，
--    跟這份設定「原生優先」的原則不合。要瀏覽目錄就按 \y。
-- =====================================================================

return {
  plugin = {
    { src = 'https://github.com/nvim-lua/plenary.nvim' },
    { src = 'https://github.com/mikavilpas/yazi.nvim' },
  },

  config = function()
    require('yazi').setup({
      open_for_directories = false,

      keymaps = {
        -- ★ 這個功能(複製相對路徑)需要 realpath，Windows 上沒有。
        --   關掉它是官方 healthcheck 建議的做法(原始碼裡 false 就是停用值)，
        --   不關的話 :checkhealth yazi 會一直掛一個永遠修不好的警告，
        --   久了你就會忽略整份健檢報告 —— 那才是真正的損失。
        copy_relative_path_to_selected_files = false,
      },

      -- yazi 裡選了檔案之後要用什麼方式開。保持預設(取代當前 buffer)，
      -- 這裡寫出來是為了讓你知道有這個開關。
      integrations = {
        -- 在 yazi 當下所在的目錄做全文搜尋時，用我們已經裝了的 fzf-lua。
        grep_in_directory = 'fzf-lua',
        grep_in_selected_files = 'fzf-lua',
      },
    })
  end,
}
