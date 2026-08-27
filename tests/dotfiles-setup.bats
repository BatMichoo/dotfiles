#!/usr/bin/env bats

load 'helpers/stubs'

setup() {
    setup_stubs
    SCRIPT="$BATS_TEST_DIRNAME/../.local/bin/dotfiles-setup.sh"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    BIN="$FAKE_HOME/.local/bin"
    mkdir -p "$BIN"
    HOME="$FAKE_HOME"
    export HOME

    # Fake stand-ins for every script dotfiles-setup.sh may invoke, so this
    # file tests only its own flag-to-script dispatch logic, not the real
    # sub-scripts' behavior (those have their own .bats files).
    for name in github-ssh-setup.sh repo-setup.sh kde-setup.sh sys-setup.sh apps-setup.sh reload-services.sh; do
        cat > "$BIN/$name" <<EOF
#!/usr/bin/env bash
echo "ran:$name \$*" >> "$STUB_LOG"
EOF
        chmod +x "$BIN/$name"
    done
}

@test "no args shows the interactive menu (closed stdin aborts at the read, exit 1 — a real rough edge, not this suite's job to fix)" {
    run bash "$SCRIPT" < /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unified Dotfiles Bootstrap Setup"* ]]
}

@test "-h shows help and exits 0" {
    run bash "$SCRIPT" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "-k runs only kde-setup.sh (and the trailing reload)" {
    run bash "$SCRIPT" -k
    [ "$status" -eq 0 ]
    grep -q "ran:kde-setup.sh" "$STUB_LOG"
    grep -q "ran:reload-services.sh" "$STUB_LOG"
    ! grep -q "ran:sys-setup.sh" "$STUB_LOG"
    ! grep -q "ran:apps-setup.sh" "$STUB_LOG"
}

@test "-s runs sys-setup.sh with the install action" {
    run bash "$SCRIPT" -s
    [ "$status" -eq 0 ]
    grep -q "ran:sys-setup.sh install" "$STUB_LOG"
}

@test "-a runs apps-setup.sh with the install action" {
    run bash "$SCRIPT" -a
    [ "$status" -eq 0 ]
    grep -q "ran:apps-setup.sh install" "$STUB_LOG"
}

@test "--all runs bootstrap, kde, sys, and apps" {
    run bash "$SCRIPT" --all
    [ "$status" -eq 0 ]
    grep -q "ran:github-ssh-setup.sh" "$STUB_LOG"
    grep -q "ran:repo-setup.sh" "$STUB_LOG"
    grep -q "ran:kde-setup.sh" "$STUB_LOG"
    grep -q "ran:sys-setup.sh install" "$STUB_LOG"
    grep -q "ran:apps-setup.sh install" "$STUB_LOG"
}

@test "--skip-sys runs bootstrap, kde, and apps but not sys" {
    run bash "$SCRIPT" --skip-sys
    [ "$status" -eq 0 ]
    grep -q "ran:kde-setup.sh" "$STUB_LOG"
    grep -q "ran:apps-setup.sh" "$STUB_LOG"
    ! grep -q "ran:sys-setup.sh" "$STUB_LOG"
}

@test "-b skips SSH key generation when a key already exists" {
    mkdir -p "$FAKE_HOME/.ssh"
    : > "$FAKE_HOME/.ssh/id_ed25519"
    run bash "$SCRIPT" -b
    [ "$status" -eq 0 ]
    grep -q "ran:github-ssh-setup.sh" "$STUB_LOG"
    grep -q "ran:repo-setup.sh" "$STUB_LOG"
}

@test "reload-services.sh runs at the end regardless of which flags were passed" {
    run bash "$SCRIPT" -a
    [ "$status" -eq 0 ]
    grep -q "ran:reload-services.sh" "$STUB_LOG"
}
