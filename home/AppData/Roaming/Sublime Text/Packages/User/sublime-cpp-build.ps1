param(
    [ValidateSet("BuildRun", "Compile", "Terminal", "RunOnly", "RunOnlyTerminal")]
    [string] $Mode = "BuildRun",

    [Parameter(Position = 0)]
    [AllowEmptyString()]
    [string] $Source = ""
)

$ErrorActionPreference = "Stop"

$compiler = "C:\Program Files\mingw64\bin\g++.exe"

function Stop-Build {
    param([string] $Message)

    Write-Host $Message
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Source)) {
    Stop-Build "Save the current file as a .cpp file first, then build again."
}

if (-not (Test-Path -LiteralPath $compiler)) {
    Stop-Build "Cannot find g++ at: $compiler"
}

try {
    $sourceItem = Get-Item -LiteralPath $Source -ErrorAction Stop
}
catch {
    Stop-Build "Cannot find source file: $Source"
}

if ($sourceItem.PSIsContainer) {
    Stop-Build "The build target is a folder, not a C++ source file: $Source"
}

$sourcePath = $sourceItem.FullName
$extension = [System.IO.Path]::GetExtension($sourcePath).ToLowerInvariant()

if ($extension -notin @(".cpp", ".cc", ".cxx", ".c++")) {
    Write-Host "Warning: this file is not using a common C++ extension: $sourcePath"
}

$outputPath = Join-Path $sourceItem.DirectoryName ($sourceItem.BaseName + ".exe")

function Invoke-Program {
    param([string] $Path)

    Write-Host "Running: $Path"
    & $Path
    exit $LASTEXITCODE
}

function Start-ProgramInTerminal {
    param([string] $Path)

    Write-Host "Starting terminal: $Path"
    Start-Process -FilePath $env:ComSpec -WorkingDirectory $sourceItem.DirectoryName -ArgumentList @("/K", "`"$Path`"")
    exit 0
}

if ($Mode -eq "RunOnly") {
    if (-not (Test-Path -LiteralPath $outputPath)) {
        Stop-Build "Cannot find executable. Compile first: $outputPath"
    }

    Invoke-Program $outputPath
}

if ($Mode -eq "RunOnlyTerminal") {
    if (-not (Test-Path -LiteralPath $outputPath)) {
        Stop-Build "Cannot find executable. Compile first: $outputPath"
    }

    Start-ProgramInTerminal $outputPath
}

Write-Host "Compiling: $sourcePath"
& $compiler -std=c++17 -Wall -Wextra -O2 $sourcePath -o $outputPath

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Compiled: $outputPath"

if ($Mode -eq "Compile") {
    exit 0
}

if ($Mode -eq "Terminal") {
    Start-ProgramInTerminal $outputPath
}

Invoke-Program $outputPath
