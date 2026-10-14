-- =====================================================================
--  basedpyright：Python 的補全與型別檢查
--
--  ruff 只提供 lint 與格式化，不提供補全。
--    Python 由兩個 server 分工，兩者同時連接 .py 檔案，互不衝突：
--        basedpyright：補全、型別檢查、跳至定義、重新命名
--        ruff        ：即時標示問題與自動修正
--
--  使用 basedpyright 而非 pyright：官方 pyright 需要 node，
--    basedpyright 可從 PyPI 安裝並自帶執行環境，可沿用 uv 的管理方式
--    （`uv tool install basedpyright`，執行檔位於已在 PATH 上的 ~\.local\bin）。
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

  -- 使用專案的 .venv 解析 import。
  --   basedpyright 預設以系統 Python 解析 import，而本機全域 site-packages 刻意保持為空，
  --   導致專案中的 `import requests` 等皆被標為找不到模組，補全也無結果。
  --   server 啟動時若在專案根目錄找到 .venv，便將直譯器指向該處。
  on_init = function(client)
    local root = client.config.root_dir
    if not root then return end

    local py = root .. '/.venv/Scripts/python.exe' -- Windows 的 venv 目錄結構
    if vim.fn.executable(py) ~= 1 then return end

    client.settings = vim.tbl_deep_extend('force', client.settings or {}, {
      python = { pythonPath = py },
    })
  end,

  settings = {
    basedpyright = {
      analysis = {
        -- basedpyright 預設為 'recommended'：啟用所有檢查，未標註型別一律報錯，
        --   一般的既有專案會出現大量錯誤。
        --   'standard' 是官方 pyright 的預設值，只檢查實際的型別錯誤。
        --   嚴格程度：basic < standard < strict < recommended。
        typeCheckingMode = 'standard',

        -- 只診斷已開啟的檔案；設為 'workspace' 會在開啟專案時掃描整個專案。
        diagnosticMode = 'openFilesOnly',

        autoSearchPaths = true,
        useLibraryCodeForTypes = true, -- 套件沒有 .pyi 時，從原始碼推斷型別
      },
    },
  },
}
