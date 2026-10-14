-- =====================================================================
--  yazi.nvim：在 nvim 中開啟 yazi 切換檔案
--
--  plenary 是 yazi.nvim 的相依套件（用於解析路徑）。lazy.nvim 會自動安裝相依套件，
--    但內建的 vim.pack 不會，因此須自行列出（yazi.nvim 的 README 亦有說明）。
--    此功能實際佔用 2 個外掛。
--
--  Windows 支援：作者標示的最低需求為 Windows 11。
--    遇到問題時可執行 :checkhealth yazi，檢查 yazi 版本與相依項目。
--
--  已知限制：「複製相對路徑」功能需要 realpath 指令，
--    Windows 的 PATH 上沒有此指令（Git for Windows 有附帶，但未加入 PATH）。
--    其他功能不受影響。
--
--  open_for_directories = true：`nvim <目錄>`、`nvim .`、`:e <目錄>` 一律改開 yazi。
--    這是「原生優先」原則的刻意例外，代價是 netrw 整個停用（:Explore 不再存在）。
--    loaded_netrwPlugin 讓 netrw 完全不載入（README 建議的寫法）；
--    此 config 在 init.lua 期間執行，早於 runtime 的 plugin/ 載入，因此來得及。
--
--  圖片預覽：nvim 終端機不支援圖形協定，只能讓 yazi 改用 chafa 以字元近似顯示
--    （需 winget 安裝 hpjansson.Chafa）。要看原始畫質請直接在 WezTerm 中執行 yazi。
--    但 yazi 會從繼承的 TERM_PROGRAM、WEZTERM_* 誤判自己在 WezTerm 中，
--    送出的圖片被 nvim 終端機丟棄。因此下方包裝 require('yazi').yazi，
--    在啟動 yazi 期間暫時移除這些變數。調查過程見 docs/nvim.md；
--    check.ps1 會實測這個包裝在外掛更新後是否仍有效。
-- =====================================================================

return {
  plugin = {
    { src = 'https://github.com/nvim-lua/plenary.nvim' },
    { src = 'https://github.com/mikavilpas/yazi.nvim' },
  },

  config = function()
    vim.g.loaded_netrwPlugin = 1

    require('yazi').setup({
      open_for_directories = true,

      keymaps = {
        -- 停用「複製相對路徑」：此功能需要 realpath，Windows 上沒有。
        --   這是官方 healthcheck 建議的做法（原始碼中 false 即為停用）；
        --   若不停用，:checkhealth yazi 會持續顯示一個無法修復的警告。
        copy_relative_path_to_selected_files = false,
      },

      -- 在 yazi 目前所在目錄或選取的檔案中進行全文搜尋時，使用 fzf-lua。
      integrations = {
        grep_in_directory = 'fzf-lua',
        grep_in_selected_files = 'fzf-lua',
      },
    })

    local yazi = require('yazi')
    local launch = yazi.yazi
    ---@diagnostic disable-next-line: duplicate-set-field
    yazi.yazi = function(...)
      local saved = {}
      for name in pairs(vim.fn.environ()) do
        if name == 'TERM_PROGRAM' or name == 'TERM_PROGRAM_VERSION' or name:match('^WEZTERM_') then
          saved[name] = vim.env[name]
          vim.env[name] = nil
        end
      end
      -- 即使 launch 出錯也要還原環境變數，錯誤再原樣拋出
      local ok, err = pcall(launch, ...)
      for name, value in pairs(saved) do
        vim.env[name] = value
      end
      if not ok then error(err, 0) end
    end
  end,
}
