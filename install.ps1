<#
.SYNOPSIS
    部署（或驗證）這份 dotfiles。

.DESCRIPTION
    這份 repo 用 symlink 部署：磁碟上每個 config 的位元組只存在一份，就在 repo 裡，
    $HOME 底下的對應位置只是指標。因此「改 config」與「改 repo」是同一件事，
    沒有任何同步步驟，也不存在漂移。

    本腳本只在三種時候需要跑：
      1. 新機器 / 重灌後第一次部署
      2. 新增了一個模組，需要多一條 link
      3. 某條 link 斷了要修（用 -Verify 找出來）
    平常改 config 不需要跑它。

    ── 相容性 ────────────────────────────────────────────────────────────
    刻意維持 Windows PowerShell 5.1 相容：重灌後的乾淨 Windows 只有 5.1，
    而 pwsh 7 正是這支腳本要安裝的東西之一。因此請勿在此檔使用 PS7 專屬語法
    （?? 、?. 、三元運算子、ForEach-Object -Parallel）。
    本檔必須存成 UTF-8 with BOM，否則 5.1 會用 ANSI(Big5) 解讀中文而語法錯誤。

.PARAMETER Verify
    只檢查不修改：列出每條 link 的狀態、核心工具是否在位、Developer Mode 是否開啟。

.PARAMETER SkipPackages
    跳過階段 2（winget）。

.PARAMETER SkipDeps
    跳過階段 3（npm / cargo）。

.EXAMPLE
    .\install.ps1 -WhatIf
    預覽會做什麼，不動任何東西。

.EXAMPLE
    .\install.ps1
    完整部署：建 link、裝 winget 套件、裝非-winget 依賴。

.EXAMPLE
    .\install.ps1 -Verify
    健檢。重灌後確認「全綠了嗎」就用這個。
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

# ── 「透明」目錄 ──────────────────────────────────────────────────────
# 走訪 home/ 時，遇到這些目錄要「繼續往下走」而不是把整個目錄 link 過去。
# 理由只有一個：對應的 $HOME 位置底下住著不屬於這個 repo 的東西。
#   .config\claude → 同目錄有 .credentials.json / sessions/ / history.jsonl
#   其餘幾層       → 純粹是通往 Sublime 的路徑，不是任何工具的設定目錄
#
# ★ 新增模組時通常不必動這裡：把 config 丟進 home/.config/<tool>/ 即可，
#   .config 已經是透明的，<tool> 就會自動成為一個 link 點。
#   只有當「新模組的父目錄還住著別人的東西」時才需要在此加一行。
$Transparent = @(
    '.config'
    '.config\claude'
    'AppData'
    'AppData\Roaming'
    'AppData\Roaming\Sublime Text'
    'AppData\Roaming\Sublime Text\Packages'
)

# ── 額外的 link ───────────────────────────────────────────────────────
# 不是「repo → $HOME」，而是 $HOME 內部的轉接。
# nvim 在 Windows 原生只讀 $LOCALAPPDATA\nvim；這條把它接到 .config\nvim，
# 讓 nvim 跟其他工具一樣待在 .config 底下（第二跳，第一跳由主計畫負責）。
$ExtraLinks = @(
    [pscustomobject]@{
        Target = Join-Path $env:LOCALAPPDATA 'nvim'
        Source = Join-Path $UserHome '.config\nvim'
        Kind   = 'Directory'
        Note   = 'nvim 第二跳'
    }
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
    # 沒有它，收進來的 CLAUDE.md / settings.json / skills 全是死檔。
    # 刻意放在這裡而不是 winget-core.json：這台機器上的 claude 是原生安裝器裝的
    # （~/.local/bin/claude.exe，會自我更新），winget 再裝一份會有兩個執行檔搶 PATH。
    # 靠下面的 Probe 擋住——已經有 claude 就跳過，只有空機器才會真的安裝。
    [pscustomobject]@{
        Name    = 'Claude Code'
        Probe   = 'claude'
        Command = { winget install --id Anthropic.ClaudeCode --exact --silent `
                        --accept-package-agreements --accept-source-agreements `
                        --disable-interactivity }
        Why     = '~/.config/claude 底下的設定與 41 個 skills 全靠它'
    }
)

