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
