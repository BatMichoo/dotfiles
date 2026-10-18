# Windows repository setup. The Linux dotfiles don't apply on Windows, so
# instead of checking out the bare repo this clones the Neovim config (the
# .config/nvim submodule) to where Windows Neovim reads it: %LOCALAPPDATA%\nvim.
$ErrorActionPreference = 'Stop'

$NvimRemote = 'git@github.com:BatMichoo/nvim-config.git'
$NvimDir = Join-Path $env:LOCALAPPDATA 'nvim'
$BackupDirBase = Join-Path $HOME '.dotfiles-backup'

function Write-Info([string]$Message) {
    Write-Host '[INFO] ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Update-SessionPath {
    $current = $env:Path -split [IO.Path]::PathSeparator | Where-Object { $_ }
    $stored = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';' -split ';' | Where-Object { $_ -and ($current -notcontains $_) }
    $env:Path = (@($current) + @($stored)) -join [IO.Path]::PathSeparator
}

# Git doesn't ship with Windows, so bootstrap it before anything else
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Info 'Installing Git...'
    winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements --silent
    Update-SessionPath
}

# Git for Windows bundles its own ssh, which can't see keys held by the
# Windows ssh-agent service that github-ssh-setup.ps1 loads them into.
$WindowsSsh = (Join-Path $env:SystemRoot 'System32\OpenSSH\ssh.exe') -replace '\\', '/'
Write-Info 'Pointing Git at the Windows OpenSSH client...'
git config --global core.sshCommand $WindowsSsh

Write-Info 'Setting up Neovim config...'
if (Test-Path (Join-Path $NvimDir '.git')) {
    Write-Info "Neovim config already cloned at $NvimDir."
} else {
    if (Test-Path $NvimDir) {
        $Backup = Join-Path $BackupDirBase (Get-Date -Format 'yyyyMMdd_HHmmss')
        Write-Info "Existing non-git $NvimDir found. Backing it up to $Backup..."
        New-Item -ItemType Directory -Force -Path $Backup | Out-Null
        Move-Item $NvimDir (Join-Path $Backup 'nvim')
    }
    Write-Info "Cloning Neovim config into $NvimDir..."
    git clone $NvimRemote $NvimDir
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
}

# Environment fallbacks & overrides
if (-not [Environment]::GetEnvironmentVariable('EDITOR', 'User')) {
    Write-Info 'Setting nvim as the default EDITOR/VISUAL...'
    [Environment]::SetEnvironmentVariable('EDITOR', 'nvim', 'User')
    [Environment]::SetEnvironmentVariable('VISUAL', 'nvim', 'User')
}

# Windows client default is Restricted, which blocks the helper scripts in
# ~/.local/bin and the PowerShell profile (fnm env) from running.
if ($env:OS -eq 'Windows_NT') {
    $Policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($Policy -eq 'Undefined' -or $Policy -eq 'Restricted') {
        Write-Info 'Setting the CurrentUser execution policy to RemoteSigned...'
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    }
}

exit 0
