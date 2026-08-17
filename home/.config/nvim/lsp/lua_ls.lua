-- =====================================================================
--  lua-language-server — 你主力在編輯的就是 .lua 設定檔，這隻最有感
--
--  ★ 這個目錄(nvim/lsp/)是 nvim 0.11 開始的原生機制：檔名就是 server 名，
--    回傳一個設定表，然後在 lua/lsp.lua 裡用 vim.lsp.enable('lua_ls') 打開。
--    這就是為什麼「加 LSP」不需要 nvim-lspconfig —— 套件數還是 5 個。
--
--  ★ 執行檔由 winget 裝在
--    %LOCALAPPDATA%\Microsoft\WinGet\Packages\LuaLS.lua-language-server_*\bin\
--    並把該目錄加進 user PATH(不是建 Links symlink —— 開發人員模式沒開時
--    winget 會靜默走這條 B 計畫)。所以這裡直接寫命令名，靠 PATH 找。
-- =====================================================================

return {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },

  -- ★ root_markers 決定「專案根目錄」在哪 —— server 會索引整個根目錄，所以
  --   這一項同時決定了跨檔案補全的範圍與記憶體用量。
  --
  -- ★★ 清單順序就是優先權(不是「由近到遠」)：nvim 會拿第一項往上找到底，
  --   找不到才換第二項。巢狀 list 表示同優先權。這裡 `init.lua` 必須排在
  --   `.git` 前面 —— 你的 nvim 設定真身在 D:\Project\dotfiles 這個 git repo
  --   裡面，`.git` 若排在前面，根目錄會被判成整個 dotfiles repo，於是
  --   下面 on_init 的「這是不是 nvim 設定目錄」比對就會失敗(實測過)。
  root_markers = {
    { '.luarc.json', '.luarc.jsonc' }, -- 明確宣告的專案根，最高優先
    'init.lua',                        -- nvim 設定 / lua 專案的入口
    { '.stylua.toml', 'stylua.toml', 'selene.toml' },
    '.git',                            -- 最後才退到版控根
  },

  -- ★ 記憶體優化(實測)：lua_ls 常駐 232MB，其中 212MB 就是下面 workspace.library
  --   那份 VIMRUNTIME 型別標註 —— 拿掉之後只剩 20MB，但 vim.api.* 的補全會
  --   直接歸零(實測候選數 0)。所以那 212MB 不是浪費，它就是功能本身。
  --
  --   唯一真正免費的省法：只有在編輯「會用到 nvim API 的專案」時才載入它。
  --   編 wezterm.lua 或任何其他 lua 檔時，那 212MB 買到的 vim.* 你根本用不到。
  --
  -- ★ 誤判時的逃生口：在專案根放一個 .luarc.json，lua_ls 會優先讀它，
  --   裡面自己指定 workspace.library 即可蓋掉這裡的判斷。
  on_init = function(client)
    -- ★ 一定要走 fs_realpath 再比對，不能只用 fs.normalize。這台機器上同一份
    --   設定有三個入口，字串長得完全不一樣：
    --       %LOCALAPPDATA%\nvim          (nvim 認得的 stdpath('config'))
    --       ~\.config\nvim               (你平常打的路徑)
    --       D:\Project\dotfiles\home\... (真身，前兩個都是連結指過來的)
    --   realpath 之後三個才會收斂成同一個。少了這一步，你從 dotfiles 那條
    --   路徑開設定檔就會被誤判成「不是 nvim 專案」而丟掉 library。
    local function canon(p)
      if not p or p == '' then return nil end
      return vim.fs.normalize(vim.uv.fs_realpath(p) or p)
    end

    local root = canon(client.config.root_dir)
    local nvim_config = canon(vim.fn.stdpath('config'))

    local function has(dir) return vim.uv.fs_stat(dir) ~= nil end

    local is_nvim_project = root ~= nil
      and (
        -- 1. 就是你的 nvim 設定目錄(或它底下的子目錄)
        (nvim_config ~= nil and (root == nvim_config or vim.startswith(root .. '/', nvim_config .. '/')))
        -- 2. 長得像 nvim 外掛的專案：有 lua/ 而且有 plugin/ 或 doc/
        or (has(root .. '/lua') and (has(root .. '/plugin') or has(root .. '/doc')))
      )

    if not is_nvim_project then
      client.config.settings.Lua.workspace.library = {}
    end
  end,

  settings = {
    Lua = {
      runtime = {
        -- nvim 內嵌的是 LuaJIT，不是標準 Lua 5.x。講錯的話標準函式庫會對不上。
        version = 'LuaJIT',
        -- ★ 讓 server 看得懂 require('options') —— 它要知道模組是從 lua/ 底下
        --   解析的，否則你設定裡每一行 require 都會被標成找不到模組。
        path = { 'lua/?.lua', 'lua/?/init.lua' },
      },

      workspace = {
        -- ★ 這一行就是「vim.api.nvim_buf_set_lines 會不會跳出來」的關鍵：
        --   把 nvim 自己的 runtime 掛成函式庫，裡面的 lua/vim/_meta/ 有完整的
        --   API 型別標註。沒有這行的話 vim.* 全部無法補全。
        library = {
          vim.env.VIMRUNTIME,
          '${3rd}/luv/library', -- vim.uv.*(計時器、檔案系統)的型別
        },
        -- 別跳「要不要套用 luassert/busted 設定?」那種互動式問題 —— headless
        -- 情境下沒人回答，server 會卡在那裡。
        checkThirdParty = false,
      },

      -- 保險絲：萬一 library 沒載成功，至少 vim 不會被當成未定義的全域變數。
      diagnostics = { globals = { 'vim' } },

      telemetry = { enable = false },
    },
  },
}
