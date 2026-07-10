# pbin installer for Windows. Downloads the standalone binary from the public
# GitHub release. No auth required.
#
#   irm https://github.com/<owner>/<repo>/releases/latest/download/install.ps1 | iex
#
# Env overrides: PBIN_REPO, PBIN_VERSION, PBIN_BIN_DIR

$ErrorActionPreference = 'Stop'

# @@REPO@@ is replaced with the real owner/repo by release.sh at publish time.
$Repo    = if ($env:PBIN_REPO)    { $env:PBIN_REPO }    else { '@@REPO@@' }
$Version = if ($env:PBIN_VERSION) { $env:PBIN_VERSION } else { 'latest' }
$BinDir  = if ($env:PBIN_BIN_DIR) { $env:PBIN_BIN_DIR } else { "$env:LOCALAPPDATA\Programs\pbin" }
$Asset   = 'pbin-windows-x86_64.exe'

if ($Repo -like '*@@*') { throw "PBIN_REPO is not set (should be baked in by release.sh)." }

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
$Dest = Join-Path $BinDir 'pbin.exe'

if ($Version -eq 'latest') {
    $Url = "https://github.com/$Repo/releases/latest/download/$Asset"
} else {
    $Url = "https://github.com/$Repo/releases/download/$Version/$Asset"
}

Write-Host "Downloading $Asset ($Version)..."
Invoke-WebRequest -Uri $Url -OutFile $Dest

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
    Write-Host "Added $BinDir to your PATH (restart the terminal to pick it up)."
}
Write-Host "`nNext: run 'pbin init' once, then 'pbin create'."
