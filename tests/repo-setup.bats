#!/usr/bin/env bats

load 'helpers/stubs'

setup() {
    setup_stubs
    stub git
    SCRIPT="$BATS_TEST_DIRNAME/../.local/bin/repo-setup.sh"
    FAKE_HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$FAKE_HOME"
    HOME="$FAKE_HOME"
    export HOME
}

@test "clones the bare repo when ~/.dotfiles doesn't exist yet" {
    run bash "$SCRIPT"
    grep -q "git clone --bare git@github.com:BatMichoo/dotfiles.git $FAKE_HOME/.dotfiles" "$STUB_LOG"
}

@test "does not re-clone when ~/.dotfiles already exists" {
    mkdir -p "$FAKE_HOME/.dotfiles"
    run bash "$SCRIPT"
    ! grep -q "git clone --bare" "$STUB_LOG"
    [[ "$output" == *"already exists"* ]]
}

@test "writes exclude rules for secrets and caches, never for the repo itself" {
    run bash "$SCRIPT"
    EXCLUDE="$FAKE_HOME/.dotfiles/info/exclude"
    [ -f "$EXCLUDE" ]
    grep -q "^\.ssh/id_\*$" "$EXCLUDE"
    grep -q "^\.gnupg/$" "$EXCLUDE"
    grep -q "^\.cache/$" "$EXCLUDE"
}

@test "sets status.showUntrackedFiles=no on the bare repo" {
    run bash "$SCRIPT"
    grep -q "git --git-dir=$FAKE_HOME/.dotfiles/ --work-tree=$FAKE_HOME config --local status.showUntrackedFiles no" "$STUB_LOG"
}
