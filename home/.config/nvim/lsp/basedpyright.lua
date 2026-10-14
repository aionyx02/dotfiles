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

  -- 決定用哪個 Python 解析 import。
  --   basedpyright 預設以系統 Python 解析 import，而本機全域 site-packages 刻意保持為空，
  --   導致 `import requests` 等皆被標為找不到模組，補全也無結果。依序嘗試：
  --     1. 專案根目錄的 .venv（uv 管理的專案）
  --     2. 目前啟用的 conda 環境（機器學習與資料科學）：先 conda activate 再開 nvim。
  --        base 除外：PowerShell 的 conda hook 每次開 shell 都會自動啟用 base，
  --        若採用 base，所有沒有 .venv 的檔案都會被導到 base。
  --   conda 的判斷不依賴專案根目錄：單檔練習腳本通常沒有 pyproject.toml 或 .git。
  on_init = function(client)
    local py
    local root = client.config.root_dir
    if root and vim.fn.executable(root .. '/.venv/Scripts/python.exe') == 1 then -- Windows 的 venv 目錄結構
      py = root .. '/.venv/Scripts/python.exe'
    elseif vim.env.CONDA_PREFIX and vim.env.CONDA_DEFAULT_ENV ~= 'base'
        and vim.fn.executable(vim.env.CONDA_PREFIX .. '/python.exe') == 1 then
      py = vim.env.CONDA_PREFIX .. '/python.exe'
    end
    if not py then return end

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
