-- =====================================================================
--  nvim-treesitter：讓 C++ / Python 等語言的語法上色完整
--
--  沒有 treesitter 時，nvim 使用舊式的 regex 語法檔上色，只認得關鍵字、字串、數字，
--    型別名、函式名、成員、模組名都會與一般文字同色（實測數據見 docs/nvim.md）。
--    LSP 的 semantic tokens 要等 server 索引完才有；treesitter 在開檔當下即完成上色。
--
--  nvim 0.12 只內建 c、lua、markdown、markdown_inline、query、vim、vimdoc 的 parser；
--    其他語言的 parser 由本套件下載原始碼後編譯。
--
--  使用 main 分支（master 分支已凍結，不支援 nvim 0.12）。main 分支本身不會啟動上色，
--    只負責安裝 parser 與提供 query，啟動由下方的 FileType autocmd 處理。
--
--  外部需求（只有編譯 parser 時才需要，編好之後兩者都可移除）：
--    tree-sitter CLI   winget install tree-sitter.tree-sitter-cli
--    C 編譯器           不需設定，tree-sitter CLI 會自動找到 Visual Studio 的 MSVC。
--                       沒有 Visual Studio 時：先設定 CC=gcc 再 :TSInstall，改用 mingw。
--
--  parser 編譯後放在 %LOCALAPPDATA%\nvim-data\site\parser\，屬於拋棄式快取。
--  新增語言：把名稱加入下方 parsers 清單即可，下次啟動時會在背景編譯。
--    臨時需要時也可直接執行 :TSInstall <語言>。
-- =====================================================================

-- nvim 內建的 parser 也一併安裝：本套件的 query 是依最新版 parser 撰寫的，
--   搭配 nvim 內建的舊版 parser 可能出現 query 錯誤。
local parsers = {
  'c', 'cpp', 'python', 'rust',                      -- 主力語言（與 LSP 對應）
  'lua', 'vim', 'vimdoc', 'query',                   -- nvim 設定與說明文件
  'markdown', 'markdown_inline',
  'toml', 'json', 'yaml', 'powershell', 'bash',      -- dotfiles 裡的設定檔與腳本
}

return {
  plugin = { src = 'https://github.com/nvim-treesitter/nvim-treesitter', version = 'main' },

  config = function()
    -- 先自行比對缺少哪些 parser，全部已安裝時（平常的狀態）完全不呼叫 install()。
    --   沒有 tree-sitter CLI 的新機器若直接呼叫，每次啟動都會下載原始碼後編譯失敗，
    --   每個 parser 各跳一條錯誤；改成只提示一次缺少什麼。
    --   executable() 在本機很慢（見 lua/lsp.lua），因此只在確實缺少時才檢查。
    local ts = require('nvim-treesitter')
    -- 必須傳 'parsers'：不帶參數時 query 與 parser 取聯集，parser 遺失但 query 還在時會誤判為已安裝。
    local installed = ts.get_installed('parsers')
    local missing = vim.tbl_filter(function(lang)
      return not vim.list_contains(installed, lang)
    end, parsers)

    if #missing > 0 then
      if vim.fn.executable('tree-sitter') == 1 then
        -- 在背景編譯，不阻塞啟動。編譯期間已開啟的檔案不會自動上色，需重新開啟（:e）。
        ts.install(missing)
      else
        vim.notify(
          ('[treesitter] 缺少 tree-sitter CLI，未編譯：%s\n'
            .. '  安裝：winget install tree-sitter.tree-sitter-cli'):format(table.concat(missing, ' ')),
          vim.log.levels.WARN
        )
      end
    end

    -- 對所有檔案類型嘗試啟動 treesitter 上色，有 parser 的才會成功。
    --   不限定 parsers 清單：以 :TSInstall 臨時加裝的語言也能直接生效。
    --   沒有 parser 的類型維持原本的 regex 上色。
    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('treesitter-start', { clear = true }),
      desc = '有 parser 的檔案類型改用 treesitter 上色',
      callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
      end,
    })
  end,
}
