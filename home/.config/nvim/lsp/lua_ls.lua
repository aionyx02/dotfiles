-- =====================================================================
--  lua-language-server：Lua（nvim、wezterm、yazi 設定檔）
--
--  nvim/lsp/ 是 nvim 0.11 起的原生機制：檔名即 server 名稱，檔案回傳設定表，
--    再於 lua/lsp.lua 以 vim.lsp.enable('lua_ls') 啟用。
--    因此加入 LSP 不需要 nvim-lspconfig（套件數見 lua/lsp.lua）。
--
--  執行檔由 winget 安裝並加入 PATH，此處直接寫指令名稱（安裝位置見 docs/nvim.md）。
-- =====================================================================

return {
  cmd = { 'lua-language-server' },
  filetypes = { 'lua' },

  -- root_markers 決定專案根目錄。server 會索引整個根目錄，
  --   因此這也決定了跨檔案補全的範圍與記憶體用量。
  --
  -- 注意：清單順序即優先順序。nvim 會先以第一項一路向上搜尋，
  --   找不到才改用下一項；巢狀清單內的項目優先順序相同。
  --   `init.lua` 必須排在 `.git` 之前：nvim 設定位於 dotfiles 這個 git repo 中，
  --   若 `.git` 在前，根目錄會變成整個 repo，下方 on_init 的判斷就會失敗。
  root_markers = {
    { '.luarc.json', '.luarc.jsonc' }, -- 明確宣告的專案根目錄，優先順序最高
    'init.lua',                        -- nvim 設定或 Lua 專案的進入點
    { '.stylua.toml', 'stylua.toml', 'selene.toml' },
    '.git',                            -- 最後才使用版本控制的根目錄
  },

  -- lua_ls 的記憶體大多花在下方 workspace.library 的 VIMRUNTIME 型別標註，
  --   那是 vim.* 補全本身所需（數據見 docs/nvim.md）。
  --   因此只在用得到 nvim API 的專案載入；編輯 wezterm.lua 等其他 Lua 檔時清空。
  --
  -- 判斷錯誤時：在專案根目錄放置 .luarc.json，lua_ls 會優先讀取，
  --   在其中自行指定 workspace.library 即可覆蓋此處的判斷。
  on_init = function(client)
    -- 比對前必須先經過 fs_realpath：同一份設定有三個以連結互指的入口
    --   （stdpath('config')、~\.config\nvim、dotfiles 內的實際位置），只用 fs.normalize
    --   無法讓三者一致，從 dotfiles 路徑開檔時會被誤判為非 nvim 專案。
    local function canon(p)
      if not p or p == '' then return nil end
      return vim.fs.normalize(vim.uv.fs_realpath(p) or p)
    end

    local root = canon(client.config.root_dir)
    local nvim_config = canon(vim.fn.stdpath('config'))

    local function has(dir) return vim.uv.fs_stat(dir) ~= nil end

    local is_nvim_project = root ~= nil
      and (
        -- 1. nvim 設定目錄本身或其子目錄
        (nvim_config ~= nil and (root == nvim_config or vim.startswith(root .. '/', nvim_config .. '/')))
        -- 2. nvim 外掛專案：有 lua/，且有 plugin/ 或 doc/
        or (has(root .. '/lua') and (has(root .. '/plugin') or has(root .. '/doc')))
      )

    if not is_nvim_project then
      client.config.settings.Lua.workspace.library = {}
    end
  end,

  settings = {
    Lua = {
      runtime = {
        -- nvim 內嵌的是 LuaJIT 而非標準 Lua 5.x，設定錯誤會導致標準函式庫定義不符。
        version = 'LuaJIT',
        -- 讓 server 能解析 require('options')：模組從 lua/ 目錄下解析，
        --   否則設定中的每個 require 都會被標為找不到模組。
        path = { 'lua/?.lua', 'lua/?/init.lua' },
      },

      workspace = {
        -- 將 nvim 的 runtime 載入為函式庫，其中 lua/vim/_meta/ 含有完整的 API 型別標註。
        --   未設定時 vim.* 完全無法補全。
        library = {
          vim.env.VIMRUNTIME,
          '${3rd}/luv/library', -- vim.uv.*（計時器、檔案系統）的型別
        },
        -- 停用「是否套用 luassert / busted 設定」等互動式詢問；
        -- headless 情境下無人回應，server 會卡住。
        checkThirdParty = false,
      },

      -- 保險措施：即使 library 載入失敗，vim 也不會被視為未定義的全域變數。
      diagnostics = { globals = { 'vim' } },

      telemetry = { enable = false },
    },
  },
}
