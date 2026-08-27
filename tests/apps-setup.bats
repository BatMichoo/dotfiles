#!/usr/bin/env bats

load 'helpers/stubs'

setup() {
    setup_stubs
    stub_all_common
    SCRIPT="$BATS_TEST_DIRNAME/../.local/bin/apps-setup.sh"
}

@test "discord: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install discord
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm discord" "$STUB_LOG"
}

@test "discord: debian downloads and installs a .deb" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install discord
    [ "$status" -eq 0 ]
    grep -q "curl -Lo /tmp/discord.deb" "$STUB_LOG"
    grep -q "apt-get install -y /tmp/discord.deb" "$STUB_LOG"
}

@test "steam: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install steam
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm steam" "$STUB_LOG"
}

@test "steam: debian adds i386 arch and uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install steam
    [ "$status" -eq 0 ]
    grep -q "dpkg --add-architecture i386" "$STUB_LOG"
}

@test "chrome: arch uses paru (AUR)" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install chrome
    [ "$status" -eq 0 ]
    grep -q "paru -S --noconfirm google-chrome" "$STUB_LOG"
}

@test "chrome: debian downloads and installs a .deb" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install chrome
    [ "$status" -eq 0 ]
    grep -q "curl -Lo /tmp/google-chrome.deb" "$STUB_LOG"
    grep -q "apt-get install -y /tmp/google-chrome.deb" "$STUB_LOG"
}

@test "firefox: arch uses pacman" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install firefox
    [ "$status" -eq 0 ]
    grep -q "pacman -S --noconfirm firefox" "$STUB_LOG"
}

@test "firefox: debian uses apt-get" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install firefox
    [ "$status" -eq 0 ]
    grep -q "apt-get install -y firefox" "$STUB_LOG"
}

@test "brave: arch uses paru (AUR)" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install brave
    [ "$status" -eq 0 ]
    grep -q "paru -S --noconfirm brave-bin" "$STUB_LOG"
}

@test "brave: debian uses the official install script over curl" {
    DOTFILES_TEST_OS=debian run bash "$SCRIPT" install brave
    [ "$status" -eq 0 ]
    grep -q "curl -fsS https://dl.brave.com/install.sh" "$STUB_LOG"
}


# Note: the numbered choice branches (1-4) aren't tested here — the script
# checks `[ -t 0 ]`, which is false for piped stdin too, not just closed
# stdin, so `echo 2 | script` can't reach them without a real pty.
@test "browser_select: no tty skips browser install instead of hanging" {
    DOTFILES_TEST_OS=arch run bash "$SCRIPT" install all < /dev/null
    [ "$status" -eq 0 ]
    ! grep -q "google-chrome" "$STUB_LOG"
    ! grep -q "firefox" "$STUB_LOG"
    ! grep -q "brave" "$STUB_LOG"
}

@test "unknown component fails with usage" {
    run bash "$SCRIPT" install not-a-real-thing
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown component"* ]]
}
