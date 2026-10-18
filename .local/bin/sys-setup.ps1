# Windows developer environment installer (winget-based). Mirrors sys-setup.sh.
# Works on Windows PowerShell 5.1 and PowerShell 7+.
param(
    [Parameter(Position = 0)][string]$Action,
    [Parameter(Position = 1)][string]$Component = 'all'
)
$ErrorActionPreference = 'Stop'

# Config Versions
$NET_SDK_V = '9'
$NET_RUN_V = '10'
$PG_V = '18'

function Write-Info([string]$Message) {
    Write-Host '[INFO] ' -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Err([string]$Message) {
    Write-Host '[ERROR] ' -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# --- HELPERS ---
# winget exit codes that mean "nothing to do" rather than failure:
# 0x8A15002B (no applicable upgrade) and 0x8A150061 (already installed).
$WingetOk = @(0, -1978335189, -1978335135)

# Re-reads Machine + User PATH from the registry so tools installed earlier in
# this run are callable, without dropping session-only entries (e.g. fnm env).
function Update-SessionPath {
    $current = $env:Path -split [IO.Path]::PathSeparator | Where-Object { $_ }
    $stored = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';' -split ';' | Where-Object { $_ -and ($current -notcontains $_) }
    $env:Path = (@($current) + @($stored)) -join [IO.Path]::PathSeparator
}

function Add-UserPath([string]$Dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ })
    if ($entries -notcontains $Dir) {
        Write-Info "Adding $Dir to the user PATH..."
        [Environment]::SetEnvironmentVariable('Path', (@($entries) + $Dir) -join ';', 'User')
    }
    Update-SessionPath
}

function Remove-UserPath([string]$Dir) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries = @($userPath -split ';' | Where-Object { $_ -and $_ -ne $Dir })
    [Environment]::SetEnvironmentVariable('Path', $entries -join ';', 'User')
}

function Install-WingetPackage([string]$Id, [string[]]$ExtraArgs = @()) {
    winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements --silent @ExtraArgs
    if ($WingetOk -notcontains $LASTEXITCODE) {
        throw "winget install $Id failed (exit code $LASTEXITCODE)."
    }
    Update-SessionPath
}

# Cleanup is best-effort, like the '|| true' cleanups in sys-setup.sh.
function Uninstall-WingetPackage([string]$Id) {
    winget uninstall --id $Id --exact --source winget --silent
}

# install fails when the tool is already present, so fall back to update.
function Install-DotnetTool([string]$Name, [string[]]$ExtraArgs = @()) {
    dotnet tool install -g $Name @ExtraArgs
    if ($LASTEXITCODE -ne 0) {
        dotnet tool update -g $Name @ExtraArgs
        if ($LASTEXITCODE -ne 0) { throw "dotnet tool install $Name failed." }
    }
}

# Both editions' all-hosts profiles, so the line loads in powershell.exe and pwsh.
function Get-ProfilePaths {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    @(
        (Join-Path $docs 'PowerShell\profile.ps1'),
        (Join-Path $docs 'WindowsPowerShell\profile.ps1')
    )
}

function Test-Interactive {
    [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

# --- SYSTEM UPDATE ---
function Update-System {
    Write-Info 'Upgrading all winget packages...'
    winget upgrade --all --accept-package-agreements --accept-source-agreements --silent
}

# --- BUILD ESSENTIALS ---
# gcc + make: nvim-treesitter compiles parsers and telescope-fzf-native runs `make`.
function Install-BuildEss {
    Write-Info 'Installing build essentials...'
    Install-WingetPackage Git.Git
    Install-WingetPackage BurntSushi.ripgrep.MSVC
    Install-WingetPackage ezwinports.make
    Install-WingetPackage BrechtSanders.WinLibs.POSIX.UCRT
}

function Clear-BuildEss {
    Write-Info 'Cleaning build essentials...'
    Uninstall-WingetPackage BrechtSanders.WinLibs.POSIX.UCRT
    Uninstall-WingetPackage ezwinports.make
    Uninstall-WingetPackage BurntSushi.ripgrep.MSVC
    Uninstall-WingetPackage Git.Git
}

# --- DOTNET ---
function Install-Dotnet {
    Write-Info 'Installing .NET SDK & Runtime...'
    Install-WingetPackage "Microsoft.DotNet.SDK.$NET_SDK_V"
    Install-WingetPackage "Microsoft.DotNet.Runtime.$NET_RUN_V"
    Install-WingetPackage "Microsoft.DotNet.AspNetCore.$NET_RUN_V"
    Add-UserPath (Join-Path $HOME '.dotnet\tools')

    # Global tools for easy-dotnet.nvim: its server and the Roslyn LSP it starts.
    Write-Info 'Installing EasyDotnet and Roslyn language server...'
    Install-DotnetTool EasyDotnet
    Install-DotnetTool roslyn-language-server @('--prerelease')

    # NuGet plugin that authenticates restores against Azure Artifacts feeds.
    Write-Info 'Installing Azure Artifacts Credential Provider...'
    Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-artifacts-credprovider.ps1) }"
}

