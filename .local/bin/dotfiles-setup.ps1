# Main Windows Setup & Orchestration Entry Script. Mirrors dotfiles-setup.sh.
# Works on Windows PowerShell 5.1 and PowerShell 7+.
param(
    [Alias('b')][switch]$Bootstrap,
    [Alias('s')][switch]$Sys,
    [Alias('a')][switch]$Apps,
    [switch]$All,
    [switch]$SkipSys,
    [Alias('u')][switch]$Update,
    [Alias('h')][switch]$Help
)
$ErrorActionPreference = 'Stop'

# Helper Logging
function Write-Info([string]$Message) {
    Write-Host '[INFO] ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Err([string]$Message) {
    Write-Host '[ERROR] ' -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# 1. OS Detection (DOTFILES_TEST_OS overrides for testing)
if (-not $env:DOTFILES_TEST_OS -and $env:OS -ne 'Windows_NT') {
    Write-Err 'This script is for Windows. Use dotfiles-setup.sh on Linux.'
    exit 1
}

function Show-Help {
    Write-Host 'Usage: dotfiles-setup.ps1 [options]'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '  -b, -Bootstrap    Run SSH setup and Neovim config setup'
    Write-Host '  -s, -Sys          Run system programming packages installation'
    Write-Host '  -a, -Apps         Run general applications installation'
    Write-Host '  -All              Run all setup steps in order'
    Write-Host '  -SkipSys          Run Bootstrap and Apps setups (skip system packages)'
    Write-Host '  -u, -Update       Re-download the helper scripts already in ~/.local/bin'
    Write-Host '  -h, -Help         Show this help message'
}

if ($Help) {
    Show-Help
    exit 0
}

$RunBootstrap = $Bootstrap -or $All -or $SkipSys
$RunSys = $Sys -or $All
$RunApps = $Apps -or $All -or $SkipSys
$RunUpdate = [bool]$Update

# If no flags are set, run the interactive menu
if (-not ($RunBootstrap -or $RunSys -or $RunApps -or $RunUpdate)) {
    Write-Host '==========================================='
    Write-Host '    Unified Dotfiles Bootstrap Setup'
    Write-Host '==========================================='
    Write-Host '1) Full Setup (Bootstrap, System, Apps)'
    Write-Host '2) Bootstrap & Apps Setup (Skip System/Programming packages)'
    Write-Host '3) Run Bootstrap Only (SSH Setup & Neovim Config Setup)'
    Write-Host '4) Install System Packages Only (sys-setup.ps1)'
    Write-Host '5) Install General Apps Only (apps-setup.ps1)'
    Write-Host '6) Update Helper Scripts (fetch latest from GitHub)'
    Write-Host '7) Exit'
    Write-Host '==========================================='
    switch (Read-Host 'Select option [1-7]') {
        '1' { $RunBootstrap = $true; $RunSys = $true; $RunApps = $true }
        '2' { $RunBootstrap = $true; $RunApps = $true }
        '3' { $RunBootstrap = $true }
        '4' { $RunSys = $true }
        '5' { $RunApps = $true }
        '6' { $RunUpdate = $true }
        default {
            Write-Host 'Exiting...'
            exit 0
        }
    }
}

# Define target paths
$ScriptsDir = [IO.Path]::Combine($HOME, '.local', 'bin')
# DOTFILES_SCRIPTS_URL overrides for testing
$ScriptsUrl = if ($env:DOTFILES_SCRIPTS_URL) { $env:DOTFILES_SCRIPTS_URL } else { 'https://raw.githubusercontent.com/BatMichoo/dotfiles/main/.local/bin' }
$HelperScripts = @('dotfiles-setup.ps1', 'github-ssh-setup.ps1', 'repo-setup.ps1', 'sys-setup.ps1', 'apps-setup.ps1')

# Downloads a helper script into ~/.local/bin. Writes to a temp file and moves
# it into place, so a failed download never leaves a truncated script behind.
function Save-HelperScript([string]$Name) {
    $path = Join-Path $ScriptsDir $Name
    $tmp = "$path.download"

    Write-Info "Downloading $Name..."
    New-Item -ItemType Directory -Force -Path $ScriptsDir | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri "$ScriptsUrl/$Name" -OutFile $tmp
    Move-Item -Force $tmp $path
}

# Runs a helper script from ~/.local/bin, downloading it first only when it
# isn't on disk yet (e.g. a single step picked before bootstrap).
function Invoke-HelperScript([string]$Name, [string[]]$ScriptArgs = @()) {
    $path = Join-Path $ScriptsDir $Name
    if (-not (Test-Path $path)) {
        Save-HelperScript $Name
    }
    # Every helper ends with an explicit exit code, so this mirrors `set -e`.
    & $path @ScriptArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err "$Name failed (exit code $LASTEXITCODE)."
        exit $LASTEXITCODE
    }
}

# Refresh only the helper scripts already on disk; missing ones are still
# fetched on demand when their step runs
if ($RunUpdate) {
    foreach ($name in $HelperScripts) {
        if (Test-Path (Join-Path $ScriptsDir $name)) {
            Save-HelperScript $name
        }
    }
}

# Execute components in dependency order: Bootstrap -> Sys -> Apps
if ($RunBootstrap) {
    Invoke-HelperScript github-ssh-setup.ps1
    Invoke-HelperScript repo-setup.ps1
}

if ($RunSys) {
    Invoke-HelperScript sys-setup.ps1 @('install')
}

if ($RunApps) {
    Invoke-HelperScript apps-setup.ps1 @('install')
}

Write-Host ''
Write-Host '==========================================='
Write-Host '    Setup Action(s) Complete!'
Write-Host '==========================================='
