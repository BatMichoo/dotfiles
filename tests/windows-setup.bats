#!/usr/bin/env bats

# Exercises the Windows PowerShell scripts under pwsh on Linux. winget, dotnet,
# etc. are the same PATH stubs the bash suites use; components that pipe a
# remote installer into Invoke-Expression (dotnet's credential provider,
# antigravity, claude) aren't run here, since that would execute live scripts.

load 'helpers/stubs'

setup() {
    PWSH="${PWSH:-$(command -v pwsh || true)}"
    [ -n "$PWSH" ] || skip "pwsh not installed"

    setup_stubs
    stub_all_common
    stub winget
    BIN_DIR="$BATS_TEST_DIRNAME/../.local/bin"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    SCRIPTS="$FAKE_HOME/.local/bin"
    mkdir -p "$SCRIPTS"
    HOME="$FAKE_HOME"
    DOTFILES_TEST_OS=windows
    # Windows-only env vars the scripts build paths from
    ProgramFiles="$BATS_TEST_TMPDIR/ProgramFiles"
    LOCALAPPDATA="$FAKE_HOME/AppData/Local"
    APPDATA="$FAKE_HOME/AppData/Roaming"
    export HOME DOTFILES_TEST_OS ProgramFiles LOCALAPPDATA APPDATA
}

ps() {
    run "$PWSH" -NoProfile -NonInteractive -File "$@" < /dev/null
}

# Fake stand-ins for every helper dotfiles-setup.ps1 may invoke, so these tests
# cover only its own flag-to-script dispatch logic.
fake_helpers() {
    for name in github-ssh-setup.ps1 repo-setup.ps1 sys-setup.ps1 apps-setup.ps1; do
        cat > "$SCRIPTS/$name" <<EOF
Add-Content -Path '$STUB_LOG' -Value "ran:$name \$args"
exit 0
EOF
    done
}

# --- dotfiles-setup.ps1 ---

@test "ps1: refuses to run outside Windows without the test override" {
    DOTFILES_TEST_OS= ps "$BIN_DIR/dotfiles-setup.ps1" -Sys
    [ "$status" -eq 1 ]
    [[ "$output" == *"This script is for Windows"* ]]
}

@test "ps1: -h shows help and exits 0" {
    ps "$BIN_DIR/dotfiles-setup.ps1" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "ps1: -s runs only sys-setup.ps1 with the install action" {
    fake_helpers
    ps "$BIN_DIR/dotfiles-setup.ps1" -s
    [ "$status" -eq 0 ]
    grep -q "ran:sys-setup.ps1 install" "$STUB_LOG"
    ! grep -q "ran:apps-setup.ps1" "$STUB_LOG"
    ! grep -q "ran:repo-setup.ps1" "$STUB_LOG"
}

@test "ps1: -All runs bootstrap, sys, and apps in order" {
    fake_helpers
    ps "$BIN_DIR/dotfiles-setup.ps1" -All
    [ "$status" -eq 0 ]
    [ "$(cut -d' ' -f1 "$STUB_LOG" | tr '\n' ' ')" = "ran:github-ssh-setup.ps1 ran:repo-setup.ps1 ran:sys-setup.ps1 ran:apps-setup.ps1 " ]
}

@test "ps1: -SkipSys runs bootstrap and apps but not sys" {
    fake_helpers
    ps "$BIN_DIR/dotfiles-setup.ps1" -SkipSys
    [ "$status" -eq 0 ]
    grep -q "ran:repo-setup.ps1" "$STUB_LOG"
    grep -q "ran:apps-setup.ps1 install" "$STUB_LOG"
    ! grep -q "ran:sys-setup.ps1" "$STUB_LOG"
}

@test "ps1: a failing helper stops the run with its exit code" {
    fake_helpers
    echo 'exit 3' > "$SCRIPTS/sys-setup.ps1"
    ps "$BIN_DIR/dotfiles-setup.ps1" -All
    [ "$status" -eq 3 ]
    ! grep -q "ran:apps-setup.ps1" "$STUB_LOG"
}

# Serves a directory over HTTP for the download tests; echoes its base URL.
serve_dir() {
    local dir="$1"
    local port_file="$BATS_TEST_TMPDIR/port"
    python3 -I -c '
import http.server, sys, functools
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=sys.argv[1])
srv = http.server.HTTPServer(("127.0.0.1", 0), handler)
open(sys.argv[2], "w").write(str(srv.server_port))
srv.serve_forever()
' "$dir" "$port_file" >/dev/null 2>&1 3>&- &
    SERVER_PID=$!
    for _ in $(seq 50); do [ -s "$port_file" ] && break; sleep 0.1; done
    echo "http://127.0.0.1:$(cat "$port_file")"
}

teardown() {
    [ -z "${SERVER_PID:-}" ] || kill "$SERVER_PID" 2>/dev/null || true
}