function Clear-Dotnet {
    Write-Info 'Cleaning .NET SDK & Runtime...'
    dotnet tool uninstall -g EasyDotnet
    dotnet tool uninstall -g roslyn-language-server
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue `
        (Join-Path $HOME '.nuget\plugins\netcore\CredentialProvider.Microsoft'),
        (Join-Path $HOME '.nuget\plugins\netfx\CredentialProvider.Microsoft')
    Uninstall-WingetPackage "Microsoft.DotNet.AspNetCore.$NET_RUN_V"
    Uninstall-WingetPackage "Microsoft.DotNet.Runtime.$NET_RUN_V"
    Uninstall-WingetPackage "Microsoft.DotNet.SDK.$NET_SDK_V"
}

# --- GO ---
# Only needed so mason can build sqls (SQL LSP); the Go tooling itself is Linux-only.
function Install-Go {
    Write-Info 'Installing Go...'
    Install-WingetPackage GoLang.Go
}

function Clear-Go {
    Write-Info 'Cleaning Go...'
    Uninstall-WingetPackage GoLang.Go
}

# --- NODEJS ---
$FnmProfileLine = 'fnm env --use-on-cd --shell powershell | Out-String | Invoke-Expression'

function Install-Node {
    Write-Info 'Installing Node.js...'
    Install-WingetPackage Schniz.fnm
    foreach ($profilePath in Get-ProfilePaths) {
        if (-not (Test-Path $profilePath) -or -not (Select-String -Path $profilePath -SimpleMatch 'fnm env' -Quiet)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $profilePath) | Out-Null
            Add-Content -Path $profilePath -Value $FnmProfileLine
        }
    }
    fnm env --shell powershell | Out-String | Invoke-Expression
    fnm install --lts
    fnm use lts-latest
}

function Clear-Node {
    Write-Info 'Cleaning Node.js...'
    Uninstall-WingetPackage Schniz.fnm
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $env:APPDATA 'fnm')
    foreach ($profilePath in Get-ProfilePaths) {
        if (Test-Path $profilePath) {
            $kept = @(Get-Content $profilePath | Where-Object { $_ -notmatch 'fnm env' })
            Set-Content -Path $profilePath -Value $kept
        }
    }
}

# --- NEOVIM ---
# Nightly, to match the unstable PPA build used on Linux.
function Install-Nvim {
    Write-Info 'Installing Neovim (nightly)...'
    Install-WingetPackage Neovim.Neovim.Nightly
}

function Clear-Nvim {
    Write-Info 'Cleaning Neovim...'
    Uninstall-WingetPackage Neovim.Neovim.Nightly
}

# --- LAZYGIT ---
function Install-Lazygit {
    Write-Info 'Installing Lazygit...'
    Install-WingetPackage JesseDuffield.lazygit
}

function Clear-Lazygit {
    Write-Info 'Cleaning Lazygit...'
    Uninstall-WingetPackage JesseDuffield.lazygit
}

# --- DOCKER ---
function Install-Docker {
    Write-Info 'Installing Docker Desktop (requires WSL2)...'
    Install-WingetPackage Docker.DockerDesktop
}

function Clear-Docker {
    Write-Info 'Cleaning Docker Desktop...'
    Uninstall-WingetPackage Docker.DockerDesktop
}

# --- POSTGRESQL CLIENT (psql) ---
# The EDB installer has no client-only package; skip every component except the
# command line tools. It doesn't add bin to PATH, so do that here.
function Get-PgBin { Join-Path $env:ProgramFiles "PostgreSQL\$PG_V\bin" }

function Install-Psql {
    Write-Info 'Installing PostgreSQL client (psql)...'
    Install-WingetPackage "PostgreSQL.PostgreSQL.$PG_V" @('--override', '--mode unattended --unattendedmodeui none --disable-components server,pgAdmin,stackbuilder')
    Add-UserPath (Get-PgBin)
}

function Clear-Psql {
    Write-Info 'Cleaning PostgreSQL client...'
    Uninstall-WingetPackage "PostgreSQL.PostgreSQL.$PG_V"
    Remove-UserPath (Get-PgBin)
}

# --- MICROSOFT SQL SERVER CLI (go-sqlcmd) ---
function Install-Mssql {
    Write-Info 'Installing sqlcmd (go-sqlcmd)...'
    Install-WingetPackage Microsoft.Sqlcmd
}

function Clear-Mssql {
    Write-Info 'Cleaning sqlcmd...'
    Uninstall-WingetPackage Microsoft.Sqlcmd
}

# --- AZURE CLI ---
function Install-Az {
    Write-Info 'Installing Azure CLI...'
    Install-WingetPackage Microsoft.AzureCLI
}

function Clear-Az {
    Write-Info 'Cleaning Azure CLI...'
    Uninstall-WingetPackage Microsoft.AzureCLI
}

# --- TREESITTER ---
function Install-Treesitter {
    Write-Info 'Installing Tree-sitter CLI...'
    Install-WingetPackage tree-sitter.tree-sitter-cli
}

function Clear-Treesitter {
    Write-Info 'Cleaning Tree-sitter CLI...'
    Uninstall-WingetPackage tree-sitter.tree-sitter-cli
}

# --- ANTIGRAVITY ---
function Install-Antigravity {
    Write-Info 'Installing Antigravity CLI...'
    Invoke-RestMethod https://antigravity.google/cli/install.ps1 | Invoke-Expression
    Update-SessionPath
}

function Clear-Antigravity {
    Write-Info 'Cleaning Antigravity CLI...'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue `
        (Join-Path $env:LOCALAPPDATA 'agy'),
        (Join-Path $HOME '.gemini\antigravity-cli')
}

