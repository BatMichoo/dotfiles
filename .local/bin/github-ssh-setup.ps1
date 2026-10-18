# Windows GitHub SSH key setup. Mirrors github-ssh-setup.sh, using the
# built-in Windows OpenSSH client and its ssh-agent service.
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) {
    Write-Host '[INFO] ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Err([string]$Message) {
    Write-Host '[ERROR] ' -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# 1. Key Check & Generation
$SshDir = Join-Path $HOME '.ssh'
$KeyPath = Join-Path $SshDir 'id_ed25519'

if (Test-Path $KeyPath) {
    Write-Info "Existing SSH key found at $KeyPath. Skipping generation."
} else {
    Write-Host '=============================='
    Write-Host '   GitHub SSH Key Generator'
    Write-Host '=============================='
    Write-Host ''

    $Email = Read-Host 'Enter your GitHub email address'
    New-Item -ItemType Directory -Force -Path $SshDir | Out-Null

    # ssh-keygen prompts for the passphrase itself: Windows PowerShell 5.1
    # drops empty-string arguments, so `-N ""` can't be passed reliably.
    Write-Info 'Generating new Ed25519 SSH key...'
    ssh-keygen -t ed25519 -C $Email -f $KeyPath
    if ($LASTEXITCODE -ne 0) { throw 'ssh-keygen failed.' }
}

# 2. ssh-agent service: disabled by default on Windows, and enabling it needs admin
$Agent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if (-not $Agent) {
    Write-Err 'ssh-agent service not found. Enable the "OpenSSH Client" optional feature first.'
    exit 1
}
if ($Agent.StartType -ne 'Automatic' -or $Agent.Status -ne 'Running') {
    Write-Info 'Enabling the ssh-agent service (requires an admin prompt)...'
    Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile', '-Command', 'Set-Service ssh-agent -StartupType Automatic; Start-Service ssh-agent'
}

# 3. Add key to the agent (the service persists it across reboots)
$KeyFp = (ssh-keygen -lf $KeyPath) -split ' ' | Select-Object -Index 1
$Loaded = (ssh-add -l 2>$null) -join "`n"
if ($Loaded -like "*$KeyFp*") {
    Write-Info 'SSH key is already loaded in ssh-agent. Skipping key printing.'
    exit 0
}

Write-Info 'Adding key to ssh-agent...'
ssh-add $KeyPath

# 4. Instructions & Output
Write-Host ''
Write-Host '=================================================='
Write-Host '                  SUCCESS!'
Write-Host '=================================================='
Write-Host 'SSH configuration verified.'
Write-Host 'Here is your public key. Copy the box below:'
Write-Host '--------------------------------------------------'
Get-Content "$KeyPath.pub"
Write-Host '--------------------------------------------------'
Write-Host ''
Write-Host "Please add it to your GitHub account if you haven't already:"
Write-Host 'https://github.com/settings/keys'
Write-Host '=================================================='

exit 0
