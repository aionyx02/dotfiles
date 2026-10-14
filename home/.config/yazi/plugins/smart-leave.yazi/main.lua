--- @since 26.5.6
-- =====================================================================
--  smart-leave：以 h / <Left> 返回上層，已在最上層時開啟磁碟機選單
--
--  Windows 沒有 Unix 的單一根目錄，C:\ 沒有上一層，
--  因此在 C:\ 按 h（leave）時 yazi 沒有反應。
--  此外掛在最上層時改為開啟 drives 選單，以便切換到其他磁碟機；
--  其餘情況皆執行內建的 leave，行為不變。
-- =====================================================================

local cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local function entry()
	-- 先統一為正斜線再比對，避免在 Lua pattern 中跳脫反斜線。
	local p = cwd():gsub("\\", "/")

	-- 以下兩種情況視為已在最上層：
	--   C:/                     磁碟機根目錄
	--   //wsl.localhost/Ubuntu  UNC 分享根目錄（上一層為主機名稱，無法列舉）
	local at_root = p:match("^%a:/?$") or p:match("^//[^/]+/[^/]+/?$")

	if at_root then
		require("drives"):entry()
	else
		ya.emit("leave", {})
	end
end

return { entry = entry }