# --- GEMINI CLI ---
# Note: skill/plugin installs run through `agy` (Antigravity CLI), which is
# how Gemini CLI's plugin system is invoked now. Requires the 'antigravity'
# component installed first.
function Install-Gemini {
    Write-Info 'Installing Gemini CLI...'
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Err "npm not found. Install the 'node' component first."
        throw 'npm not found.'
    }
    npm install -g @google/gemini-cli

    if (-not (Get-Command agy -ErrorAction SilentlyContinue)) {
        Write-Err "agy not found. Install the 'antigravity' component first to get Gemini CLI's plugin/skill installs."
        return
    }

    Write-Info 'Installing caveman plugin for Gemini CLI (agy)...'
    agy plugin install https://github.com/JuliusBrussee/caveman
    if ($LASTEXITCODE -ne 0) { Write-Err 'Failed to install caveman plugin for Gemini CLI.' }

    Write-Info 'Installing superpowers plugin for Gemini CLI (agy)...'
    agy plugin install https://github.com/obra/superpowers
    if ($LASTEXITCODE -ne 0) { Write-Err 'Failed to install superpowers plugin for Gemini CLI.' }
}

function Clear-Gemini {
    Write-Info 'Cleaning Gemini CLI...'
    if (Get-Command agy -ErrorAction SilentlyContinue) {
        agy plugin uninstall caveman
        agy plugin uninstall superpowers
    }
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm uninstall -g @google/gemini-cli
    }
}

