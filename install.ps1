<#
.SYNOPSIS
    部署（或驗證）這份 dotfiles。

.DESCRIPTION
    本 repo 以 symlink 部署：每個設定檔只在 repo 中存有一份，
    $HOME 下的對應位置僅為指向 repo 的連結。因此修改設定即是修改 repo，
    不需要同步步驟，也不會產生不一致。

    只有以下情況需要執行本腳本：
      1. 新機器或重灌後的首次部署
      2. 新增模組，需要建立新的連結
      3. 修復失效的連結（可用 -Verify 找出）
    平時修改設定不需要執行。

    ── 相容性 ────────────────────────────────────────────────────────────
    本腳本須相容 Windows PowerShell 5.1：重灌後的 Windows 只有 5.1，
    而 PowerShell 7 正是本腳本要安裝的項目之一。因此不可使用 PS7 專屬語法
    （??、?.、三元運算子、ForEach-Object -Parallel）。
    本檔須存為 UTF-8 with BOM，否則 5.1 會以 ANSI（Big5）解讀中文而產生語法錯誤。

.PARAMETER Verify
    僅檢查、不修改：列出每條連結的狀態、使用者環境變數與 PATH、
    含中文的 .ps1 是否有 BOM、核心工具是否存在、Developer Mode 是否開啟。

.PARAMETER SkipPackages
    跳過階段 2（winget）。

.PARAMETER SkipDeps
    跳過階段 3（npm / cargo）。

.EXAMPLE
    .\install.ps1 -WhatIf
    預覽將執行的動作，不做任何修改。

.EXAMPLE
    .\install.ps1
    完整部署：建立連結、安裝 winget 套件、安裝非 winget 的依賴。

.EXAMPLE
    .\install.ps1 -Verify
    健康檢查。重灌後用來確認所有項目皆正常。
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Verify,
    [switch]$SkipPackages,
    [switch]$SkipDeps
)

$ErrorActionPreference = 'Stop'

# =====================================================================
#  設定
# =====================================================================

$RepoRoot = $PSScriptRoot
$RepoHome = Join-Path $RepoRoot 'home'
$UserHome = $env:USERPROFILE

# ── 透明目錄 ──────────────────────────────────────────────────────────
# 走訪 home/ 時，遇到這些目錄會繼續往下層走訪，而不是連結整個目錄。
# 原因：$HOME 中的對應目錄還含有不屬於本 repo 的檔案。
#   .config\claude：同目錄下有 .credentials.json、sessions/、history.jsonl
#   其餘項目      ：僅是通往 Sublime 設定的路徑，本身不是任何工具的設定目錄
#
# 新增模組時通常不需修改此處：將設定放入 home/.config/<tool>/ 即可，
# 由於 .config 已是透明目錄，<tool> 會自動成為連結點。
# 只有當新模組的上層目錄含有其他程式的檔案時，才需要在此新增一行。
$Transparent = @(
    '.config'
    '.config\claude'
    'AppData'
    'AppData\Roaming'
    'AppData\Roaming\Sublime Text'
    'AppData\Roaming\Sublime Text\Packages'
)

# ── 額外的 link ───────────────────────────────────────────────────────
# 這些連結位於 $HOME 內部，而非從 repo 連到 $HOME：將工具在 Windows 上的
# 預設設定位置指向 .config 下的目錄（.config\<tool> 本身由主要連結計畫建立）。
# 使用 junction 而非 symlink：junction 不需要開發人員模式，且只能指向目錄，正好符合需求。
#   nvim：Windows 版只讀取 $LOCALAPPDATA\nvim
#   yazi：已設定 YAZI_CONFIG_HOME（見下方 $UserEnv），此連結讓未繼承該變數的行程
#         （例如部署前已開啟的終端機）也能從預設位置讀到設定
$ExtraLinks = @(
    [pscustomobject]@{
        Target = Join-Path $env:LOCALAPPDATA 'nvim'
        Source = Join-Path $UserHome '.config\nvim'
        Kind   = 'Junction'
        Label  = 'nvim 預設設定位置'
    }
    [pscustomobject]@{
        Target = Join-Path $env:APPDATA 'yazi\config'
        Source = Join-Path $UserHome '.config\yazi'
        Kind   = 'Junction'
        Label  = 'yazi 預設設定位置'
    }
)

