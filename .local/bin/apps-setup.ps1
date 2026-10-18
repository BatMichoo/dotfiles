# Windows general applications installer (winget-based). Mirrors apps-setup.sh.
# Works on Windows PowerShell 5.1 and PowerShell 7+.
param(
    [Parameter(Position = 0)][string]$Action,
    [Parameter(Position = 1)][string]$Component = 'all'
)
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host '[INFO] ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Err([string]$Message) {
    Write-Host '[ERROR] ' -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# winget exit codes that mean "nothing to do" rather than failure:
# 0x8A15002B (no applicable upgrade) and 0x8A150061 (already installed).
$WingetOk = @(0, -1978335189, -1978335135)

function Install-WingetPackage([string]$Id) {
    winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements --silent
    if ($WingetOk -notcontains $LASTEXITCODE) {
        throw "winget install $Id failed (exit code $LASTEXITCODE)."
    }
}

# Cleanup is best-effort, like the '|| true' cleanups in apps-setup.sh.
function Uninstall-WingetPackage([string]$Id) {
    winget uninstall --id $Id --exact --source winget --silent
}

function Test-Interactive {
    [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

# --- SYSTEM UPDATE ---
function Update-System {
    Write-Info 'Upgrading all winget packages...'
    winget upgrade --all --accept-package-agreements --accept-source-agreements --silent
}

# Name -> winget ID
$Apps = [ordered]@{
    'discord' = 'Discord.Discord'
    'steam'   = 'Valve.Steam'
    'chrome'  = 'Google.Chrome'
    'firefox' = 'Mozilla.Firefox'
    'brave'   = 'Brave.Brave'
}

function Install-App([string]$Name) {
    Write-Info "Installing $Name..."
    Install-WingetPackage $Apps[$Name]
}

function Clear-App([string]$Name) {
    Write-Info "Cleaning $Name..."
    Uninstall-WingetPackage $Apps[$Name]
}

# Prompts to pick which browser(s) to install as part of a full run,
# rather than installing Chrome unconditionally.
function Select-Browser {
    if (-not (Test-Interactive)) {
        Write-Info "No interactive terminal detected. Skipping browser selection (run 'apps-setup.ps1 install chrome|firefox|brave' manually)."
        return
    }

    Write-Host 'Browsers:'
    Write-Host '  1) Google Chrome'
    Write-Host '  2) Firefox'
    Write-Host '  3) Brave'
    Write-Host '  4) All of the above'
    Write-Host '  5) Skip'
    switch (Read-Host 'Select option [1-5]') {
        '1' { Install-App chrome }
        '2' { Install-App firefox }
        '3' { Install-App brave }
        '4' { Install-App chrome; Install-App firefox; Install-App brave }
        default { Write-Info 'Skipping browser installation.' }
    }
}

# --- BULK COMMANDS ---
function Install-All {
    Write-Info 'Starting apps installation...'
    Update-System
    Install-App discord
    Install-App steam
    Select-Browser
    Write-Info 'Apps installation completed!'
}

function Clear-All {
    Write-Info 'Starting apps cleanup...'
    foreach ($name in @('brave', 'firefox', 'chrome', 'steam', 'discord')) {
        Clear-App $name
    }
    Write-Info 'Apps cleanup completed!'
}

function Show-Help {
    Write-Host 'Usage: apps-setup.ps1 <action> [component]'
    Write-Host ''
    Write-Host 'Actions:'
    Write-Host '  install [component]  Install all apps or a specific app'
    Write-Host '  clean [component]    Uninstall all apps or a specific app'
    Write-Host '  update               Upgrade all winget packages'
    Write-Host ''
    Write-Host 'Components:'
    Write-Host "  $($Apps.Keys -join ', ')"
    Write-Host ''
    Write-Host 'Legacy Target Support:'
    Write-Host "  <component>-i        Same as 'install <component>'"
    Write-Host "  <component>-c        Same as 'clean <component>'"
}

# --- ARGUMENT ROUTING ---
if (-not $Action) {
    Show-Help
    exit 1
}

if (-not $env:DOTFILES_TEST_OS -and -not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err 'winget not found. Install "App Installer" from the Microsoft Store first.'
    exit 1
}

if ($Action -match '^(.*)-(i|c)$') {
    $Component = $Matches[1]
    $Action = if ($Matches[2] -eq 'i') { 'install' } else { 'clean' }
}

if ($Action -eq 'update') {
    Update-System
    exit 0
}

if ($Action -ne 'install' -and $Action -ne 'clean') {
    Show-Help
    exit 1
}

if ($Component -eq 'all') {
    if ($Action -eq 'install') { Install-All } else { Clear-All }
} elseif ($Apps.Contains($Component)) {
    if ($Action -eq 'install') { Install-App $Component } else { Clear-App $Component }
} else {
    Write-Err "Unknown component: $Component"
    Show-Help
    exit 1
}

exit 0
