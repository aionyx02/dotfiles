--- @since 26.5.6
-- =====================================================================
--  everything  ·  <F4> / `e    全機檔名搜尋（voidtools Everything）
--
--  ★ 為什麼要寫外掛，不能用內建的 search --via=？
--    那個指令只認得 fd / rg / rga 三個引擎，沒有任何掛自訂引擎的介面
--    (對照官方 keymap 文件的 search 條目)。所以只能走
--    「外掛 → es.exe → fzf → cd/reveal」這條路。
--
--  ★ fzf 在這裡不是搜尋引擎。
--    --disabled 把 fzf 自己的模糊比對整個關掉，比對規則 100% 由 Everything
--    決定；fzf 退化成純粹的「檢視窗 + 選取器 + 方向鍵」。
--    這是必要的 — es.exe 只會把路徑印到 stdout，它沒有任何互動介面。
--    附帶好處：fzf 是獨立行程、有自己的鍵盤處理，所以上下鍵天生就會動 —
--    順手解掉了 yazi 過濾提示字元裡方向鍵無效的老問題(見 keymap.toml 的 f)。
--
--  ★ Everything 的兩個結構性盲區，決定了 s / S 為什麼不能被這個外掛取代：
--      1. 它讀的是 NTFS 的 MFT — \\wsl.localhost 底下的 ext4 完全看不見
--      2. 它只有檔名，沒有內容比對
--    所以 s(fd, 涵蓋 WSL) 與 S(rg, 內容搜尋) 都必須留著。
-- =====================================================================

-- 預設排除的路徑。Everything 的規則：查詢字串裡只要含有路徑分隔符，
-- 就改為比對「完整路徑」而非僅檔名 — 所以下面這些會匹配整條路徑。
-- ★ 刻意都不含空白字元：這串最後會被 fzf 交給 cmd.exe 解析，
--   沒有空白就完全不需要引號，也就繞開了所有跳脫問題。
--   (尤其別在結尾反斜線外再包雙引號 — \" 會被當成跳脫的引號。)
local EXCLUDES = {
	[[!C:\Windows\]],
	[[!\node_modules\]],
	[[!\.git\]],
	[[!\AppData\Local\Temp\]],
	[[!$RECYCLE.BIN]],
}

-- 單次查詢的筆數上限。這個值跟排序方式是綁在一起的決定：
-- 因為 --disabled 讓 fzf 原封不動顯示 es 回傳的順序，當查詢命中好幾千筆時，
-- 「排序」等於在決定你看得到哪 200 筆、其餘的你根本不知道存在。
-- 選 date-modified 遞減是因為廣泛查詢時「最近動過的」命中率最高 —
-- 若改成依路徑排，第一屏幾乎必然是 C:\ 開頭的系統路徑。
local LIMIT = "200"
local SORT = "date-modified-descending"

local M = {}

local state = ya.sync(function() return cx.active.current.cwd end)

---把 fzf 的多行輸出切成陣列（保留空行 — 第 2 行是空的代表按的是 Enter）。
local function split_lines(s)
	local t, start = {}, 1
	while true do
		local i = s:find("\n", start, true)
		if not i then
			if start <= #s then
				t[#t + 1] = (s:sub(start):gsub("\r$", ""))
			end
			return t
		end
		t[#t + 1] = (s:sub(start, i - 1):gsub("\r$", ""))
		start = i + 1
	end
end

---組出給 fzf 的 reload 指令字串。
---{q} 是 fzf 的佔位符，每敲一個字它就把當前輸入代進去重跑一次。
---@param scoped boolean 限當前目錄以下（否則全機）
---@param cwd Url
---@param filtered boolean 套用 EXCLUDES
local function es_command(scoped, cwd, filtered)
	local t = { "es.exe", "-n", LIMIT, "-sort", SORT }
	if scoped then
		-- cwd 可能含空白，這裡必須包引號；路徑結尾不會是反斜線以外的怪字元。
		t[#t + 1] = "-path"
		t[#t + 1] = '"' .. tostring(cwd) .. '"'
	end
	t[#t + 1] = "{q}"
	if filtered then
		for _, e in ipairs(EXCLUDES) do
			t[#t + 1] = e
		end
	end
	return table.concat(t, " ")
end

local function prompt(scoped, filtered)
	return string.format(
		"Everything · %s · %s > ",
		scoped and "當前目錄" or "全機",
		filtered and "已濾雜訊" or "不過濾"
	)
end

---跑一次 fzf，回傳 stdout。
---★ 切換鍵沒有用 fzf 的 transform action，改用 --expect + --print-query：
---  fzf 會在第 1 行印出當前查詢字串、第 2 行印出「結束時按的是哪個 expect 鍵」，
---  於是 Lua 這邊可以翻轉狀態、把查詢字串原樣餵回去重開一次 fzf。
---  使用體驗跟 transform 一樣（打到一半切換不會掉字），但完全不需要在
---  bind 字串裡嵌套 shell 指令 — 那在 Windows 上是引號地獄。
local function run_fzf(cwd, scoped, filtered, query)
	local cmd = es_command(scoped, cwd, filtered)

	-- ★ 每個 --bind 各自是一個 argv 元素，而 Command:arg() 是直接傳 argv、
	--   不經過任何 shell，所以這裡不需要任何跳脫。唯一會碰到 shell 的是
	--   fzf 自己執行 reload 指令的那一刻（Windows 上是 cmd.exe /s /c）。
	--   也因此用 "reload:" 的冒號形式而非 "reload(...)" — 冒號形式代表
	--   「到字串結尾都是指令」，不必擔心指令裡的括號被當成語法。
	local child, err = Command("fzf")
		:arg({
			"--disabled",
			"--layout=reverse",
			"--print-query",
			"--expect=ctrl-o,ctrl-t",
			"--query=" .. query,
			"--prompt=" .. prompt(scoped, filtered),
			"--header=Ctrl+O 全機/當前目錄（當前目錄僅限本機 NTFS）   Ctrl+T 雜訊過濾",
			"--bind=start:reload:" .. cmd,
			"--bind=change:reload:" .. cmd,
		})
		:cwd(tostring(cwd))
		:stdin(Command.INHERIT)
		:stdout(Command.PIPED)
		:spawn()

	if not child then
		return nil, Err("Failed to start `fzf`, error: %s", err)
	end

	local output, err = child:wait_with_output()
	if not output then
		return nil, Err("Cannot read `fzf` output, error: %s", err)
	end
	-- 0 = 有選取, 1 = 沒有任何符合, 130 = 使用者按 Esc/Ctrl+C 中斷。
	-- 後兩者都是正常結局，--print-query 仍然會把查詢字串印出來。
	local code = output.status.code
	if not output.status.success and code ~= 1 and code ~= 130 then
		return nil, Err("`fzf` exited with error code %s", code)
	end
	return output.stdout, nil
end

local function notify(content, level)
	ya.notify { title = "Everything", content = content, timeout = 8, level = level or "error" }
end

function M:entry()
	ya.emit("escape", { visual = true })

	local cwd = state()
	-- ★ 用 is_regular 而不是 spec.is_virtual。
	--   yazi 的 Url 有四種 scheme(Regular / Search / Archive / SFTP)，is_regular
	--   就是「scheme 是 Regular」。而 spec 是 main 分支的過渡期 API，26.5.6 沒有
	--   (本機的 mime-ext.yazi 用到它的那行還掛著 "TODO: remove" 註記)，
	--   照抄 main 分支的 fzf.lua 會直接 attempt to index a nil value。
	--
	--   這個檢查不能省：下面 Command("fzf"):cwd() 吃到 search:// 或 archive://
	--   這種路徑會直接 spawn 失敗，錯誤訊息還看不出原因。
	if not cwd.is_regular then
		return notify("目前在搜尋結果或壓縮檔內部，不是一般檔案系統 — 先 Esc 退出再用 F4", "warn")
	end

	-- ★ 先探一次，把兩種「安靜失敗」變成看得懂的訊息。
	--   這不是防禦性程式碼的癖好 — es.exe 在 Everything 沒跑時是回
	--   errorlevel 8 然後什麼都不印，接進 fzf 就只是一個空清單，
	--   使用者會以為是「搜尋不到」而不是「服務沒開」。
	--   -n 1 不帶查詢字串會取索引裡的第一筆，是毫秒級的，成本可以忽略。
	local probe, perr = Command("es.exe"):arg({ "-n", "1" }):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not probe then
		return notify(
			"找不到 es.exe（" .. tostring(perr) .. "）\n"
				.. "1. 未安裝 → winget install -e --id voidtools.Everything.Cli\n"
				.. "2. 已安裝但仍找不到 → 完整重開 WezTerm。winget 是改「使用者 PATH」，\n"
				.. "   而 WezTerm 只在啟動時繼承環境變數，Ctrl+Shift+R 重載設定不會更新 PATH。"
		)
	elseif probe.status.code == 8 then
		-- ★ 這個訊息刻意寫「客戶端」而不是「服務」— 兩者是不同的東西，
		--   而預設安裝很容易只有服務在跑：
		--     服務   Everything.exe -svc（LocalSystem）負責讀 MFT
		--     客戶端 Everything.exe（系統匣圖示）負責建立 es 要找的 IPC 視窗
		--   只有服務在跑時，Everything「看起來」是好的(工作管理員有行程、
		--   服務狀態 Running)，但 es 一律回 errorlevel 8。
		--   (2026-08-09 實際踩到：安裝後只有服務，客戶端從未啟動。)
		return notify(
			"Everything 客戶端沒有在執行（es 回報 errorlevel 8）。\n"
				.. "注意：只有「服務」在跑是不夠的 — es 要的是客戶端建立的 IPC 視窗。\n"
				.. "從開始功能表啟動 Everything，並在 Tools → Options → General\n"
				.. "勾選 Start Everything on system startup，否則重開機後又會失效。"
		)
	end

	local permit = ui.hide()
	local scoped, filtered, query = false, true, ""
	local target

	while true do
		local out, err = run_fzf(cwd, scoped, filtered, query)
		if not out then
			permit:drop()
			return notify(tostring(err))
		end

		local lines = split_lines(out)
		query = lines[1] or ""
		local key = lines[2] or ""

		if key == "ctrl-o" then
			scoped = not scoped
		elseif key == "ctrl-t" then
			filtered = not filtered
		else
			target = lines[3]
			break
		end
	end
	permit:drop()

	if not target or target == "" then
		return
	end

	-- 跟內建 fzf 外掛同一套語意：目錄就進去，檔案就跳到它旁邊。
	-- reveal 而非 open 是刻意的 — 全機搜尋找到檔案之後多半還有下一步
	-- (複製、改名、看預覽)，落在它旁邊比直接開啟更有用，要開再按一下 l。
	-- 註：main 分支的 fzf.lua 這裡多帶一個 raw = true，但 26.5.6 的型別定義
	-- (types.yazi) 裡沒有這個參數，所以拿掉 — 傳的本來就是 Url 物件而非字串，
	-- 不需要額外指定「不要展開」。
	local url = Url(target)
	local cha = fs.cha(url)
	ya.emit(cha and cha.is_dir and "cd" or "reveal", { url })
end

return M
