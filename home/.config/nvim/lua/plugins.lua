-- =====================================================================
--  外掛載入器
--
--  lua/plugins/ 下的每個 .lua 檔回傳一個 table：
--      {
--        plugin = <一個 spec 或 spec 陣列>,   -- 交給 vim.pack.add()
--        config = function() ... end,          -- 安裝完成後執行的設定
--      }
--
--  採用此結構後，新增或移除外掛只需新增或刪除一個檔案，不必修改任何清單。
--    結構參考自 gh0stzk/dotfiles（同樣使用 vim.pack）。
--
--  config 以 pcall 執行：任一外掛出錯時（例如更新後 API 變更、安裝中斷），
--    nvim 仍可正常啟動並編輯檔案。全域設定的主要風險在於單點錯誤會導致
--    所有 nvim 無法使用，pcall 可將錯誤限制在此處。
--    錯誤不會被忽略，會以 vim.notify 顯示出錯的檔案。
-- =====================================================================

local plugin_dir = vim.fn.stdpath('config') .. '/lua/plugins'

local specs = {}
local configs = {}

for _, file in ipairs(vim.fn.readdir(plugin_dir)) do
  if file:match('%.lua$') then
    local name = file:gsub('%.lua$', '')
    local ok, mod = pcall(require, 'plugins.' .. name)

    if not ok then
      vim.notify(('[plugins] 載入 %s 失敗：%s'):format(file, mod), vim.log.levels.ERROR)
    else
      if mod.plugin then
        -- 有 src 欄位即為單一 spec；否則視為 spec 陣列並展開
        if mod.plugin.src then
          specs[#specs + 1] = mod.plugin
        else
          vim.list_extend(specs, mod.plugin)
        end
      end

      if type(mod.config) == 'function' then
        configs[#configs + 1] = { name = name, fn = mod.config }
      end
    end
  end
end

-- 安裝外掛。首次執行時會 git clone 到
--   %LOCALAPPDATA%\nvim-data\site\pack\core\opt\，之後僅加入 runtimepath。
--   實際 commit 記錄於 nvim-pack-lock.json，未手動更新前版本固定不變。
vim.pack.add(specs)

for _, cfg in ipairs(configs) do
  local ok, err = pcall(cfg.fn)
  if not ok then
    vim.notify(('[plugins] %s 的設定出錯：%s'):format(cfg.name, err), vim.log.levels.WARN)
  end
end
