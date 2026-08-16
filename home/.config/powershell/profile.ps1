# 共用 profile（快取版）：Windows PowerShell 5.1 與 PowerShell 7 都 dot-source 這支
# 檔案存成 UTF-8 with BOM，否則 5.1 會用 ANSI(Big5) 解讀中文而語法錯誤
#
# 設計原則：開 shell 時「不 spawn 任何外部程序、不做萬用字元掃描」。
# 所有需要 spawn 才拿得到的東西（starship/zoxide 的 init script、工具路徑）
# 都預先算好存進 ~/.cache/pwsh-init/，之後每次開 shell 只是讀檔 + dot-source。
# 快取失效條件：對應的 exe 比快取檔新，或快取檔不存在 → 自動重建。
# 想手動重建：Remove-Item ~/.cache/pwsh-init -Recurse

$InitCache = Join-Path $HOME '.cache\pwsh-init'
if (-not [IO.Directory]::Exists($InitCache)) { New-Item -ItemType Directory -Force $InitCache | Out-Null }

# 解析一次工具路徑就存起來；Get-Command 第一次呼叫要掃整個 PATH + 建 command cache，
# 在這台機器上單次就要 ~180ms。
$ToolsFile = Join-Path $InitCache 'tools.ps1'

$zoxideDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe'

if ([IO.File]::Exists($ToolsFile)) {
    . $ToolsFile
} else {
    # winget 裝的工具不一定在這個 session 的 PATH 裡（session 開在安裝之前就會這樣）
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
# PATH：yazi 是靠 PATH 找外部工具的，這兩個裝好了卻都不在 PATH 上
# =====================================================================
# winget 裝的工具(含 ffmpeg/ffprobe)已改由 ~\.local\bin 的硬連結統一供應，
# 那個目錄本來就在 User PATH 上，所以這裡不必再補。維護見 sync-winget-shims.ps1。
$extraPath = @(
    (Join-Path $env:ProgramFiles '7-Zip'),        # 內建的壓縮檔預覽與 ya pub extract 都呼叫 7z
    (Join-Path $env:ProgramFiles 'Sublime Text')  # yazi.toml 的 edit opener 設為 subl
) | Where-Object { $_ }

$currentPath = $env:Path -split ';'
foreach ($dir in $extraPath) {
    if ($currentPath -notcontains $dir) { $env:Path = "$env:Path;$dir" }
}

# =====================================================================
# Starship
# =====================================================================
if ($env:TERMINAL_EMULATOR -eq 'JetBrains-JediTerm') {
    $env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship-tokyo-night-jetbrains.toml'
} else {
    $env:STARSHIP_CONFIG = Join-Path $HOME '.config\starship-tokyo-night-user.toml'
}

# `starship init powershell` 只是個 bootstrap：它印出來的東西自己又會再 spawn 一次
# `starship init powershell --print-full-init`。直接快取 full-init 可省掉那兩次 spawn。
# Get-Item 走 FileSystem provider，每次都要建 PSObject 並做 ACL/reparse 檢查；
# 這裡的四次檢查在這台機器上量到 ~144ms。改用 .NET 靜態方法直接問檔案系統，剩下個位數 ms。
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
# 打 y 啟動 yazi；離開(q)時 shell 自動 cd 到你最後所在的目錄。
# y <path> 可直接開在指定位置。官方 --cwd-file 寫法。
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        yazi $args --cwd-file="$tmp"
        $cwd = Get-Content -LiteralPath $tmp -Encoding UTF8
        # Test-Path 這個條件不能省：在 yazi 裡把當前目錄刪掉(d)再離開時，
        # cwd-file 記的是已經不存在的路徑，Set-Location 會噴一行紅字。
        if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path -and
            (Test-Path -LiteralPath $cwd -PathType Container)) {
            Set-Location -LiteralPath $cwd
        }
    } finally {
        # yazi 執行中按 Ctrl+C 會中止整個函式；沒有 finally 的話
        # GetTempFileName() 建出來的實體檔案會一直累積在 %TEMP%。
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
    }
}