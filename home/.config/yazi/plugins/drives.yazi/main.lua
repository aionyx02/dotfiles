--- @since 26.5.6
-- =====================================================================
--  drives：磁碟機與 WSL 切換選單
--
--  自行撰寫的原因：官方 yazi-rs/plugins:mount 的 README 註明不支援 Windows
--  （TODO 中寫著 "Windows support, PRs welcome"），它依賴 Linux 的
--  udisksctl、lsblk 與 macOS 的 diskutil，本機皆沒有。
--
--  不啟動子行程列舉磁碟機：
--    常見做法是呼叫 PowerShell 的 Get-PSDrive 或 wmic，
--    但兩者都需要啟動行程（PowerShell 冷啟動需 300～800ms），
--    且 wmic 在 Windows 11 已被列為淘汰。此處改以 fs.cha 直接探測 A:～Z:，
--    純 Lua 實作、不啟動行程，代價是無法取得磁碟區標籤（顯示 "D:" 而非 "D: 資料"）。
-- =====================================================================

-- 逐一探測 A:～Z:，只保留實際存在的磁碟機。
-- 不存在的代號會立即回傳 ERROR_PATH_NOT_FOUND，不會阻塞；
-- 只有已對應但離線的網路磁碟機可能較慢，這種情況本來就會逾時。
local function local_drives()
	local out = {}
	for i = string.byte("A"), string.byte("Z") do
		local letter = string.char(i)
		local cha = fs.cha(Url(letter .. ":/"))
		if cha and cha.is_dir then
			out[#out + 1] = {
				on   = letter:lower(),
				desc = letter .. ":",
				path = letter .. ":/",
			}
		end
	end
	return out
end

-- Docker Desktop 的內部發行版，不供一般瀏覽，予以排除。
local SKIP_DISTROS = {
	["docker-desktop"]      = true,
	["docker-desktop-data"] = true,
}

-- 列出 WSL 發行版。
--
-- 不使用 fs.read_dir(Url("\\\\wsl.localhost"))：
--   WSL 的 P9 provider 不支援列舉分享的根目錄，即使發行版正在執行也一律回傳空清單。
--   （進入 \\wsl.localhost\Ubuntu 等具體路徑正常，只有根目錄無法列舉。）
--
-- 改為查詢 wsl.exe：它只讀取登錄檔，不會啟動 VM，實測單次約 29ms。
--   這是本檔「不啟動子行程」原則的例外，但替代方案成本更高：以 fs.cha
--   探測 \\wsl.localhost\<name> 雖不需啟動行程，卻會喚醒整個 WSL VM
--   （冷啟動實測 267ms），且須預先寫死發行版名稱。
local function wsl_distros()
	local out = {}

	local child = Command("wsl.exe")
		:arg({ "--list", "--quiet" })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
	-- 未安裝 WSL 時 Command 回傳 nil；此時只略過 WSL 項目，不影響磁碟機選單。
	if not child or child.status.code ~= 0 then
		return out
	end

	-- wsl.exe 的輸出為不帶 BOM 的 UTF-16LE。
	-- 發行版名稱實際上皆為 ASCII，移除 NUL 即可；
	-- 即使日後設定 WSL_UTF8=1 使其改為輸出 UTF-8，此段仍能正確解析。
	--
	-- 不使用 gsub 移除 NUL：Lua pattern 對 NUL 的寫法因版本而異，
	--   5.1 須寫 %z（pattern 不能包含 NUL），5.2 起改為直接寫 \0，%z 已淘汰。
	--   逐位元組處理可避免此相容性問題。
	local bytes = {}
	for i = 1, #child.stdout do
		local b = child.stdout:byte(i)
		if b ~= 0 then
			bytes[#bytes + 1] = string.char(b)
		end
	end
	local text = table.concat(bytes)

	-- 注意：不可寫成 for name in ... do name = name:match(...) end。
	--   yazi 使用 Luau 而非標準 Lua，泛型 for 的迴圈變數為 const，
	--   重新賦值會在編譯時產生 "attempt to assign to const variable"，
	--   導致整個檔案無法載入（症狀是 M 與 h 完全沒有反應）。
	--   修剪後的結果須另存為新的 local 變數。
	for line in text:gmatch("[^\r\n]+") do
		local name = line:match("^%s*(.-)%s*$")
		if name ~= "" and not SKIP_DISTROS[name] then
			out[#out + 1] = {
				on   = tostring(#out + 1), -- 使用數字鍵，避免與磁碟機代號衝突
				desc = "WSL: " .. name,
				path = "\\\\wsl.localhost\\" .. name,
			}
		end
	end
	return out
end

local function entry()
	local cands = local_drives()
	for _, v in ipairs(wsl_distros()) do
		cands[#cands + 1] = v
	end

	if #cands == 0 then
		ya.notify {
			title   = "Drives",
			content = "找不到任何磁碟機",
			level   = "warn",
			timeout = 3,
		}
		return
	end

	-- 只將 on 與 desc 傳給 ya.which；path 是自訂欄位，
	-- 一併傳入會被視為未知欄位。
	local which = {}
	for i, c in ipairs(cands) do
		which[i] = { on = c.on, desc = c.desc }
	end

	-- ya.which 回傳從 1 開始的索引；按 Esc 取消時回傳 nil。
	local idx = ya.which { cands = which }
	if idx then
		ya.emit("cd", { Url(cands[idx].path) })
	end
end

return { entry = entry }