@test "ps1: downloads a missing helper into ~/.local/bin, then runs it" {
    REMOTE="$BATS_TEST_TMPDIR/remote"
    mkdir -p "$REMOTE"
    echo "Add-Content -Path '$STUB_LOG' -Value 'ran:remote-apps'; exit 0" > "$REMOTE/apps-setup.ps1"
    DOTFILES_SCRIPTS_URL="$(serve_dir "$REMOTE")" ps "$BIN_DIR/dotfiles-setup.ps1" -a
    [ "$status" -eq 0 ]
    grep -q "ran:remote-apps" "$STUB_LOG"
    [ -f "$SCRIPTS/apps-setup.ps1" ]
}

@test "ps1: -u re-downloads only the helpers already on disk and runs nothing else" {
    fake_helpers
    rm "$SCRIPTS/apps-setup.ps1"
    REMOTE="$BATS_TEST_TMPDIR/remote"
    mkdir -p "$REMOTE"
    for name in dotfiles-setup.ps1 github-ssh-setup.ps1 repo-setup.ps1 sys-setup.ps1 apps-setup.ps1; do
        echo "# updated $name" > "$REMOTE/$name"
    done
    DOTFILES_SCRIPTS_URL="$(serve_dir "$REMOTE")" ps "$BIN_DIR/dotfiles-setup.ps1" -u
    [ "$status" -eq 0 ]
    grep -q "# updated sys-setup.ps1" "$SCRIPTS/sys-setup.ps1"
    grep -q "# updated repo-setup.ps1" "$SCRIPTS/repo-setup.ps1"
    [ ! -e "$SCRIPTS/apps-setup.ps1" ]
    ! grep -q "^ran:" "$STUB_LOG"
}

# --- sys-setup.ps1 ---

@test "sys.ps1: nvim installs the nightly build via winget" {
    ps "$BIN_DIR/sys-setup.ps1" install nvim
    [ "$status" -eq 0 ]
    grep -q "winget install --id Neovim.Neovim.Nightly --exact --source winget" "$STUB_LOG"
}

@test "sys.ps1: psql installs only the EDB command line tools" {
    ps "$BIN_DIR/sys-setup.ps1" install psql
    [ "$status" -eq 0 ]
    grep -q "winget install --id PostgreSQL.PostgreSQL.18 .* --override --mode unattended --unattendedmodeui none --disable-components server,pgAdmin,stackbuilder" "$STUB_LOG"
}

@test "sys.ps1: mssql installs go-sqlcmd, az installs the Azure CLI" {
    ps "$BIN_DIR/sys-setup.ps1" install mssql
    [ "$status" -eq 0 ]
    ps "$BIN_DIR/sys-setup.ps1" install az
    [ "$status" -eq 0 ]
    grep -q "winget install --id Microsoft.Sqlcmd " "$STUB_LOG"
    grep -q "winget install --id Microsoft.AzureCLI " "$STUB_LOG"
}

@test "sys.ps1: a failing winget install fails the script" {
    stub winget 1
    ps "$BIN_DIR/sys-setup.ps1" install lazygit
    [ "$status" -ne 0 ]
    [[ "$output" == *"winget install JesseDuffield.lazygit failed"* ]]
}

@test "sys.ps1: clean dotnet removes the global tools and the SDK packages" {
    ps "$BIN_DIR/sys-setup.ps1" clean dotnet
    [ "$status" -eq 0 ]
    grep -q "^dotnet tool uninstall -g EasyDotnet$" "$STUB_LOG"
    grep -q "^dotnet tool uninstall -g roslyn-language-server$" "$STUB_LOG"
    grep -q "winget uninstall --id Microsoft.DotNet.SDK.9 " "$STUB_LOG"
}

@test "sys.ps1: legacy <component>-i target maps to install" {
    ps "$BIN_DIR/sys-setup.ps1" treesitter-i
    [ "$status" -eq 0 ]
    grep -q "winget install --id tree-sitter.tree-sitter-cli " "$STUB_LOG"
}

@test "sys.ps1: rust and ghostty are not Windows components" {
    ps "$BIN_DIR/sys-setup.ps1" install rust
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown component: rust"* ]]
    ps "$BIN_DIR/sys-setup.ps1" install ghostty
    [ "$status" -eq 1 ]
}

# --- apps-setup.ps1 ---

@test "apps.ps1: discord installs via winget" {
    ps "$BIN_DIR/apps-setup.ps1" install discord
    [ "$status" -eq 0 ]
    grep -q "winget install --id Discord.Discord " "$STUB_LOG"
}

@test "apps.ps1: full install without a tty skips the browser picker" {
    ps "$BIN_DIR/apps-setup.ps1" install
    [ "$status" -eq 0 ]
    grep -q "winget install --id Valve.Steam " "$STUB_LOG"
    ! grep -q "Google.Chrome" "$STUB_LOG"
    [[ "$output" == *"Skipping browser selection"* ]]
}
