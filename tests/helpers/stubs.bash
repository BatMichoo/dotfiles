#!/usr/bin/env bash
# Shared bats helper: stubs external commands (package managers, sudo, curl,
# git, systemctl, ...) so the setup scripts under test never touch the real
# network, package databases, or the live desktop session.
#
# Usage in a .bats file:
#   load 'helpers/stubs'
#   setup() {
#       setup_stubs
#       stub_all_common
#   }

# # Creates an isolated bin dir and a log file every stub appends to, then
# REPLACES (not prepends to) PATH with just [stub-bin, /usr/bin, /bin].
# This is deliberate: prepending onto the inherited PATH still lets real
# user-installed tools in ~/.local/bin, ~/.cargo/bin, fnm's node dirs, etc.
# leak through for anything we forgot to stub — which is exactly how an
# earlier version of this suite ended up calling the real `agy` and running
# live `agy plugin install` against this machine. /usr/bin and /bin cover
# the real coreutils/bash the scripts legitimately need (mkdir, grep, sed,
# awk, chmod, ...); anything the scripts shell out to beyond that MUST be
# stubbed explicitly or it will correctly appear "not installed".
setup_stubs() {
    STUB_BIN="$BATS_TEST_TMPDIR/stub-bin"
    STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
    mkdir -p "$STUB_BIN"
    : > "$STUB_LOG"
    export STUB_BIN STUB_LOG
    PATH="$STUB_BIN:/usr/bin:/bin"
    export PATH
}

# stub <name> [exit_code] — logs "<name> <args...>" to STUB_LOG, exits 0
# (or the given code) without doing anything real.
stub() {
    local name="$1" code="${2:-0}"
    cat > "$STUB_BIN/$name" <<EOF
#!/usr/bin/env bash
echo "\$(basename "\$0") \$*" >> "\$STUB_LOG"
exit $code
EOF
    chmod +x "$STUB_BIN/$name"
}

# sudo strips any leading VAR=value assignments (mimicking real sudo's
# handling of e.g. `sudo ACCEPT_EULA=Y apt-get install ...` — a naive
# `exec "$@"` would instead try to run a program literally named
# "ACCEPT_EULA=Y" and fail) and execs the rest, so nested stub commands fire.
stub_sudo() {
    cat > "$STUB_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> "$STUB_LOG"
while [[ $# -gt 0 && "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; do
    export "$1"
    shift
done
exec "$@"
EOF
    chmod +x "$STUB_BIN/sudo"
}

# curl: logs the call; if given -o/-Lo <path>, creates an empty file there so
# downstream tar/dpkg/install steps don't fail on a missing file (they may
# still fail on invalid content under set -e, which is fine — we only assert
# on stub calls that happened before that point). Otherwise (streamed output,
# e.g. `curl ... | bash` or a version lookup) prints a harmless no-op line.
stub_curl_noop() {
    cat > "$STUB_BIN/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> "$STUB_LOG"
out=""
prev=""
for arg in "$@"; do
    if [ "$prev" = "-o" ] || [ "$prev" = "-Lo" ]; then
        out="$arg"
    fi
    prev="$arg"
done
if [ -n "$out" ]; then
    : > "$out"
else
    echo ": stub-noop"
fi
EOF
    chmod +x "$STUB_BIN/curl"
}

# The full set of external commands these scripts shell out to.
stub_all_common() {
    stub_sudo
    stub_curl_noop
    for cmd in pacman apt-get add-apt-repository dpkg npm git systemctl gdbus \
               kwriteconfig6 ssh-keygen ssh-add ssh-agent claude agy paru \
               tar install rustup fnm nvm usermod gpasswd tee; do
        stub "$cmd"
    done
}
