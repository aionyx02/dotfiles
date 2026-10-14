<#
.SYNOPSIS
    檢查這份設定「實際跑起來」是否正常。

.DESCRIPTION
    install.ps1 -Verify 檢查的是部署狀態（連結、PATH、工具是否存在）；
    本腳本檢查的是設定本身的行為。這些問題都不會主動報錯，壞了也不易察覺：

      · yazi.toml／keymap.toml 有任何一個值不合法時，yazi 會把整組設定退回預設值，
        症狀是所有自訂鍵位失效，而不是出現錯誤訊息
      · wezterm.lua 有語法錯誤時，WezTerm 同樣改用預設設定
      · nvim 外掛的錯誤由 plugins.lua 以 pcall 攔下，只在啟動時閃過一行通知
      · yazi.nvim 的圖片預覽依賴包裝 require('yazi').yazi（lua/plugins/yazi.lua），
        外掛更新後可能悄悄失效
      · 含中文的 .ps1 少了 BOM 時，只有 5.1 會出錯

    建議在以下時機執行：vim.pack.update() 之後、升級 yazi／WezTerm 之後、
    修改任何設定檔之後、commit 之前。

    全程在背景執行：不開啟任何視窗，也不會佔用目前的終端機畫面。
    需要約 20～40 秒，主要花在 nvim 與 yazi 的實際啟動。

    ── 相容性 ────────────────────────────────────────────────────────────
    與 install.ps1 相同：須相容 Windows PowerShell 5.1，並存為 UTF-8 with BOM。

.PARAMETER Quick
    跳過最慢的一項（nvim 開啟目錄並等待 yazi 預覽圖片，約 5～15 秒）。

.EXAMPLE
    .\check.ps1
    執行全部檢查。任一項失敗時結束碼為失敗項目數，全部通過為 0。
#>
[CmdletBinding()]
param(
    [switch]$Quick
)

$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
$ConfigDir = Join-Path $RepoRoot 'home\.config'
$WorkDir = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-check-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $WorkDir

$script:Failed = 0
$script:Warned = 0

# =====================================================================
#  輔助函式
# =====================================================================

# 與 install.ps1 相同的輸出格式
function Write-Head($Text) {
    Write-Host ''
    Write-Host "── $Text " -NoNewline -ForegroundColor Cyan
    Write-Host ('─' * [Math]::Max(0, 68 - $Text.Length)) -ForegroundColor DarkCyan
}

function Write-Item($Status, $Text, $Detail) {
    $map = @{
        OK   = @{ Mark = ' ok '; Color = 'Green'      }
        Skip = @{ Mark = ' -- '; Color = 'DarkGray'   }
        Bad  = @{ Mark = ' XX '; Color = 'Red'        }
        Warn = @{ Mark = ' !! '; Color = 'DarkYellow' }
    }
    if ($Status -eq 'Bad')  { $script:Failed++ }
    if ($Status -eq 'Warn') { $script:Warned++ }
    $m = $map[$Status]
    Write-Host $m.Mark -NoNewline -ForegroundColor $m.Color
    Write-Host $Text.PadRight(46) -NoNewline
    if ($Detail) { Write-Host $Detail -ForegroundColor DarkGray } else { Write-Host '' }
}

