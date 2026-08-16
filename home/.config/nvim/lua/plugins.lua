-- =====================================================================
--  外掛載入器
--
--  lua/plugins/ 底下每個 .lua 檔回傳一個 table：
--      {
--        plugin = <一個 spec 或 spec 陣列>,   -- 交給 vim.pack.add()
--        config = function() ... end,          -- 安裝完之後要跑的設定
--      }
--
--  ★ 為什麼要這一層：加或砍一個外掛時只要新增/刪除一個檔案，不必回來改
--    任何清單。結構借自 gh0stzk/dotfiles(他也是用 vim.pack)。
--
--  ★ 為什麼 config 要用 pcall 包：某個外掛出問題時(更新後 API 變了、
--    網路裝到一半…)，nvim 還是開得起來、還是能改檔案。這是全域設定唯一
--    真正的風險 —— 一個地方壞掉，所有 nvim 都壞 —— pcall 把它擋在這裡。
--    但錯誤不會被吞掉：會用 vim.notify 明確報出是哪個檔案出事。
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
        -- 單一 spec 用 src 判斷；沒有 src 的就當成 spec 陣列攤平進來
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

-- ★ 這一行就是「安裝」。第一次執行時會 git clone 到
--   %LOCALAPPDATA%\nvim-data\site\pack\core\opt\，之後只是掛進 runtimepath。
--   實際 commit 記在 nvim-pack-lock.json，不手動 update 就永遠停在那裡。
vim.pack.add(specs)

for _, cfg in ipairs(configs) do
  local ok, err = pcall(cfg.fn)
  if not ok then
    vim.notify(('[plugins] %s 的設定出錯：%s'):format(cfg.name, err), vim.log.levels.WARN)
  end
end
