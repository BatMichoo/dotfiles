#!/usr/bin/env bats

load 'helpers/stubs'

setup() {
    setup_stubs
    # gdbus/systemctl are real, live-session commands (D-Bus calls, systemd
    # --user restarts) — always stub these regardless of kwriteconfig6, so
    # the live desktop session is never touched by these tests.
    stub gdbus
    stub systemctl
    SCRIPT="$BATS_TEST_DIRNAME/../.local/bin/kde-setup.sh"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$FAKE_HOME/.config"
    HOME="$FAKE_HOME"
    export HOME
}

@test "skips entirely when kwriteconfig6 is missing (not a KDE Plasma system)" {
    # kwriteconfig6 is genuinely installed system-wide on the box this
    # suite runs on, so even the [stub-bin, /usr/bin, /bin] PATH would find
    # the real one. The script exits immediately after this one check
    # (nothing else runs), so it's safe to use a fully empty PATH here.
    BASH_BIN="$(command -v bash)"
    PATH="$STUB_BIN" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"kwriteconfig6 not found"* ]]
}

@test "applies terminal defaults when kwriteconfig6 is present" {
    stub kwriteconfig6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q "kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty" "$STUB_LOG"
    grep -q "kwriteconfig6 --file kdeglobals --group General --key TerminalService com.mitchellh.ghostty.desktop" "$STUB_LOG"
}

@test "sets Neovim as default handler for text/plain in mimeapps.list" {
    stub kwriteconfig6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q "^text/plain=nvim.desktop;$" "$FAKE_HOME/.config/mimeapps.list"
}

@test "configures the Bulgarian phonetic + US keyboard layout" {
    stub kwriteconfig6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q "kwriteconfig6 --file kxkbrc --group Layout --key LayoutList us,bg" "$STUB_LOG"
    grep -q "kwriteconfig6 --file kxkbrc --group Layout --key Options grp:alt_shift_toggle" "$STUB_LOG"
}

@test "configures power/screen-lock timeouts" {
    stub kwriteconfig6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q "kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayIdleTimeoutSec 1800" "$STUB_LOG"
    grep -q "kwriteconfig6 --file kscreenlockerrc --group Daemon --key Timeout 30" "$STUB_LOG"
}

@test "configures flat pointer acceleration profile" {
    stub kwriteconfig6
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    grep -q "kwriteconfig6 --file kcminputrc --group Libinput --group Defaults --key PointerAccelerationProfile 1" "$STUB_LOG"
}
