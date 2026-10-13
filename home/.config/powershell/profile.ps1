# 共用 profile：Windows PowerShell 5.1 與 PowerShell 7 皆 dot-source 此檔。
# 注意：本檔須存為 UTF-8 with BOM，否則 5.1 會以 ANSI（Big5）解讀中文而產生語法錯誤。
#
# 設計原則：啟動 shell 時不啟動任何外部行程，也不做萬用字元掃描。
# 需要執行外部程式才能取得的內容（starship、zoxide 的初始化腳本與工具路徑）
# 皆預先產生並快取於 ~/.cache/pwsh-init/，啟動時僅讀檔並 dot-source。
# 快取重建條件：
#   tools.ps1      ：檔案不存在，或記錄的任一路徑已不存在（例如工具在快取建立後才安裝）
#   初始化腳本快取 ：對應的 exe 比快取檔新，或快取檔不存在
# 手動重建：Remove-Item ~/.cache/pwsh-init -Recurse

$InitCache = Join-Path $HOME '.cache\pwsh-init'
if (-not [IO.Directory]::Exists($InitCache)) { New-Item -ItemType Directory -Force $InitCache | Out-Null }

# 工具路徑只解析一次並快取。
# Get-Command 首次呼叫需掃描整個 PATH 並建立 command cache，在本機約需 180ms。
$ToolsFile = Join-Path $InitCache 'tools.ps1'

$zoxideDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe'

# 快取中任一路徑為空或已不存在時重新解析；否則若在工具安裝前啟動過 shell，
# 空路徑會被永久快取，之後每次啟動都顯示「找不到」。
# 工具確實未安裝時，每次啟動都會重新解析一次（約 180ms），直到安裝為止。
$toolsValid = $false
if ([IO.File]::Exists($ToolsFile)) {
    . $ToolsFile
    $toolsValid = $Tools_Starship -and $Tools_Zoxide -and
        [IO.File]::Exists($Tools_Starship) -and [IO.File]::Exists($Tools_Zoxide)
}
if (-not $toolsValid) {
    # 若 session 在 winget 安裝工具之前啟動，其 PATH 不會包含該工具，需手動補上
    if ((Test-Path (Join-Path $zoxideDir 'zoxide.exe')) -and (($env:Path -split ';') -notcontains $zoxideDir)) {
        $env:Path = "$env:Path;$zoxideDir"
    }
    $Tools = [ordered]@{
        Starship = (Get-Command starship -ErrorAction SilentlyContinue).Source
        Zoxide   = (Get-Command zoxide   -ErrorAction SilentlyContinue).Source
    }
    $lines = foreach ($k in $Tools.Keys) { "`$Tools_$k = '$($Tools[$k])'" }
    ($lines -join "`r`n") | Set-Content $ToolsFile -Encoding UTF8
    . $ToolsFile
}

# =====================================================================
# Starship
# =====================================================================
if ($env:TERMINAL_EMULATOR -eq 'JetBrains-JediTerm') {
    $env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship-tokyo-night-jetbrains.toml'
} else {
    $env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship-tokyo-night-user.toml'
}

# 產生或更新初始化腳本的快取，回傳快取檔路徑（不存在時不回傳）。
#
# `starship init powershell` 的輸出只是 bootstrap，執行時會再啟動一次
# `starship init powershell --print-full-init`；直接快取 full-init 可省下這兩次行程啟動。
# 檔案檢查使用 .NET 靜態方法而非 Get-Item：後者經由 FileSystem provider，
# 每次都要建立 PSObject 並檢查 ACL 與 reparse point，在本機四次檢查約需 144ms，
# 改用 .NET 後降至個位數 ms。
function Update-InitCache($Name, $ExePath, $Generator) {
    $out = Join-Path $InitCache "$Name.ps1"
    if ($ExePath -and ((-not [IO.File]::Exists($out)) -or
        ([IO.File]::GetLastWriteTimeUtc($ExePath) -gt [IO.File]::GetLastWriteTimeUtc($out)))) {
        (& $Generator) | Set-Content $out -Encoding UTF8
    }
    if ([IO.File]::Exists($out)) { $out }
}

$starshipInit = Update-InitCache 'starship' $Tools_Starship {
    & $Tools_Starship init powershell --print-full-init | Out-String
}
if ($starshipInit) { . $starshipInit }

# =====================================================================
# Zoxide
# =====================================================================
$env:_ZO_EXCLUDE_DIRS = "$HOME;$env:LOCALAPPDATA\*;$env:APPDATA\*;$env:TEMP\*;C:\Windows\*;$HOME\OneDrive\*"
$env:_ZO_FZF_OPTS     = "--height=40% --layout=reverse --border --info=inline"

