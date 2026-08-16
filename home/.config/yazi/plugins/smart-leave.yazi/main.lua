--- @since 26.5.6
-- =====================================================================
--  smart-leave  ·  h / <Left> 退到頂就叫出磁碟機選單
--
--  問題根源：Windows 沒有 Unix 那種單一根目錄。C:\ 的上一層不存在，
--  所以在 C:\ 按 h(leave) 時 yazi 沒有任何地方可去，看起來就像「卡住」。
--  這個外掛在到頂時把 leave 換成 drives 選單，接回「上一層 → 選 D: → 進去」
--  的直覺操作。其餘情況原封不動走內建的 leave，沒有任何行為差異。
-- =====================================================================

local cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local function entry()
	-- 統一成正斜線再比對，省掉為了 \ 寫一堆跳脫的 Lua pattern。
	local p = cwd():gsub("\\", "/")

	-- 兩種「已經到頂」的情況：
	--   C:/                     磁碟機根目錄
	--   //wsl.localhost/Ubuntu  UNC 分享根目錄(再往上是主機名，列不出東西)
	local at_root = p:match("^%a:/?$") or p:match("^//[^/]+/[^/]+/?$")

	if at_root then
		require("drives"):entry()
	else
		ya.emit("leave", {})
	end
end

return { entry = entry }
