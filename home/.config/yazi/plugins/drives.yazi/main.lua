--- @since 26.5.6
-- =====================================================================
--  drives  ·  磁碟機 / WSL 切換選單
--
--  為什麼要自己寫：官方 yazi-rs/plugins:mount 的 README 明講不支援
--  Windows(TODO 裡寫著 "Windows support, PRs welcome")，它靠的是 Linux 的
--  udisksctl/lsblk 與 macOS 的 diskutil，這台機器上一個都沒有。
--
--  ★ 刻意不開子行程：
--    列磁碟機最直覺的做法是叫 PowerShell 的 Get-PSDrive 或 wmic，
--    但兩者都要付一次行程啟動成本(PowerShell 冷啟動 300~800ms)，
--    而且 wmic 在 Win11 已被標為淘汰。這裡改用 fs.cha 直接探測 A:~Z:，
--    純 Lua、零行程，代價只是拿不到磁碟區標籤(顯示 "D:" 而非 "D: 資料")。
-- =====================================================================

-- 逐一探測 A: ~ Z:，只留下真的存在的。
-- 不存在的代號 Windows 會立刻回 ERROR_PATH_NOT_FOUND，不會卡住；
-- 唯一可能變慢的是「已對應但斷線的網路磁碟機」，那本來就會逾時。
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

-- Docker Desktop 的內部發行版，不是給人進去逛的，濾掉。
local SKIP_DISTROS = {
	["docker-desktop"]      = true,
	["docker-desktop-data"] = true,
}

-- 列出 WSL 發行版。
--
-- ★ 這裡原本是 fs.read_dir(Url("\\\\wsl.localhost"))，但那條路根本走不通：
--   WSL 的 P9 provider 不支援列舉「分享根目錄」，即使發行版正在執行也一律
--   回傳空清單 — 也就是說這個選單從來沒有真的出現過 WSL 項目。
--   (進入具體路徑 \\wsl.localhost\Ubuntu 完全正常，不能做的只有列舉根目錄。)
--
-- ★ 改問 wsl.exe，它只讀註冊表，不會啟動 VM，實測單次 spawn 29ms。
--   這確實破了本檔「刻意不開子行程」的原則，但另一個選項更貴 —— 用 fs.cha
--   去探測 \\wsl.localhost\<name> 雖然不開行程，卻會把整個 WSL VM 叫醒
--   (冷啟實測 267ms)，而且發行版名稱還得預先寫死在這裡。
local function wsl_distros()
	local out = {}

	local child = Command("wsl.exe")
		:arg({ "--list", "--quiet" })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()
	-- 沒裝 WSL 時 Command 直接回 nil；不要讓整個磁碟機選單跟著失敗。
	if not child or child.status.code ~= 0 then
		return out
	end

	-- wsl.exe 的輸出是 UTF-16LE 而且不帶 BOM(實測 48 bytes / 24 個 NUL)。
	-- 發行版名稱實務上都是 ASCII，濾掉 NUL 就夠 —— 這樣寫的好處是即使日後
	-- 環境設了 WSL_UTF8=1 讓它改印 UTF-8，這段一樣能正確解析。
	--
	-- ★ 刻意不用 gsub 做這件事：NUL 在 Lua pattern 裡的處理跟版本綁死 ——
	--   5.1 得寫 %z(pattern 不能含內嵌 NUL)，而 %z 在 5.3 之後被移除、
	--   改成直接寫 \0。逐位元組組回來就沒有這個相容性問題。
	local bytes = {}
	for i = 1, #child.stdout do
		local b = child.stdout:byte(i)
		if b ~= 0 then
			bytes[#bytes + 1] = string.char(b)
		end
	end
	local text = table.concat(bytes)

	-- ★ 這裡「不能」寫成 for name in ... do name = name:match(...) end ——
	--   yazi 跑的是 Luau 不是標準 Lua，泛型 for 的迴圈變數是 const，
	--   重新賦值會在編譯期就丟 "attempt to assign to const variable"，
	--   整個檔案連載入都失敗(症狀是 M 與 h 完全沒反應，不是「選單少一項」)。
	--   修剪後的結果一律另存一個 local。
	for line in text:gmatch("[^\r\n]+") do
		local name = line:match("^%s*(.-)%s*$")
		if name ~= "" and not SKIP_DISTROS[name] then
			out[#out + 1] = {
				on   = tostring(#out + 1), -- 數字鍵，與磁碟機字母不會撞
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

	-- 只把 on / desc 交給 ya.which — path 是我們自己的欄位，
	-- 混在候選項裡送過去會被當成未知欄位。
	local which = {}
	for i, c in ipairs(cands) do
		which[i] = { on = c.on, desc = c.desc }
	end

	-- ya.which 回傳 1-based 索引；按 Esc 取消時回 nil。
	local idx = ya.which { cands = which }
	if idx then
		ya.emit("cd", { Url(cands[idx].path) })
	end
end

return { entry = entry }
