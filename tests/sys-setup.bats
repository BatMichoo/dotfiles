#!/usr/bin/env bats

load 'helpers/stubs'

setup() {
    setup_stubs
    stub_all_common
    SCRIPT="$BATS_TEST_DIRNAME/../.local/bin/sys-setup.sh"
    mkdir -p "$BATS_TEST_TMPDIR/home"
}

@test "build-ess: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install build-ess
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm base-devel git curl ripgrep unzip xclip" "$STUB_LOG"
}

@test "build-ess: debian uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install build-ess
    [ "$status" -eq 0 ]
    grep -q "apt-get install -y build-essential git curl ripgrep unzip xclip" "$STUB_LOG"
}

@test "ghostty: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install ghostty
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm ghostty" "$STUB_LOG"
}

@test "ghostty: debian uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install ghostty
    [ "$status" -eq 0 ]
    grep -q "apt-get install -y ghostty" "$STUB_LOG"
}

@test "dotnet: arch uses pacman with version suffixes" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install dotnet
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm dotnet-runtime-10.0 dotnet-sdk-9.0 aspnet-runtime-10.0" "$STUB_LOG"
}

@test "dotnet: debian adds PPA and uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install dotnet
    [ "$status" -eq 0 ]
    grep -q "add-apt-repository ppa:dotnet/backports -y" "$STUB_LOG"
    grep -q "apt-get install -y dotnet-runtime-10.0 dotnet-sdk-9.0 aspnet-runtime-10.0" "$STUB_LOG"
}

@test "dotnet: installs EasyDotnet and roslyn-language-server as global tools" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install dotnet
    [ "$status" -eq 0 ]
    grep -q "^dotnet tool install -g EasyDotnet$" "$STUB_LOG"
    grep -q "^dotnet tool install -g roslyn-language-server --prerelease$" "$STUB_LOG"
}

@test "dotnet: updates the global tools when they are already installed" {
    cat > "$STUB_BIN/dotnet" <<'EOF'
#!/usr/bin/env bash
echo "dotnet $*" >> "$STUB_LOG"
[ "$2" != "install" ]
EOF
    chmod +x "$STUB_BIN/dotnet"
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install dotnet
    [ "$status" -eq 0 ]
    grep -q "^dotnet tool update -g EasyDotnet$" "$STUB_LOG"
    grep -q "^dotnet tool update -g roslyn-language-server --prerelease$" "$STUB_LOG"
}

@test "dotnet: clean uninstalls the global tools" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" clean dotnet
    [ "$status" -eq 0 ]
    grep -q "^dotnet tool uninstall -g EasyDotnet$" "$STUB_LOG"
    grep -q "^dotnet tool uninstall -g roslyn-language-server$" "$STUB_LOG"
}

@test "go: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install go
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm go" "$STUB_LOG"
}

@test "go: debian adds PPA and uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install go
    [ "$status" -eq 0 ]
    grep -q "add-apt-repository ppa:longsleep/golang-backports -y" "$STUB_LOG"
    grep -q "apt-get install -y golang-go" "$STUB_LOG"
}

@test "treesitter: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install treesitter
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm tree-sitter-cli" "$STUB_LOG"
}

@test "treesitter: debian uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install treesitter
    [ "$status" -eq 0 ]
    grep -q "apt-get install -y tree-sitter-cli" "$STUB_LOG"
}

@test "node: arch installs fnm via pacman" {
    DOTFILES_TEST_OS=arch HOME="$BATS_TEST_TMPDIR/home" run bash "$SCRIPT" install node
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm fnm" "$STUB_LOG"
    grep -q "fnm install --lts" "$STUB_LOG"
}

@test "docker: arch installs docker + docker-compose via pacman and enables the service" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install docker
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm docker docker-compose" "$STUB_LOG"
    grep -q "systemctl enable --now docker.service" "$STUB_LOG"
}

@test "docker: debian installs docker.io + compose plugin via apt-get and enables the service" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install docker
    [ "$status" -eq 0 ]
    grep -q "apt-get install -y docker.io docker-compose-v2" "$STUB_LOG"
    grep -q "systemctl enable --now docker.service" "$STUB_LOG"
}