# ── -Verify 會檢查的核心工具 ─────────────────────────────────────────
$CoreTools = @(
    'wezterm-gui', 'starship', 'pwsh', 'zoxide', 'yazi', 'fzf',
    'rg', 'fd', '7z', 'nvim', 'git', 'gh', 'subl',
    # yazi 內建預覽會呼叫的：影片縮圖 / JSON / PDF / SVG·HEIC·字型 / 全機檔名搜尋
    'ffmpeg', 'jq', 'pdftoppm', 'magick', 'es',
    'node', 'cargo', 'ccstatusline', 'rtk', 'claude'
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

# Get-Item 對 symlink 的回報方式在 5.1 與 7 之間不同，這裡統一成一個字串（非 link 回 $null）。
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

# 只刪 link 本身，永遠不遞迴刪內容。
# Remove-Item 在舊版 PowerShell 對「指向目錄的 symlink」會連目標內容一起刪，
# 這裡改用 .NET 的非遞迴 Delete，從機制上排除那個風險。
function Remove-LinkOnly([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) { [IO.Directory]::Delete($Path) } else { [IO.File]::Delete($Path) }
}

function New-Link([string]$Target, [string]$Source) {
    $parent = Split-Path $Target -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    New-Item -ItemType SymbolicLink -Path $Target -Value $Source -Force:$false | Out-Null
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

# 走訪 home/，把「結構」翻譯成「link 計畫」。
# 對應關係不是寫在某張表裡，而是 home/ 的目錄結構本身。
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
                Source = $child.FullName
                Target = Join-Path $UserHome $childRel
                Kind   = $kind
                Note   = ''
            })
        }
    }

    # ~/.config/claude/settings.json 等檔案很可能正被執行中的 Claude Code 開著，
    # Move 會失敗。排到最後，讓前面的 link 全部先成功落地。
    $ordered = @($plan | Where-Object { $_.Rel -notlike '.config\claude\*' })
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
#  -Verify：只看不動
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

    Write-Head 'Symlinks'
    $bad = 0
    $all = @(Get-LinkPlan) + @($ExtraLinks | ForEach-Object {
        [pscustomobject]@{ Rel = $_.Note; Source = $_.Source; Target = $_.Target; Kind = $_.Kind; Note = $_.Note }
    })

    foreach ($p in $all) {
        $label = $p.Rel
        if (-not (Test-Path -LiteralPath $p.Target)) {
            Write-Item Bad $label '目標不存在（尚未部署？）'; $bad++
            continue
        }
        $lt = Get-LinkTarget $p.Target
        if (-not $lt) {
            # 這正是 Sublime 這類「原子存檔」編輯器打斷 link 後的症狀：
            # link 被換成一個真實檔案，改 repo 從此不再生效，而且悄無聲息。
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
        Write-Host " symlink 問題 $bad 項、缺少工具 $missing 項。" -ForegroundColor Yellow
        if ($bad -gt 0)     { Write-Host ' 修 link：.\install.ps1' -ForegroundColor DarkGray }
        if ($missing -gt 0) { Write-Host ' 補工具：.\install.ps1 -SkipPackages:$false' -ForegroundColor DarkGray }
    }
    return
}

# =====================================================================
#  階段 1：Symlink
# =====================================================================

Write-Head '階段 1 / 3：Symlink'

if (-not $devMode -and -not $isAdmin) {
    throw '無法建立 symlink：Developer Mode 未開啟且非管理員。請至「設定 → 系統 → 開發人員專用」開啟 Developer Mode 後重試。'
}

$plan = @(Get-LinkPlan)
$stats = @{ Created = 0; Skipped = 0; BackedUp = 0; Failed = 0 }

foreach ($p in $plan) {
    $label = $p.Rel

    # 已經是正確的 link → 什麼都不做（冪等）
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
                # 指向別處的舊 link：只拆 link，不碰它指到的東西
                Remove-LinkOnly $p.Target
            } else {
                $moved = Move-ToBackup $p.Target
                $stats.BackedUp++
                Write-Item Warn $label "已備份 → $moved"
            }
        }
        New-Link -Target $p.Target -Source $p.Source
        Write-Item OK $label ''
        $stats.Created++
    } catch {
        Write-Item Bad $label $_.Exception.Message
        $stats.Failed++
    }
}

# 額外的 $HOME 內部轉接
foreach ($e in $ExtraLinks) {
    $label = $e.Note
    $lt = Get-LinkTarget $e.Target
    if ($lt -and (Test-SameTarget $lt $e.Source)) {
        Write-Item Skip $label '已是正確的 link'
        $stats.Skipped++
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($e.Target, "link → $($e.Source)")) {
        Write-Item Do $label '會建立 link'
        continue
    }
    try {
        if (Test-Path -LiteralPath $e.Target) {
            if ($lt) { Remove-LinkOnly $e.Target }
            else {
                $moved = Move-ToBackup $e.Target
                $stats.BackedUp++
                Write-Item Warn $label "已備份 → $moved"
            }
        }
        New-Link -Target $e.Target -Source $e.Source
        Write-Item OK $label ''
        $stats.Created++
    } catch {
        Write-Item Bad $label $_.Exception.Message
        $stats.Failed++
    }
}

Write-Host ''
Write-Host (" 建立 {0}、跳過 {1}、備份 {2}、失敗 {3}" -f $stats.Created, $stats.Skipped, $stats.BackedUp, $stats.Failed) -ForegroundColor Cyan
if ($stats.BackedUp -gt 0) {
    Write-Host " 備份位置：$BackupRoot" -ForegroundColor DarkGray
}
if ($stats.Failed -gt 0) {
    Write-Host ' 失敗的項目多半是「檔案正被其他程式開著」。關掉該程式後重跑即可（本腳本冪等）。' -ForegroundColor Yellow
}

# =====================================================================
#  階段 2：winget
#  寬容失敗：單一套件裝不起來只警告，不中斷整體流程。
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
            # winget 自己就會偵測「已安裝」，不必先查一次
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

# =====================================================================
#  階段 3：非-winget 依賴
#  ccstatusline 走 npm、rtk 走 cargo。兩者都可能很慢或失敗（cargo 要編譯），
#  所以同樣寬容失敗——它們壞掉只會讓 Claude Code 的狀態列與 hook 失效，
#  不影響終端機本身。
# =====================================================================

if ($SkipDeps) {
    Write-Head '階段 3 / 3：非-winget 依賴（已跳過）'
} else {
    Write-Head '階段 3 / 3：非-winget 依賴'

    # 階段 2 剛用 winget 裝的 Node / Rustup 不會出現在「這個 shell」的 PATH 裡——
    # PATH 是行程啟動時從登錄檔複製過來的，之後的變更只有新行程看得到。
    # 空機器上若不重讀，下面的 npm 與 cargo 會全部找不到而失敗。
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machinePath, $userPath) | Where-Object { $_ }) -join ';'

    foreach ($d in $ExtraDeps) {
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
