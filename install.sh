#!/bin/sh
set -eu

# ── Configuration (overridable via env) ──────────────────────────────────────
TOTP_HOME="${TOTP_HOME:-$HOME/.totp}"
TOTP_LOCAL_BIN="${TOTP_LOCAL_BIN:-$HOME/.local/bin}"
TOTP_REPO_OWNER="${TOTP_REPO_OWNER:-codesoda}"
TOTP_REPO_NAME="${TOTP_REPO_NAME:-totp}"
TOTP_REPO_REF="${TOTP_REPO_REF:-}"  # empty = latest release
BIN_NAME="totp"

# ── Helpers ──────────────────────────────────────────────────────────────────
info()  { printf '  \033[1;34m→\033[0m %s\n' "$*"; }
ok()    { printf '  \033[1;32m✓\033[0m %s\n' "$*"; }
err()   { printf '  \033[1;31m✗\033[0m %s\n' "$*" >&2; }
die()   { err "$@"; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not found"
}

detect_target() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Darwin) os="apple-darwin" ;;
        Linux)  os="unknown-linux-gnu" ;;
        *)      die "Unsupported OS: $os" ;;
    esac
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)       die "Unsupported architecture: $arch" ;;
    esac
    echo "${arch}-${os}"
}

# ── Install binary to TOTP_HOME ─────────────────────────────────────────────
install_binary() {
    local src="$1"
    mkdir -p "$TOTP_HOME/bin"
    cp "$src" "$TOTP_HOME/bin/$BIN_NAME"
    chmod +x "$TOTP_HOME/bin/$BIN_NAME"

    # macOS: strip quarantine & ad-hoc sign
    if [ "$(uname -s)" = "Darwin" ]; then
        xattr -dr com.apple.quarantine "$TOTP_HOME/bin/$BIN_NAME" 2>/dev/null || true
        codesign -s - -f "$TOTP_HOME/bin/$BIN_NAME" 2>/dev/null || true
    fi

    ok "Installed $BIN_NAME to $TOTP_HOME/bin/$BIN_NAME"

    # Symlink into PATH
    if [ -d "$TOTP_LOCAL_BIN" ] || mkdir -p "$TOTP_LOCAL_BIN" 2>/dev/null; then
        ln -sf "$TOTP_HOME/bin/$BIN_NAME" "$TOTP_LOCAL_BIN/$BIN_NAME"
        ok "Symlinked to $TOTP_LOCAL_BIN/$BIN_NAME"
    fi

    # Check if on PATH
    if ! echo "$PATH" | tr ':' '\n' | grep -qx "$TOTP_LOCAL_BIN"; then
        echo
        info "Add to your shell profile:"
        echo "    export PATH=\"$TOTP_LOCAL_BIN:\$PATH\""
    fi

    echo
    ok "Done! Run '$BIN_NAME --help' to get started."
}

# ── Build from local source ──────────────────────────────────────────────────
build_from_source() {
    info "Building from source ($SOURCE_ROOT) ..."
    need cargo
    (cd "$SOURCE_ROOT" && cargo build --release --quiet)
    local bin="$SOURCE_ROOT/target/release/$BIN_NAME"
    [ -f "$bin" ] || die "Build succeeded but binary not found at $bin"
    install_binary "$bin"
}

# ── Download pre-built release ───────────────────────────────────────────────
install_from_release() {
    need curl
    need tar

    local target tag url tmp
    target="$(detect_target)"

    if [ -n "$TOTP_REPO_REF" ]; then
        tag="$TOTP_REPO_REF"
    else
        info "Fetching latest release tag ..."
        tag="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
            "https://github.com/${TOTP_REPO_OWNER}/${TOTP_REPO_NAME}/releases/latest" \
            | grep -o '[^/]*$')"
        [ -n "$tag" ] || die "Could not determine latest release"
    fi

    info "Downloading $BIN_NAME $tag for $target ..."
    url="https://github.com/${TOTP_REPO_OWNER}/${TOTP_REPO_NAME}/releases/download/${tag}/${BIN_NAME}-${tag}-${target}.tar.gz"

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    curl -fsSL "$url" | tar xz -C "$tmp"
    local bin="$tmp/$BIN_NAME"
    [ -f "$bin" ] || die "Archive did not contain '$BIN_NAME'"

    install_binary "$bin"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo
    echo "  \033[1mtotp installer\033[0m"
    echo

    # Detect local source checkout
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$script_dir/Cargo.toml" ] && [ -d "$script_dir/src" ]; then
        SOURCE_ROOT="$script_dir"
        build_from_source
    else
        install_from_release
    fi
}

main "$@"