@test "psql: arch installs the postgresql package" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install psql
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm postgresql" "$STUB_LOG"
}

@test "psql: debian installs the client-only postgresql-client package" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install psql
    [ "$status" -eq 0 ]
    grep -q "apt-get install -y postgresql-client" "$STUB_LOG"
}

@test "mssql: arch installs go-sqlcmd via paru (AUR)" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install mssql
    [ "$status" -eq 0 ]
    grep -q "paru -S --noconfirm go-sqlcmd" "$STUB_LOG"
}

@test "mssql: debian installs the go-sqlcmd release binary, without the Microsoft repo" {
    DOTFILES_TEST_OS=debian HOME="$BATS_TEST_TMPDIR/home" run bash "$SCRIPT" install mssql
    [ "$status" -eq 0 ]
    grep -q "curl -Lo sqlcmd.tar.bz2 https://github.com/microsoft/go-sqlcmd/releases/latest/download/sqlcmd-linux-amd64.tar.bz2" "$STUB_LOG"
    grep -q "sudo install sqlcmd /usr/local/bin/sqlcmd" "$STUB_LOG"
    ! grep -q "packages.microsoft.com" "$STUB_LOG"
    ! grep -q "mssql-tools18" "$STUB_LOG"
}

@test "mssql: debian clean removes go-sqlcmd and the legacy mssql-tools18 setup" {
    mkdir -p "$BATS_TEST_TMPDIR/home"
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' > "$BATS_TEST_TMPDIR/home/.bashrc"
    DOTFILES_TEST_OS=debian HOME="$BATS_TEST_TMPDIR/home" run bash "$SCRIPT" clean mssql
    [ "$status" -eq 0 ]
    grep -q "sudo rm -f /usr/local/bin/sqlcmd" "$STUB_LOG"
    grep -q "apt-get purge -y mssql-tools18 unixodbc-dev" "$STUB_LOG"
    ! grep -q "mssql-tools18/bin" "$BATS_TEST_TMPDIR/home/.bashrc"
}

@test "rust: no OS branch, always uses rustup installer via curl" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install rust
    [ "$status" -eq 0 ]
    grep -q "curl.*sh.rustup.rs" "$STUB_LOG"
}

@test "gemini: installs npm package and, when agy is missing, skips plugin install with an error instead of crashing" {
    # setup()'s stub_all_common already wrote an agy stub into $STUB_BIN;
    # remove it so `command -v agy` correctly fails for this one test.
    rm -f "$STUB_BIN/agy"
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install gemini
    [ "$status" -eq 0 ]
    grep -q "npm install -g @google/gemini-cli" "$STUB_LOG"
    [[ "$output" == *"agy not found"* ]]
}

@test "gemini: installs caveman and superpowers plugins via agy when present" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install gemini
    [ "$status" -eq 0 ]
    grep -q "agy plugin install https://github.com/JuliusBrussee/caveman" "$STUB_LOG"
    grep -q "agy plugin install https://github.com/obra/superpowers" "$STUB_LOG"
}

@test "claude: installs via native installer and both plugins" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install claude
    [ "$status" -eq 0 ]
    grep -q "curl -fsSL https://claude.ai/install.sh" "$STUB_LOG"
    grep -q "claude plugin marketplace add JuliusBrussee/caveman" "$STUB_LOG"
    grep -q "claude plugin install caveman@caveman" "$STUB_LOG"
    grep -q "claude plugin install superpowers@claude-plugins-official" "$STUB_LOG"
}

@test "ai_cli_select: no tty skips both AI CLIs instead of hanging" {
    DOTFILES_TEST_OS=arch HOME="$BATS_TEST_TMPDIR/home" run bash "$SCRIPT" install all < /dev/null
    [ "$status" -eq 0 ]
    ! grep -q "npm install -g @google/gemini-cli" "$STUB_LOG"
    ! grep -q "claude.ai/install.sh" "$STUB_LOG"
}

@test "unknown component fails with usage" {
    run bash "$SCRIPT" install not-a-real-thing
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown component"* ]]
}

@test "legacy <component>-i target maps to install" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" go-i
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm go" "$STUB_LOG"
}
