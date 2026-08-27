#!/usr/bin/env bats

load 'helpers/stubs'

setup() {
    setup_stubs
    stub_all_common
    # ksshaskpass is intentionally NOT stubbed as present, so "command -v
    # ksshaskpass" correctly fails and the install branch under test runs.
    SCRIPT="$BATS_TEST_DIRNAME/../.local/bin/github-ssh-setup.sh"

    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$FAKE_HOME/.ssh"
    # Pre-seed a fake key so the script skips its interactive keygen prompts.
    echo "fake-key" > "$FAKE_HOME/.ssh/id_ed25519"
    echo "fake-key.pub" > "$FAKE_HOME/.ssh/id_ed25519.pub"
    HOME="$FAKE_HOME"
    export HOME
}

@test "arch: does not take the debian ksshaskpass-skip branch" {
    # Doesn't assert the pacman call itself: ksshaskpass may already be
    # genuinely installed on the machine running this suite (real KDE
    # Plasma box), in which case the script correctly takes its
    # already-installed branch instead. What's actually under test is the
    # OS gate, which this message is unique to.
    DOTFILES_TEST_OS=arch run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Skipping ksshaskpass"* ]]
}

@test "debian: does not install ksshaskpass (KDE Plasma-specific, Arch-only)" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    ! grep -q "ksshaskpass" "$STUB_LOG"
    [[ "$output" == *"Skipping ksshaskpass"* ]]
}

@test "arch: writes the KDE plasma-workspace SSH askpass env file" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_HOME/.config/plasma-workspace/env/ssh-askpass.sh" ]
}

@test "debian: does not write the KDE plasma-workspace env file" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_HOME/.config/plasma-workspace/env/ssh-askpass.sh" ]
}

@test "arch: does not create the ssh-add-keys autostart fallback (keychain via fish covers it)" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ ! -f "$FAKE_HOME/.local/bin/ssh-add-keys.sh" ]
    [ ! -f "$FAKE_HOME/.config/autostart/ssh-add-keys.desktop" ]
}

@test "debian: creates the ssh-add-keys autostart fallback (no fish/keychain provisioned there)" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$FAKE_HOME/.local/bin/ssh-add-keys.sh" ]
    [ -x "$FAKE_HOME/.local/bin/ssh-add-keys.sh" ]
    [ -f "$FAKE_HOME/.config/autostart/ssh-add-keys.desktop" ]
    grep -q "Exec=$FAKE_HOME/.local/bin/ssh-add-keys.sh" "$FAKE_HOME/.config/autostart/ssh-add-keys.desktop"
}

@test "arch: final message mentions KDE/KWallet passphrase prompt" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"KDE will prompt you"* ]]
}

@test "debian: final message omits the KDE-specific note" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" != *"KDE will prompt you"* ]]
}
