--- @since 26.5.6
-- =====================================================================
--  everything：全機檔名搜尋（voidtools Everything），綁定 <F4> 與 `e
--
--  須以外掛實作，無法使用內建的 search --via=：
--    該指令只支援 fd、rg、rga 三種引擎，沒有加入自訂引擎的介面
--    （見官方 keymap 文件的 search 條目），因此採用
--    「外掛 → es.exe → fzf → cd / reveal」的流程。
--
--  fzf 在此不負責搜尋：
--    --disabled 會關閉 fzf 本身的模糊比對，比對規則完全由 Everything 決定，
--    fzf 僅作為顯示與選取介面。
--    這是必要的，因為 es.exe 只將路徑輸出到 stdout，沒有互動介面。
--    此外 fzf 是獨立行程，有自己的鍵盤處理，方向鍵可正常使用，
--    因此不受 yazi 過濾輸入框中方向鍵無效的限制（見 keymap.toml 中 f 的說明）。
--
--  Everything 的兩項限制，使 s / S 無法被本外掛取代：
--      1. 它讀取 NTFS 的 MFT，無法看到 \\wsl.localhost 下的 ext4
--      2. 它只搜尋檔名，不比對內容
--    因此 s（fd，涵蓋 WSL）與 S（rg，內容搜尋）都必須保留。
-- =====================================================================

-- 預設排除的路徑。依 Everything 的規則，查詢字串含有路徑分隔符時，
-- 會比對完整路徑而非僅檔名，因此以下規則比對的是整條路徑。
-- 注意：這些規則皆不含空白。此字串最終由 fzf 交給 cmd.exe 解析，
--   不含空白即不需加引號，可避免跳脫問題。
--   （尤其不可在以反斜線結尾的路徑外加雙引號，\" 會被解讀為跳脫的引號。）
local EXCLUDES = {
	[[!C:\Windows\]],
	[[!\node_modules\]],
	[[!\.git\]],
	[[!\AppData\Local\Temp\]],
	[[!$RECYCLE.BIN]],
}

-- 單次查詢的筆數上限，須與排序方式一併考量：
-- --disabled 使 fzf 依 es 回傳的順序顯示，當查詢命中數千筆時，
-- 排序方式決定了顯示哪 200 筆，其餘結果不會出現。
-- 採用修改時間遞減排序，因為廣泛查詢時最近修改的檔案最可能是目標；
-- 若依路徑排序，第一頁幾乎都是 C:\ 開頭的系統路徑。
local LIMIT = "200"
local SORT = "date-modified-descending"

local M = {}

local state = ya.sync(function() return cx.active.current.cwd end)

---將 fzf 的多行輸出切割為陣列（保留空行：第 2 行為空表示按下的是 Enter）。
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

---組合傳給 fzf 的 reload 指令字串。
---{q} 是 fzf 的佔位符，每次輸入時會代入目前的查詢字串並重新執行。
---@param scoped boolean 限定目前目錄以下（否則搜尋全機）
---@param cwd Url
---@param filtered boolean 套用 EXCLUDES
local function es_command(scoped, cwd, filtered)
	local t = { "es.exe", "-n", LIMIT, "-sort", SORT }
	if scoped then
		-- cwd 可能含有空白，必須加上引號。
		-- 位於磁碟根目錄時會產生 -path "C:\"。已實測 es.exe 能正確解析此寫法
		-- （結果與 "C:\\" 相同），不需另外處理結尾的反斜線。
		-- 這與上方 EXCLUDES 的限制不衝突：-path 的參數與搜尋字串的解析方式不同，
		-- 搜尋字串中的 "!C:\Windows\" 經實測會導致查詢無結果。
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

---執行一次 fzf 並回傳 stdout。
---切換鍵不使用 fzf 的 transform action，而是改用 --expect 與 --print-query：
---  fzf 在第 1 行輸出目前的查詢字串，第 2 行輸出結束時按下的 expect 鍵，
---  Lua 端據此切換狀態，並以原查詢字串重新開啟 fzf。
---  使用體驗與 transform 相同（輸入到一半切換也不會遺失文字），
---  且不需在 bind 字串中嵌入 shell 指令，避免 Windows 上複雜的引號處理。
local function run_fzf(cwd, scoped, filtered, query)
	local cmd = es_command(scoped, cwd, filtered)

	-- 每個 --bind 各為一個 argv 元素，而 Command:arg() 直接傳遞 argv，
	--   不經過 shell，因此不需跳脫。只有 fzf 執行 reload 指令時才會經過 shell
	--   （Windows 上為 cmd.exe /s /c）。
	--   因此使用 "reload:" 的冒號形式而非 "reload(...)"：冒號形式表示
	--   其後到字串結尾皆為指令，指令中的括號不會被誤判為語法。
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
	-- 結束代碼：0 為已選取，1 為沒有符合項目，130 為使用者按 Esc 或 Ctrl+C 中斷。
	-- 後兩者皆為正常結束，--print-query 仍會輸出查詢字串。
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
	-- 使用 is_regular 而非 spec.is_virtual。
	--   yazi 的 Url 有四種 scheme（Regular、Search、Archive、SFTP），is_regular
	--   表示 scheme 為 Regular。spec 是 main 分支的過渡期 API，26.5.6 沒有
	--   （本機 mime-ext.yazi 中使用它的程式碼仍標註 "TODO: remove"），
	--   直接照抄 main 分支的 fzf.lua 會產生 attempt to index a nil value。
	--
	--   此檢查不可省略：Command("fzf"):cwd() 收到 search:// 或 archive://
	--   等路徑時會啟動失敗，且錯誤訊息看不出原因。
	if not cwd.is_regular then
		return notify("目前在搜尋結果或壓縮檔內部，不是一般檔案系統 — 先 Esc 退出再用 F4", "warn")
	end

	-- 先試查詢一次，將兩種無訊息的失敗轉為明確的錯誤訊息。
	--   Everything 未執行時，es.exe 會回傳 errorlevel 8 且沒有任何輸出，
	--   交給 fzf 後只會顯示空清單，使用者會誤以為是搜尋不到結果。
	--   -n 1 且不帶查詢字串時會取得索引中的第一筆，只需數毫秒，成本可忽略。
	local probe, perr = Command("es.exe"):arg({ "-n", "1" }):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not probe then
		return notify(
			"找不到 es.exe（" .. tostring(perr) .. "）\n"
				.. "1. 未安裝 → winget install -e --id voidtools.Everything.Cli\n"
				.. "2. 已安裝但仍找不到 → 完整重開 WezTerm。winget 是改「使用者 PATH」，\n"
				.. "   而 WezTerm 只在啟動時繼承環境變數，Ctrl+Shift+R 重載設定不會更新 PATH。"
		)
	elseif probe.status.code == 8 then
		-- 此訊息刻意寫「客戶端」而非「服務」，兩者不同，
		--   且預設安裝後常只有服務在執行：
		--     服務   Everything.exe -svc（LocalSystem），負責讀取 MFT
		--     客戶端 Everything.exe（系統匣圖示），負責建立 es 所需的 IPC 視窗
		--   只有服務執行時，Everything 看似正常（工作管理員中有行程、
		--   服務狀態為 Running），但 es 一律回傳 errorlevel 8。
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

	-- 與內建 fzf 外掛相同：目錄則進入，檔案則移動到該檔案所在位置並選取。
	-- 使用 reveal 而非 open：全機搜尋找到檔案後通常還有後續操作
	-- （複製、重新命名、預覽），停在檔案位置比直接開啟更實用，需要開啟時再按 l。
	-- main 分支的 fzf.lua 在此多傳了 raw = true，但 26.5.6 的型別定義
	-- （types.yazi）沒有此參數，因此省略；傳入的本來就是 Url 物件而非字串，
	-- 不需另外指定不展開路徑。
	local url = Url(target)
	local cha = fs.cha(url)
	ya.emit(cha and cha.is_dir and "cd" or "reveal", { url })
end

return M