$zoxideInit = Update-InitCache 'zoxide' $Tools_Zoxide { & $Tools_Zoxide init powershell | Out-String }
if ($zoxideInit) {
    . $zoxideInit
    $zoxideCompletions = Join-Path $zoxideDir 'completions\_zoxide.ps1'
    if ([IO.File]::Exists($zoxideCompletions)) { . $zoxideCompletions }
} else {
    Write-Warning 'zoxide 找不到，已跳過初始化（安裝：winget install ajeetdsouza.zoxide）'
}

# =====================================================================
# Yazi
# =====================================================================
# 啟動 yazi，離開（q）後 shell 切換到 yazi 中最後所在的目錄。
# `y <路徑>` 可指定起始目錄。做法依照官方文件的 --cwd-file 範例。
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        # 須明確呼叫 yazi.exe：下方將 yazi 設為 y 的別名，呼叫 yazi 會遞迴呼叫本函式。
        yazi.exe $args --cwd-file="$tmp"
        $cwd = Get-Content -LiteralPath $tmp -Encoding UTF8
        # 必須檢查目錄是否存在：若在 yazi 中刪除目前目錄後才離開，
        # cwd-file 記錄的路徑已不存在，Set-Location 會輸出錯誤。
        if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path -and
            (Test-Path -LiteralPath $cwd -PathType Container)) {
            Set-Location -LiteralPath $cwd
        }
    } finally {
        # 在 yazi 執行中按 Ctrl+C 會中止整個函式；
        # 放在 finally 才能確保 GetTempFileName() 建立的暫存檔被刪除，不會累積在 %TEMP%。
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}
# 讓直接輸入 yazi 也經由上方的函式；yazi.exe 是子行程，無法改變 shell 的目前目錄。
# 別名的優先順序高於外部程式；yazi.nvim 直接啟動 yazi.exe，不受影響。
Set-Alias yazi y

# =====================================================================
# 非 UTF-8 的輸出與檔案
# =====================================================================
# WezTerm 啟動時已把主控台設為 UTF-8（見 wezterm.lua 第 8 節），
# 但別人寫的程式或檔案若是 Big5／GBK 等編碼，位元組會被當成 UTF-8 解讀而變成亂碼。
# 終端機本身無法猜出原本的編碼，只能在執行時指定：
#   enc big5 { .\legacy.exe }          # 程式直接輸出到畫面
#   enc big5 { git log | Select -First 5 }
#   enc gbk  { Get-Content .\readme.txt }
# 區塊內暫時切換：
#   主控台字碼頁 —— ConPTY 依此把程式寫出的位元組轉成 Unicode 再交給 WezTerm；
#   [Console]::OutputEncoding —— PowerShell 讀取管線中原生程式輸出時的解碼方式；
#   $OutputEncoding —— 經管線送給原生程式的編碼；
#   所有 cmdlet 的 -Encoding 預設值 —— Get-Content、Select-String、Out-File 等讀寫檔案。
# 結束（含 Ctrl+C 中斷）後全部還原。編碼可用名稱（big5、gbk、shift_jis）或字碼頁（950）。
function enc {
    param(
        [Parameter(Mandatory)][string]$Encoding,
        [Parameter(Mandatory)][scriptblock]$Command
    )
    $e = if ($Encoding -match '^\d+$') { [Text.Encoding]::GetEncoding([int]$Encoding) }
         else { [Text.Encoding]::GetEncoding($Encoding) }
    $saved = [Console]::OutputEncoding, [Console]::InputEncoding, $global:OutputEncoding
    $hadDefault = $global:PSDefaultParameterValues.ContainsKey('*:Encoding')
    $oldDefault = $global:PSDefaultParameterValues['*:Encoding']
    try {
        [Console]::OutputEncoding = $e
        [Console]::InputEncoding = $e
        $global:OutputEncoding = $e
        # 5.1 的 -Encoding 是固定列舉、不接受 Big5 等字碼頁（會跳 WARNING）；
        # 5.1 讀檔本來就預設 ANSI（本機為 Big5），所以只在 7 設定。
        if ($PSVersionTable.PSVersion.Major -ge 6) { $global:PSDefaultParameterValues['*:Encoding'] = $e }
        & $Command
    } finally {
        [Console]::OutputEncoding, [Console]::InputEncoding, $global:OutputEncoding = $saved
        if ($hadDefault) { $global:PSDefaultParameterValues['*:Encoding'] = $oldDefault }
        else { $global:PSDefaultParameterValues.Remove('*:Encoding') }
    }
}