# --- CLAUDE CODE CLI ---
function Install-Claude {
    Write-Info 'Installing Claude Code CLI...'
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Add-UserPath (Join-Path $HOME '.local\bin')

    Write-Info 'Installing caveman plugin for Claude Code...'
    claude plugin marketplace add JuliusBrussee/caveman
    claude plugin install caveman@caveman

    Write-Info 'Installing superpowers plugin for Claude Code...'
    claude plugin install superpowers@claude-plugins-official
}

function Clear-Claude {
    Write-Info 'Cleaning Claude Code CLI...'
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        claude plugin uninstall superpowers@claude-plugins-official
        claude plugin uninstall caveman@caveman
        claude plugin marketplace remove JuliusBrussee/caveman
    }
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $HOME '.local\bin\claude.exe')
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $HOME '.local\share\claude')
}

# Prompts to pick which AI CLI(s) to install as part of a full run,
# rather than installing both unconditionally.
function Select-AiCli {
    if (-not (Test-Interactive)) {
        Write-Info "No interactive terminal detected. Skipping AI CLI selection (run 'sys-setup.ps1 install gemini' or 'install claude' manually)."
        return
    }

    Write-Host 'AI CLI tools:'
    Write-Host '  1) Gemini CLI'
    Write-Host '  2) Claude Code CLI'
    Write-Host '  3) Both'
    Write-Host '  4) Skip'
    switch (Read-Host 'Select option [1-4]') {
        '1' { Install-Gemini }
        '2' { Install-Claude }
        '3' { Install-Gemini; Install-Claude }
        default { Write-Info 'Skipping AI CLI installation.' }
    }
}

# --- COMPONENTS ---
# Name -> install/clean function pair. Order is the install order for 'all';
# 'all' cleans in reverse. ghostty (no Windows build) and rust (only needed for
# htmx-lsp, which is Linux-only) are deliberately absent.
$Components = [ordered]@{
    'build-ess'   = @('Install-BuildEss', 'Clear-BuildEss')
    'dotnet'      = @('Install-Dotnet', 'Clear-Dotnet')
    'node'        = @('Install-Node', 'Clear-Node')
    'go'          = @('Install-Go', 'Clear-Go')
    'nvim'        = @('Install-Nvim', 'Clear-Nvim')
    'lazygit'     = @('Install-Lazygit', 'Clear-Lazygit')
    'docker'      = @('Install-Docker', 'Clear-Docker')
    'psql'        = @('Install-Psql', 'Clear-Psql')
    'mssql'       = @('Install-Mssql', 'Clear-Mssql')
    'az'          = @('Install-Az', 'Clear-Az')
    'antigravity' = @('Install-Antigravity', 'Clear-Antigravity')
    'treesitter'  = @('Install-Treesitter', 'Clear-Treesitter')
    'gemini'      = @('Install-Gemini', 'Clear-Gemini')
    'claude'      = @('Install-Claude', 'Clear-Claude')
}

# --- BULK COMMANDS ---
function Install-All {
    Write-Info 'Starting full installation...'
    Update-System
    foreach ($name in $Components.Keys) {
        if ($name -in @('gemini', 'claude')) { continue }
        & $Components[$name][0]
    }
    Select-AiCli
    Write-Info 'Full installation completed!'
}

function Clear-All {
    Write-Info 'Starting full cleanup...'
    $names = @($Components.Keys)
    [array]::Reverse($names)
    foreach ($name in $names) {
        & $Components[$name][1]
    }
    Write-Info 'Full cleanup completed!'
}

function Show-Help {
    Write-Host 'Usage: sys-setup.ps1 <action> [component]'
    Write-Host ''
    Write-Host 'Actions:'
    Write-Host '  install [component]  Install everything or a specific component'
    Write-Host '  clean [component]    Uninstall everything or a specific component'
    Write-Host '  update               Upgrade all winget packages'
    Write-Host ''
    Write-Host 'Components:'
    Write-Host "  $($Components.Keys -join ', ')"
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

# Map compatibility targets (e.g. node-i to install node, node-c to clean node)
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
} elseif ($Components.Contains($Component)) {
    $index = if ($Action -eq 'install') { 0 } else { 1 }
    & $Components[$Component][$index]
} else {
    Write-Err "Unknown component: $Component"
    Show-Help
    exit 1
}

exit 0