# ── 使用者環境變數 ────────────────────────────────────────────────────
# 寫入 HKCU\Environment。只在值不同時寫入。
$UserEnv = [ordered]@{
    YAZI_CONFIG_HOME = Join-Path $UserHome '.config\yazi'
}

# 需加入 User PATH 的目錄：這兩個安裝程式不會自行修改 PATH。
#   7-Zip        ：yazi 的壓縮檔預覽與 ya pub extract 會呼叫 7z
#   Sublime Text ：yazi.toml 的 edit opener 與 Claude Code 的 EDITOR 會呼叫 subl
# 已在 Machine 或 User PATH 中、或目錄不存在（尚未安裝）時略過。
$UserPathDirs = @(
    (Join-Path $env:ProgramFiles '7-Zip')
    (Join-Path $env:ProgramFiles 'Sublime Text')
)

# ── 階段 3：非-winget 依賴 ────────────────────────────────────────────
$ExtraDeps = @(
    [pscustomobject]@{
        Name    = 'ccstatusline'
        Probe   = 'ccstatusline'
        Command = { npm install -g ccstatusline }
        Why     = 'claude/settings.json 的 statusLine 靠它'
    }
    [pscustomobject]@{
        Name    = 'rtk'
        Probe   = 'rtk'
        Command = { cargo install --git https://github.com/rtk-ai/rtk }
        Why     = 'claude/settings.json 的 PreToolUse hook 靠它'
    }
    # 若未安裝 Claude Code，repo 中的 CLAUDE.md、settings.json 與 skills 皆不會生效。
    # 不放在 winget-core.json：本機的 claude 由原生安裝程式安裝
    # （~/.local/bin/claude.exe，會自動更新），若再以 winget 安裝，PATH 上會有兩個執行檔。
    # Probe 可避免此情況：已有 claude 時跳過，只在全新機器上安裝。
    [pscustomobject]@{
        Name    = 'Claude Code'
        Probe   = 'claude'
        Command = { winget install --id Anthropic.ClaudeCode --exact --silent `
                        --accept-package-agreements --accept-source-agreements `
                        --disable-interactivity }
        Why     = '~/.config/claude 底下的設定與 41 個 skills 全靠它'
    }
    # 以下三項供 nvim 的 Python LSP 使用（lua-language-server 在 winget-core.json）。
    # uv 不放在 winget-core.json 的理由與 Claude Code 相同：本機的 uv 由官方安裝程式
    # 安裝於 ~/.local/bin，已存在時由 Probe 略過，避免 PATH 上出現兩個 uv。
    # Python 工具一律以 uv tool 安裝，不使用全域 pip。
    [pscustomobject]@{
        Name    = 'uv'
        Probe   = 'uv'
        Command = { winget install --id astral-sh.uv --exact --silent `
                        --accept-package-agreements --accept-source-agreements `
                        --disable-interactivity }
        Why     = '安裝 basedpyright 與 ruff 所需'
    }
    [pscustomobject]@{
        Name    = 'basedpyright'
        Probe   = 'basedpyright-langserver'
        # update-shell 確保 uv tool 的安裝目錄（~/.local/bin）在 User PATH 中
        Command = { uv tool install basedpyright; uv tool update-shell }
        Why     = 'nvim 的 Python 補全與型別檢查（lsp/basedpyright.lua）'
    }
    [pscustomobject]@{
        Name    = 'ruff'
        Probe   = 'ruff'
        Command = { uv tool install ruff }
        Why     = 'nvim 的 Python lint 與格式化（lsp/ruff.lua）'
    }
)

# ── -Verify 會檢查的核心工具 ─────────────────────────────────────────
$CoreTools = @(
    'wezterm-gui', 'starship', 'pwsh', 'zoxide', 'yazi', 'fzf',
    'rg', 'fd', '7z', 'nvim', 'git', 'gh', 'subl',
    # yazi 預覽與搜尋所需：影片縮圖、JSON、PDF、SVG／HEIC／字型、全機檔名搜尋
    'ffmpeg', 'jq', 'pdftoppm', 'magick', 'es',
    'node', 'cargo', 'ccstatusline', 'rtk', 'claude',
    # nvim 的 LSP
    'uv', 'lua-language-server', 'basedpyright-langserver', 'ruff'
)

$BackupRoot = Join-Path $UserHome ('.dotfiles-backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))

# =====================================================================
#  輔助函式
# =====================================================================

function Write-Head($Text) {
    Write-Host ''
    Write-Host "── $Text " -NoNewline -ForegroundColor Cyan
    Write-Host ('─' * [Math]::Max(0, 68 - $Text.Length)) -ForegroundColor DarkCyan
}

function Write-Item($Status, $Text, $Detail) {
    $map = @{
        OK   = @{ Mark = ' ok '; Color = 'Green'      }
        Skip = @{ Mark = ' -- '; Color = 'DarkGray'   }
        Do   = @{ Mark = ' ++ '; Color = 'Yellow'     }
        Bad  = @{ Mark = ' XX '; Color = 'Red'        }
        Warn = @{ Mark = ' !! '; Color = 'DarkYellow' }
    }
    $m = $map[$Status]
    Write-Host $m.Mark -NoNewline -ForegroundColor $m.Color
    Write-Host $Text.PadRight(46) -NoNewline
    if ($Detail) { Write-Host $Detail -ForegroundColor DarkGray } else { Write-Host '' }
}

# 回傳 symlink 的目標路徑；非連結時回傳 $null。
# Get-Item 回報 symlink 目標的方式在 5.1 與 7 之間不同，此處統一為單一字串。
function Get-LinkTarget([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }
    if ($item.PSObject.Properties['LinkTarget'] -and $item.LinkTarget) { return [string]$item.LinkTarget }
    if ($item.PSObject.Properties['Target']) {
        $t = @($item.Target)
        if ($t.Count -gt 0) { return [string]$t[0] }
    }
    return $null
}

function Test-SameTarget([string]$A, [string]$B) {
    if (-not $A -or -not $B) { return $false }
    return ($A.TrimEnd('\') -ieq $B.TrimEnd('\'))
}

# 只刪除連結本身，不遞迴刪除目標內容。
# 舊版 PowerShell 的 Remove-Item 對指向目錄的 symlink 會連同目標內容一併刪除，
# 因此改用 .NET 的非遞迴 Delete。
function Remove-LinkOnly([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) { [IO.Directory]::Delete($Path) } else { [IO.File]::Delete($Path) }
}

# Kind 為 'Junction' 時建立目錄 junction，其餘（File、Directory）建立 symlink。
function New-Link([string]$Target, [string]$Source, [string]$Kind) {
    $parent = Split-Path $Target -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $type = 'SymbolicLink'
    if ($Kind -eq 'Junction') { $type = 'Junction' }
    New-Item -ItemType $type -Path $Target -Value $Source -Force:$false | Out-Null
}

function Move-ToBackup([string]$Path) {
    $rel = $Path
    if ($Path.StartsWith($UserHome, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $Path.Substring($UserHome.Length).TrimStart('\')
    } else {
        $rel = ($Path -replace '^[A-Za-z]:\\', '')
    }
    $dest = Join-Path $BackupRoot $rel
    $destParent = Split-Path $dest -Parent
    if (-not (Test-Path -LiteralPath $destParent)) {
        New-Item -ItemType Directory -Force -Path $destParent | Out-Null
    }
    Move-Item -LiteralPath $Path -Destination $dest
    return $dest
}

function Test-DeveloperMode {
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
    if (-not (Test-Path $k)) { return $false }
    $v = (Get-ItemProperty -Path $k -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
    return ($v -eq 1)
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 重新從登錄檔讀取 PATH。
# 行程的 PATH 在啟動時複製自登錄檔，之後安裝的工具不會出現在目前的 shell 中。
function Update-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'
}

# 目錄是否已在 Machine 或 User PATH 中（依登錄檔，不看目前行程的 PATH）
function Test-InRegistryPath([string]$Dir) {
    $all = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
        [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
    ) | Where-Object { $_ } | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') }
    return ($all -contains $Dir.TrimEnd('\'))
}

# 將目錄附加到 User PATH。
# 直接操作登錄檔並保留原本的值類型（REG_SZ 或 REG_EXPAND_SZ）與未展開的 %VAR%；
# [Environment]::SetEnvironmentVariable 會把讀到的已展開值寫回，破壞 %VAR% 項目。
function Add-UserPathDir([string]$Dir) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try {
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        $raw = ''
        if ($key.GetValueNames() -contains 'Path') {
            $kind = $key.GetValueKind('Path')
            $raw = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        $new = (@($raw.TrimEnd(';'), $Dir) | Where-Object { $_ }) -join ';'
        $key.SetValue('Path', $new, $kind)
    } finally {
        $key.Close()
    }
}

# 通知其他程式（檔案總管等）環境變數已變更，之後啟動的程式才會讀到新值
function Send-EnvironmentChanged {
    if (-not ('Dotfiles.NativeMethods' -as [type])) {
        Add-Type -Namespace Dotfiles -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $result = [UIntPtr]::Zero
    # HWND_BROADCAST = 0xFFFF、WM_SETTINGCHANGE = 0x1A、SMTO_ABORTIFHUNG = 0x2
    [void][Dotfiles.NativeMethods]::SendMessageTimeout([IntPtr]0xFFFF, 0x1A, [UIntPtr]::Zero,
        'Environment', 2, 5000, [ref]$result)
}

# 含非 ASCII 字元但沒有 UTF-8 BOM 的 .ps1（5.1 會以 ANSI 解讀而產生語法錯誤）
function Get-Ps1MissingBom {
    Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Filter '*.ps1' |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } |
        Where-Object {
            $bytes = [IO.File]::ReadAllBytes($_.FullName)
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $nonAscii = $false
            foreach ($b in $bytes) { if ($b -ge 0x80) { $nonAscii = $true; break } }
            $nonAscii -and -not $hasBom
        }
}

# 走訪 home/，依目錄結構產生連結計畫。
# 對應關係不另外定義，而是直接由 home/ 的目錄結構決定。
function Get-LinkPlan {
    $plan = New-Object System.Collections.ArrayList
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue('') | Out-Null

    while ($queue.Count -gt 0) {
        $rel = [string]$queue.Dequeue()
        $abs = if ($rel) { Join-Path $RepoHome $rel } else { $RepoHome }

        foreach ($child in Get-ChildItem -LiteralPath $abs -Force) {
            $childRel = if ($rel) { Join-Path $rel $child.Name } else { $child.Name }

            if ($child.PSIsContainer -and ($Transparent -contains $childRel)) {
                $queue.Enqueue($childRel) | Out-Null
                continue
            }

            $kind = 'File'
            if ($child.PSIsContainer) { $kind = 'Directory' }

            [void]$plan.Add([pscustomobject]@{
                Rel    = $childRel
                Label  = $childRel
                Source = $child.FullName
                Target = Join-Path $UserHome $childRel
                Kind   = $kind
            })
        }
    }

    # $ExtraLinks 排在主要連結之後：它們指向的 .config\<tool> 由主要連結建立。
    # ~/.config/claude/settings.json 等檔案可能正由執行中的 Claude Code 開啟，
    # 導致搬移失敗；因此排在最後，確保其他連結先完成。
    $ordered = @($plan | Where-Object { $_.Rel -notlike '.config\claude\*' })
    $ordered += @($ExtraLinks)
    $ordered += @($plan | Where-Object { $_.Rel -like '.config\claude\*' })
    return $ordered
}

# =====================================================================
#  環境前置檢查
# =====================================================================

if (-not (Test-Path -LiteralPath $RepoHome)) {
    throw "找不到 $RepoHome —— 這支腳本必須放在 repo 根目錄執行。"
}

$devMode = Test-DeveloperMode
$isAdmin = Test-Admin

# =====================================================================
#  -Verify：僅檢查，不修改
# =====================================================================

if ($Verify) {
    Write-Head '環境'
    if ($devMode) {
        Write-Item OK 'Developer Mode' '非管理員也能建 symlink'
    } elseif ($isAdmin) {
        Write-Item Warn 'Developer Mode' '未開啟，但目前是管理員，仍可建 symlink'
    } else {
        Write-Item Bad 'Developer Mode' '未開啟且非管理員 → 無法建 symlink'
    }
    Write-Item OK 'Repo' $RepoRoot

    Write-Head '連結'
    $bad = 0

    foreach ($p in @(Get-LinkPlan)) {
        $label = $p.Label
        if (-not (Test-Path -LiteralPath $p.Target)) {
            Write-Item Bad $label '目標不存在（尚未部署？）'; $bad++
            continue
        }
        $lt = Get-LinkTarget $p.Target
        if (-not $lt) {
            # 這是 Sublime 等以原子方式存檔的編輯器破壞連結後的現象：
            # 連結被替換為實體檔案，此後修改 repo 不再生效，且不會有任何提示。
            Write-Item Bad $label '是實體檔案／目錄，不是 symlink'; $bad++
            continue
        }
        if (-not (Test-SameTarget $lt $p.Source)) {
            Write-Item Bad $label "指向別處：$lt"; $bad++
            continue
        }
        if (-not (Test-Path -LiteralPath $p.Source)) {
            Write-Item Bad $label '指向的來源不存在（斷鏈）'; $bad++
            continue
        }
        Write-Item OK $label ''
    }

    Write-Head '使用者環境變數'
    foreach ($name in $UserEnv.Keys) {
        $actual = [Environment]::GetEnvironmentVariable($name, 'User')
        if ($actual -eq $UserEnv[$name]) { Write-Item OK $name $actual }
        elseif ($actual)                 { Write-Item Bad $name "值不同：$actual"; $bad++ }
        else                             { Write-Item Bad $name '未設定'; $bad++ }
    }
    foreach ($dir in $UserPathDirs) {
        if (Test-InRegistryPath $dir)             { Write-Item OK "PATH：$dir" '' }
        elseif (-not (Test-Path -LiteralPath $dir)) { Write-Item Warn "PATH：$dir" '目錄不存在（尚未安裝）' }
        else                                      { Write-Item Bad "PATH：$dir" '不在 PATH 中'; $bad++ }
    }

    Write-Head '.ps1 編碼'
    $noBom = @(Get-Ps1MissingBom)
    if ($noBom.Count -eq 0) {
        Write-Item OK '含中文的 .ps1 皆有 UTF-8 BOM' ''
    } else {
        foreach ($f in $noBom) {
            Write-Item Bad $f.FullName.Substring($RepoRoot.Length).TrimStart('\') '含非 ASCII 字元但沒有 BOM'
            $bad++
        }
    }

    Write-Head '核心工具'
    $missing = 0
    foreach ($t in $CoreTools) {
        $c = Get-Command $t -ErrorAction SilentlyContinue
        if ($c) { Write-Item OK $t $c.Source }
        else    { Write-Item Bad $t '不在 PATH 上'; $missing++ }
    }

    Write-Head '結論'
    if ($bad -eq 0 -and $missing -eq 0) {
        Write-Host ' 全綠。' -ForegroundColor Green
    } else {
        Write-Host " 設定問題 $bad 項、缺少工具 $missing 項。" -ForegroundColor Yellow
        if ($bad -gt 0)     { Write-Host ' 修連結與環境變數：.\install.ps1；BOM 問題須手動以 UTF-8 with BOM 重新存檔' -ForegroundColor DarkGray }
        if ($missing -gt 0) { Write-Host ' 補工具：.\install.ps1' -ForegroundColor DarkGray }
    }
    return
}

# =====================================================================
#  階段 1：連結與使用者環境變數
# =====================================================================

Write-Head '階段 1 / 3：連結與環境變數'

if (-not $devMode -and -not $isAdmin) {
    throw '無法建立 symlink：Developer Mode 未開啟且非管理員。請至「設定 → 系統 → 開發人員專用」開啟 Developer Mode 後重試。'
}

$plan = @(Get-LinkPlan)
$stats = @{ Created = 0; Skipped = 0; BackedUp = 0; Failed = 0 }

foreach ($p in $plan) {
    $label = $p.Label

    # 已是正確的連結則略過（冪等）
    $lt = Get-LinkTarget $p.Target
    if ($lt -and (Test-SameTarget $lt $p.Source)) {
        Write-Item Skip $label '已是正確的 link'
        $stats.Skipped++
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($p.Target, "link → $($p.Source)")) {
        if (Test-Path -LiteralPath $p.Target) {
            Write-Item Do $label '會先備份既有內容，再建 link'
        } else {
            Write-Item Do $label '會建立 link'
        }
        continue
    }

    try {
        if (Test-Path -LiteralPath $p.Target) {
            if ($lt) {
                # 指向其他位置的舊連結：只移除連結，不動其目標
                Remove-LinkOnly $p.Target
            } else {
                $moved = Move-ToBackup $p.Target
                $stats.BackedUp++
                Write-Item Warn $label "已備份 → $moved"
            }
        }
        New-Link -Target $p.Target -Source $p.Source -Kind $p.Kind
        Write-Item OK $label ''
        $stats.Created++
    } catch {
        Write-Item Bad $label $_.Exception.Message
        $stats.Failed++
    }
}

# 使用者環境變數與 PATH
$envChanged = $false
foreach ($name in $UserEnv.Keys) {
    $value = $UserEnv[$name]
    if ([Environment]::GetEnvironmentVariable($name, 'User') -eq $value) {
        Write-Item Skip $name '已設定'
        continue
    }
    if (-not $PSCmdlet.ShouldProcess("User 環境變數 $name", "設為 $value")) {
        Write-Item Do $name "會設為 $value"
        continue
    }
    # 寫入登錄檔但先不廣播，最後統一由 Send-EnvironmentChanged 通知
    [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Environment', $name, $value)
    Set-Item -Path "Env:$name" -Value $value
    Write-Item OK $name $value
    $envChanged = $true
}
if ($envChanged) { Send-EnvironmentChanged }

Write-Host ''
Write-Host (" 建立 {0}、跳過 {1}、備份 {2}、失敗 {3}" -f $stats.Created, $stats.Skipped, $stats.BackedUp, $stats.Failed) -ForegroundColor Cyan
if ($stats.BackedUp -gt 0) {
    Write-Host " 備份位置：$BackupRoot" -ForegroundColor DarkGray
}
if ($stats.Failed -gt 0) {
    # 連結是整份設定的核心，未全部建立時不繼續安裝套件
    Write-Host ' 失敗的項目多半是「檔案正被其他程式開著」。關掉該程式後重跑即可（本腳本冪等）。' -ForegroundColor Yellow
    throw "階段 1 有 $($stats.Failed) 條連結建立失敗，已中斷，未執行階段 2、3。"
}

# =====================================================================
#  階段 2：winget
#  單一套件安裝失敗時只發出警告，不中斷整體流程。
# =====================================================================

if ($SkipPackages) {
    Write-Head '階段 2 / 3：winget（已跳過）'
} else {
    Write-Head '階段 2 / 3：winget'

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Item Bad 'winget' '不存在。請先從 Microsoft Store 安裝「應用程式安裝程式」。'
    } else {
        $manifest = Join-Path $RepoRoot 'bootstrap\winget-core.json'
        $ids = (Get-Content $manifest -Raw | ConvertFrom-Json).Sources[0].Packages.PackageIdentifier

        foreach ($id in $ids) {
            if (-not $PSCmdlet.ShouldProcess($id, 'winget install')) {
                Write-Item Do $id '會嘗試安裝'
                continue
            }
            # winget 會自行偵測是否已安裝，不需事先檢查
            $out = winget install --id $id --exact --silent `
                       --accept-package-agreements --accept-source-agreements `
                       --disable-interactivity 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Item OK $id ''
            } elseif ("$out" -match '已安裝|already installed|no applicable upgrade|沒有可用的升級') {
                Write-Item Skip $id '已安裝'
            } else {
                Write-Item Warn $id "安裝未成功（exit $LASTEXITCODE），略過"
            }
        }
    }
}

# 補上 PATH：7-Zip 與 Sublime Text 在階段 2 才會安裝，因此放在階段 2 之後。
# 即使指定 -SkipPackages 也會執行（已安裝時仍需確認 PATH）。
Write-Host ''
$pathChanged = $false
foreach ($dir in $UserPathDirs) {
    if (Test-InRegistryPath $dir) {
        Write-Item Skip "PATH：$dir" '已在 PATH 中'
        continue
    }
    if (-not (Test-Path -LiteralPath $dir)) {
        Write-Item Warn "PATH：$dir" '目錄不存在（未安裝），略過'
        continue
    }
    if (-not $PSCmdlet.ShouldProcess('User PATH', "加入 $dir")) {
        Write-Item Do "PATH：$dir" '會加入 User PATH'
        continue
    }
    Add-UserPathDir $dir
    Write-Item OK "PATH：$dir" '已加入 User PATH'
    $pathChanged = $true
}
if ($pathChanged) { Send-EnvironmentChanged }

# =====================================================================
#  階段 3：非 winget 的依賴
#  ccstatusline 經由 npm、rtk 經由 cargo、Python LSP 經由 uv 安裝，都可能耗時或失敗
#  （cargo 需編譯），因此失敗時同樣只發出警告。它們失效只影響 Claude Code 的
#  狀態列與 hook，以及 nvim 的 Python LSP，不影響終端機本身。
# =====================================================================

if ($SkipDeps) {
    Write-Head '階段 3 / 3：非-winget 依賴（已跳過）'
} else {
    Write-Head '階段 3 / 3：非-winget 依賴'

    foreach ($d in $ExtraDeps) {
        # 每一項之前都重新讀取 PATH：階段 2 安裝的 Node、Rustup，以及前一項安裝的 uv，
        # 都不會出現在目前 shell 的 PATH 中，否則後續的 npm、cargo、uv 會找不到。
        Update-SessionPath
        if (Get-Command $d.Probe -ErrorAction SilentlyContinue) {
            Write-Item Skip $d.Name '已安裝'
            continue
        }
        if (-not $PSCmdlet.ShouldProcess($d.Name, 'install')) {
            Write-Item Do $d.Name $d.Why
            continue
        }
        Write-Host "     安裝 $($d.Name)（$($d.Why)）…" -ForegroundColor DarkGray
        try {
            & $d.Command 2>&1 | Out-Null
            Update-SessionPath
            if (Get-Command $d.Probe -ErrorAction SilentlyContinue) {
                Write-Item OK $d.Name ''
            } else {
                Write-Item Warn $d.Name '指令跑完但仍找不到執行檔——可能需要開新的 shell 讓 PATH 生效'
            }
        } catch {
            Write-Item Warn $d.Name "安裝失敗，略過：$($_.Exception.Message)"
        }
    }
}

# =====================================================================
#  收尾
# =====================================================================

Write-Head '完成'
Write-Host ' 下一步：'
Write-Host '   1. 開一個新的 pwsh 視窗（讓 PATH 與 profile 生效）' -ForegroundColor DarkGray
Write-Host '   2. .\install.ps1 -Verify   ← 確認全綠' -ForegroundColor DarkGray
Write-Host ''
Write-Host ' 提醒：以後改 config 請在 repo 目錄底下改（見 README 的「日常維護」）。' -ForegroundColor Yellow
Write-Host ''