# Windows 命令列的引號規則：含空白或引號的參數加上雙引號，內部引號以反斜線跳脫。
#   5.1 的 ProcessStartInfo 沒有 ArgumentList，只能自行組出 Arguments 字串。
function ConvertTo-ArgString([string[]]$ArgList) {
    $parts = foreach ($a in $ArgList) {
        if ($a -and $a -notmatch '[\s"]') { $a; continue }
        '"' + ($a -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }
    return ($parts -join ' ')
}

# 在背景執行外部程式並收集輸出，逾時則連同子行程一併結束。
#   CreateNoWindow：不開新視窗，也不寫入目前的終端機。
#   stdout／stderr 以非同步方式讀取，避免緩衝區寫滿時雙方互等而卡住。
#   $Env 中值為 $null 的項目表示從子行程的環境中移除。
function Invoke-Background([string]$File, [string[]]$ArgList, [int]$TimeoutSec, [hashtable]$Env, [string]$Cwd) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = ConvertTo-ArgString $ArgList
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    if ($Cwd) { $psi.WorkingDirectory = $Cwd }

    # Git Bash 會設定 SHELL，nvim 因此改用 bash 執行 :! 與 job，造成假性失敗
    $psi.EnvironmentVariables.Remove('SHELL')
    if ($Env) {
        foreach ($k in $Env.Keys) {
            $psi.EnvironmentVariables.Remove($k)
            if ($null -ne $Env[$k]) { $psi.EnvironmentVariables[$k] = $Env[$k] }
        }
    }

    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()

    $timedOut = -not $p.WaitForExit($TimeoutSec * 1000)
    if ($timedOut) {
        & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null
        $p.WaitForExit()
    }

    return [pscustomobject]@{
        TimedOut = $timedOut
        ExitCode = $(if ($timedOut) { $null } else { $p.ExitCode })
        Output   = $outTask.Result + $errTask.Result
    }
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

# nvim 的檢查腳本寫到暫存目錄後執行，結果以 JSON 寫回 CHECK_OUT 指定的檔案。
function Invoke-NvimProbe([string]$Name, [string]$Lua, [string[]]$ExtraArgs, [hashtable]$Env, [int]$TimeoutSec) {
    $luaFile = Join-Path $WorkDir "$Name.lua"
    $outFile = Join-Path $WorkDir "$Name.json"
    [IO.File]::WriteAllText($luaFile, $Lua, (New-Object Text.UTF8Encoding $false))

    $allEnv = @{ CHECK_OUT = $outFile }
    if ($Env) { foreach ($k in $Env.Keys) { $allEnv[$k] = $Env[$k] } }

    $argList = @('--headless', '--cmd', 'set columns=200 lines=50', '-c', "luafile $luaFile") + $ExtraArgs
    $r = Invoke-Background 'nvim' $argList $TimeoutSec $allEnv $WorkDir
    if (-not (Test-Path -LiteralPath $outFile)) {
        if ($r.TimedOut) { return "逾時（$TimeoutSec 秒）" }
        return "沒有產生結果（結束碼 $($r.ExitCode)）"
    }
    return ([IO.File]::ReadAllText($outFile) | ConvertFrom-Json)
}

# =====================================================================
#  1. yazi：設定是否被退回預設值
# =====================================================================
#  設定正常時 `yazi --debug` 印出版本與設定資訊後立即結束；
#  任一設定值不合法時，它會停在「Press <Enter> to continue with preset settings」
#  等待輸入，不印出任何內容（2026-10-14 以 image_delay = 200 實測）。
#  因此以「是否在時限內結束並印出 Config 區塊」判斷。

Write-Head 'yazi'

if (-not (Test-Command 'yazi')) {
    Write-Item Bad 'yazi' '找不到 yazi，請先執行 install.ps1'
} else {
    $yaziHome = Join-Path $ConfigDir 'yazi'
    $r = Invoke-Background 'yazi' @('--debug') 15 @{ YAZI_CONFIG_HOME = $yaziHome } $null
    if ($r.TimedOut) {
        Write-Item Bad '設定載入' '卡在「continue with preset settings」：有設定值不合法，整組設定會退回預設'
    } elseif ($r.Output -notmatch '(?m)^Config') {
        Write-Item Bad '設定載入' "輸出異常（結束碼 $($r.ExitCode)）"
    } else {
        $ver = ''
        if ($r.Output -match 'Version\s*:\s*(\S+)') { $ver = $Matches[1] }
        Write-Item OK '設定載入' "yazi $ver"
        foreach ($f in 'init.lua', 'yazi.toml', 'keymap.toml', 'theme.toml') {
            $line = ($r.Output -split "`n") | Where-Object { $_ -match [regex]::Escape($f) } | Select-Object -First 1
            if ($line -match 'os error') { Write-Item Bad "  $f" $line.Trim() }
            else                         { Write-Item OK  "  $f" '' }
        }
    }
}

# =====================================================================
#  2. WezTerm：wezterm.lua 是否有錯
# =====================================================================
#  不能用 show-keys：設定有錯時它會改用預設鍵位，照樣正常結束。
#  ls-fonts 會把 Lua 錯誤以「ERROR」印到 stderr。

Write-Head 'WezTerm'

if (-not (Test-Command 'wezterm')) {
    Write-Item Skip 'wezterm.lua' '找不到 wezterm 指令'
} else {
    $wezConfig = Join-Path $ConfigDir 'wezterm\wezterm.lua'
    $r = Invoke-Background 'wezterm' @('--config-file', $wezConfig, 'ls-fonts') 30 $null $null
    $errLine = ($r.Output -split "`n") | Where-Object { $_ -match '\bERROR\b' } | Select-Object -First 1
    if ($r.TimedOut)  { Write-Item Bad 'wezterm.lua' '逾時' }
    elseif ($errLine) { Write-Item Bad 'wezterm.lua' ($errLine.Trim() -replace '^.*?ERROR\s+', '') }
    else              { Write-Item OK  'wezterm.lua' '' }
}

# =====================================================================
#  3. nvim：啟動錯誤、LSP 執行檔、treesitter parser、外掛數
# =====================================================================

Write-Head 'nvim'

$startupLua = @'
-- 等外掛的 config 跑完再收集結果
vim.defer_fn(function()
  local r = { errors = '', lsp = {}, parsers = {}, plugins = 0 }

  -- errors 以換行串接成字串：vim.json.encode 會把空的 table 編成 {} 而非 []，
  --   PowerShell 解析後會變成一個物件，被誤判為「有一筆錯誤」
  local errors = {}
  local msgs = vim.api.nvim_exec2('messages', { output = true }).output
  for line in msgs:gmatch('[^\n]+') do
    if line:match('^E%d+:') or line:match('^%[plugins%]') or line:match('[Ee]rror') then
      table.insert(errors, line)
    end
  end
  r.errors = table.concat(errors, '\n')

  local lsp_dir = vim.fn.stdpath('config') .. '/lsp'
  for _, file in ipairs(vim.fn.readdir(lsp_dir)) do
    local name = file:gsub('%.lua$', '')
    local cfg = vim.lsp.config[name]
    local exe = cfg and type(cfg.cmd) == 'table' and cfg.cmd[1] or nil
    table.insert(r.lsp, { name = name, exe = exe or '', ok = exe ~= nil and vim.fn.executable(exe) == 1 })
  end

  for _, lang in ipairs({ 'c', 'cpp', 'python', 'lua' }) do
    local ok, res = pcall(vim.treesitter.language.add, lang)
    table.insert(r.parsers, { lang = lang, ok = ok and res == true })
  end

  local ok, list = pcall(vim.pack.get)
  if ok then r.plugins = #list end

  vim.fn.writefile({ vim.json.encode(r) }, vim.env.CHECK_OUT)
  vim.cmd('qa!')
end, 1500)
'@

if (-not (Test-Command 'nvim')) {
    Write-Item Bad 'nvim' '找不到 nvim'
} else {
    $r = Invoke-NvimProbe 'startup' $startupLua @() $null 60
    if ($r -is [string]) {
        Write-Item Bad '啟動' $r
    } else {
        if (-not $r.errors) { Write-Item OK '啟動' '沒有錯誤訊息' }
        else { foreach ($e in ($r.errors -split "`n")) { Write-Item Bad '啟動' $e } }

        # 套件上限 6 是使用者訂的規則，超過時提醒，不算失敗
        if ($r.plugins -gt 6) { Write-Item Warn "外掛數 $($r.plugins)" '超過約定的上限 6' }
        else                  { Write-Item OK   "外掛數 $($r.plugins)" '上限 6' }

        foreach ($l in $r.lsp) {
            if ($l.ok) { Write-Item OK  "LSP $($l.name)" $l.exe }
            else       { Write-Item Bad "LSP $($l.name)" "找不到 $($l.exe)" }
        }
        foreach ($p in $r.parsers) {
            if ($p.ok) { Write-Item OK  "treesitter $($p.lang)" '' }
            else       { Write-Item Bad "treesitter $($p.lang)" 'parser 未安裝，該語言會退回 regex 上色' }
        }
    }

    # checkhealth：一次只能帶一個名稱。帶多個時，yazi 那一段會從輸出中消失
    #   （2026-10-14 在 nvim 0.12.4 觀察到），因此逐一執行。
    foreach ($name in 'yazi', 'nvim-treesitter', 'vim.lsp', 'vim.pack') {
        $healthFile = Join-Path $WorkDir "health-$name.txt"
        $null = Invoke-Background 'nvim' @('--headless', '-c', "checkhealth $name", '-c', "w! $healthFile", '-c', 'qa!') 60 $null $WorkDir
        if (-not (Test-Path -LiteralPath $healthFile)) { Write-Item Bad "checkhealth $name" '沒有產生結果'; continue }
        $text = [IO.File]::ReadAllText($healthFile)
        $errs = @(($text -split "`n") | Where-Object { $_ -match '❌|ERROR' })
        $warns = @(($text -split "`n") | Where-Object { $_ -match '⚠️|WARNING' })
        if ($errs.Count)      { Write-Item Bad  "checkhealth $name" ($errs[0].Trim() -replace '^-\s*', '') }
        elseif ($warns.Count) { Write-Item Warn "checkhealth $name" ($warns[0].Trim() -replace '^-\s*', '') }
        else                  { Write-Item OK   "checkhealth $name" '' }
    }
}

# =====================================================================
#  4. nvim + yazi：開啟目錄改開 yazi、圖片預覽
# =====================================================================
#  實際以 nvim 開啟一個含 PNG 的暫存目錄，確認三件事：
#    · open_for_directories：yazi 以浮動視窗開啟（filetype = yazi）
#    · 圖片預覽：yazi 改用 chafa，畫面上出現區塊字元（U+2580～U+259F）
#    · 包裝函式結束後，nvim 的 TERM_PROGRAM 已還原
#  刻意模擬 WezTerm 的環境變數：不論本腳本在哪個終端機執行，
#    都能驗證 lua/plugins/yazi.lua 的包裝是否仍然生效。
#    包裝失效時，yazi 會判定自己在 WezTerm 中，預覽欄將一片空白。

$e2eLua = @'
local deadline = vim.uv.now() + 20000
local function finish(r)
  r.term_program = vim.env.TERM_PROGRAM or ''
  r.explore = vim.fn.exists(':Explore')
  vim.fn.writefile({ vim.json.encode(r) }, vim.env.CHECK_OUT)
  vim.cmd('qa!')
end
local function poll()
  local r = { float = false, chafa = false }
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype == 'yazi' then
      r.float = vim.api.nvim_win_get_config(w).relative ~= ''
      for _, line in ipairs(vim.api.nvim_buf_get_lines(b, 0, -1, false)) do
        if line:find('\226\150[\128-\159]') then r.chafa = true end
      end
    end
  end
  if (r.float and r.chafa) or vim.uv.now() > deadline then return finish(r) end
  vim.defer_fn(poll, 500)
end
vim.defer_fn(poll, 1000)
'@

Write-Head 'nvim + yazi'

if ($Quick) {
    Write-Item Skip '開啟目錄與圖片預覽' '-Quick'
} elseif (-not (Test-Command 'nvim') -or -not (Test-Command 'yazi')) {
    Write-Item Skip '開啟目錄與圖片預覽' '缺少 nvim 或 yazi'
} else {
    if (-not (Test-Command 'chafa')) {
        Write-Item Bad 'chafa' '未安裝：yazi 在 nvim 中無法預覽圖片（winget install hpjansson.Chafa）'
    }

    # 漸層圖：純色圖在 chafa 中可能只輸出帶底色的空白，偵測不到區塊字元
    $imgDir = Join-Path $WorkDir 'images'
    $null = New-Item -ItemType Directory -Path $imgDir
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap 200, 200
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $rect = New-Object System.Drawing.Rectangle 0, 0, 200, 200
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.Color]::Red), ([System.Drawing.Color]::Blue), 90.0
    $g.FillRectangle($brush, $rect)
    $bmp.Save((Join-Path $imgDir 'a.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    $brush.Dispose(); $g.Dispose(); $bmp.Dispose()

    $fakeWez = @{ TERM_PROGRAM = 'WezTerm'; WEZTERM_EXECUTABLE = 'wezterm-gui.exe'; WEZTERM_PANE = '0' }
    $r = Invoke-NvimProbe 'e2e' $e2eLua @($imgDir) $fakeWez 45
    if ($r -is [string]) {
        Write-Item Bad '開啟目錄' $r
    } else {
        if ($r.float) { Write-Item OK  '開啟目錄改開 yazi' '' }
        else          { Write-Item Bad '開啟目錄改開 yazi' '沒有出現 yazi 浮動視窗（open_for_directories）' }

        if ($r.explore -eq 0) { Write-Item OK  'netrw 已停用' '' }
        else                  { Write-Item Bad 'netrw 已停用' ':Explore 仍存在（loaded_netrwPlugin）' }

        if ($r.chafa)          { Write-Item OK  '圖片預覽（chafa）' '' }
        elseif ($r.float)      { Write-Item Bad '圖片預覽（chafa）' '預覽欄沒有圖：檢查 lua/plugins/yazi.lua 的 require(''yazi'').yazi 包裝' }
        else                   { Write-Item Skip '圖片預覽（chafa）' 'yazi 沒有開啟，無法檢查' }

        if ($r.term_program -eq 'WezTerm') { Write-Item OK  '環境變數已還原' '' }
        else                               { Write-Item Bad '環境變數已還原' "TERM_PROGRAM = '$($r.term_program)'" }
    }
}

# =====================================================================
#  5. PowerShell：BOM 與 5.1／7 的語法
# =====================================================================
#  含非 ASCII 字元的 .ps1 必須有 BOM，否則 5.1 以 Big5 解讀而產生語法錯誤。
#  語法以兩個版本各自的 parser 檢查，不執行任何腳本。

Write-Head 'PowerShell 腳本'

$ps1Files = @(& git -C $RepoRoot ls-files -- '*.ps1' | ForEach-Object { Join-Path $RepoRoot ($_ -replace '/', '\') })
foreach ($f in $ps1Files) {
    $bytes = [IO.File]::ReadAllBytes($f)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $nonAscii = $false
    foreach ($b in $bytes) { if ($b -ge 0x80) { $nonAscii = $true; break } }
    $rel = $f.Substring($RepoRoot.Length + 1)
    if ($nonAscii -and -not $hasBom) { Write-Item Bad "BOM  $rel" '含中文但沒有 BOM，5.1 會解讀錯誤' }
}

$listFile = Join-Path $WorkDir 'ps1-list.txt'
[IO.File]::WriteAllLines($listFile, [string[]]$ps1Files, (New-Object Text.UTF8Encoding $true))
$parseScript = Join-Path $WorkDir 'parse.ps1'
[IO.File]::WriteAllText($parseScript, @'
# 沒有主控台的子行程預設以系統字碼頁（Big5）輸出，錯誤訊息會變成亂碼
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$errs = $null
foreach ($f in (Get-Content -LiteralPath $args[0] -Encoding UTF8)) {
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs)
    if ($errs) { "$f`t$($errs[0].Extent.StartLineNumber): $($errs[0].Message)" }
}
'@, (New-Object Text.UTF8Encoding $true))

foreach ($engine in @(@{ Exe = 'powershell'; Label = '5.1' }, @{ Exe = 'pwsh'; Label = '7' })) {
    if (-not (Test-Command $engine.Exe)) { Write-Item Skip "語法 PowerShell $($engine.Label)" "找不到 $($engine.Exe)"; continue }
    $r = Invoke-Background $engine.Exe @('-NoProfile', '-NonInteractive', '-File', $parseScript, $listFile) 60 $null $null
    $bad = @(($r.Output -split "`r?`n") | Where-Object { $_ -match "`t" })
    if ($r.TimedOut)   { Write-Item Bad "語法 PowerShell $($engine.Label)" '逾時' }
    elseif ($bad.Count) {
        foreach ($line in $bad) {
            $parts = $line -split "`t", 2
            Write-Item Bad "語法 $($engine.Label)  $($parts[0].Substring($RepoRoot.Length + 1))" $parts[1]
        }
    }
    else { Write-Item OK "語法 PowerShell $($engine.Label)" "$($ps1Files.Count) 個檔案" }
}

# =====================================================================
#  結果
# =====================================================================

Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
if ($script:Failed -eq 0) {
    Write-Host (" 全部通過（警告 {0}）" -f $script:Warned) -ForegroundColor Green
} else {
    Write-Host (" 失敗 {0}、警告 {1}" -f $script:Failed, $script:Warned) -ForegroundColor Red
}
Write-Host ' 部署狀態（連結、PATH、工具）請另以 .\install.ps1 -Verify 檢查。' -ForegroundColor DarkGray
exit $script:Failed
