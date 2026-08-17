-- =====================================================================
--  basedpyright — Python 的補全與型別檢查
--
--  ★ 為什麼不是 ruff：ruff 只做 lint 與格式化，它的補全清單是空的。
--    Python 這邊是兩隻分工(兩隻都會掛在 .py 上，不衝突)：
--        basedpyright → 補全、型別、跳定義、改名
--        ruff         → 「這行有問題」的即時標示與自動修正
--
--  ★ 為什麼是 basedpyright 而不是 pyright：pyright 官方版要 node，
--    basedpyright 從 PyPI 裝、自帶執行環境，剛好走你既有的 uv 路線
--    (`uv tool install basedpyright`，執行檔落在 ~\.local\bin，那個目錄
--    你的 PATH 上已經有了 —— ruff.exe 就在那)。
-- =====================================================================

return {
  cmd = { 'basedpyright-langserver', '--stdio' },
  filetypes = { 'python' },
  root_markers = {
    'pyproject.toml',
    'uv.lock',
    'pyrightconfig.json',
    'setup.py',
    'requirements.txt',
    '.git',
  },

  -- ★ 這裡是 uv 使用者的關鍵一步：basedpyright 預設是拿「系統 python」去解析
  --   import，而你的 site-packages 是刻意淨空的 —— 於是專案裡每一個
  --   `import requests` 都會被標成找不到模組，補全也全空。
  --   這段在 server 啟動時去專案根找 .venv，找到就把直譯器指過去。
  on_init = function(client)
    local root = client.config.root_dir
    if not root then return end

    local py = root .. '/.venv/Scripts/python.exe' -- Windows 的 venv 佈局
    if vim.fn.executable(py) ~= 1 then return end

    client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
      python = { pythonPath = py },
    })
  end,

  settings = {
    basedpyright = {
      analysis = {
        -- ★ basedpyright 的原廠預設是 'recommended'，那是「所有檢查全開 + 未標
        --   註型別一律報錯」—— 開一個正常的舊專案會滿江紅，紅到你不想看。
        --   'standard' 是 pyright 官方版的預設值，抓真正的型別錯誤而已。
        --   想更嚴格再往上調：basic < standard < strict < recommended。
        typeCheckingMode = 'standard',

        -- 只診斷開著的檔案。設 'workspace' 的話一開專案就會全庫掃一遍。
        diagnosticMode = 'openFilesOnly',

        autoSearchPaths = true,
        useLibraryCodeForTypes = true, -- 沒有 .pyi 的套件，直接讀原始碼推型別
      },
    },
  },
}
