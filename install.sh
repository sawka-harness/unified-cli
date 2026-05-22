#!/usr/bin/env bash
set -euo pipefail

REPO="sawka-harness/unified-cli"
BINARY_NAME="harness"
INSTALL_DIR="${HARNESS_INSTALL_DIR:-$HOME/.local/bin}"
USER_OVERRIDE="${HARNESS_INSTALL_DIR:+yes}"  # set if user provided override

# ── helpers ────────────────────────────────────────────────────────────────────

info()    { printf '  \033[34m•\033[0m %s\n' "$*"; }
success() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()    { printf '  \033[33m!\033[0m %s\n' "$*"; }
error()   { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

is_interactive() { { true </dev/tty; } 2>/dev/null; }

confirm() {
    local prompt="$1"
    local answer
    printf '  \033[34m?\033[0m %s [Y/n] ' "$prompt"
    read -r answer </dev/tty
    case "$answer" in
        [nN]*) return 1 ;;
        *)     return 0 ;;
    esac
}

# ── platform detection ─────────────────────────────────────────────────────────

detect_platform() {
    local os arch

    case "$(uname -s)" in
        Darwin) os="darwin" ;;
        Linux)  os="linux"  ;;
        *)      error "Unsupported OS: $(uname -s)" ;;
    esac

    case "$(uname -m)" in
        x86_64)          arch="amd64" ;;
        arm64 | aarch64) arch="arm64" ;;
        *)               error "Unsupported architecture: $(uname -m)" ;;
    esac

    echo "${os}_${arch}"
}

detect_shell_rc() {
    local shell_name
    shell_name="$(basename "${SHELL:-bash}")"
    case "$shell_name" in
        zsh)  echo "$HOME/.zshrc"    ;;
        bash) echo "$HOME/.bashrc"   ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *)    echo "$HOME/.bashrc"   ;;  # safe fallback
    esac
}

# ── download ───────────────────────────────────────────────────────────────────

latest_version() {
    curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep '"tag_name"' \
        | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
}

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        error "No sha256sum or shasum command found — cannot verify download. Set HARNESS_NO_VERIFY=1 to skip verification."
    fi
}

download_binary() {
    local version="$1" platform="$2" dest="$3"
    local ver="${version#v}"
    local base="${BINARY_NAME}_${ver}_${platform}"
    local url="https://github.com/${REPO}/releases/download/${version}/${base}.tar.gz"
    local checksum_url="https://github.com/${REPO}/releases/download/${version}/${BINARY_NAME}_${ver}_checksums.txt"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    info "Downloading $BINARY_NAME $version ($platform)..."
    curl -fsSL "$url" -o "$tmp/harness.tar.gz"

    if [ -n "${HARNESS_NO_VERIFY:-}" ]; then
        warn "Skipping checksum verification (HARNESS_NO_VERIFY set)"
    else
        info "Verifying checksum..."
        curl -fsSL "$checksum_url" -o "$tmp/checksums.txt"
        local expected actual
        expected="$(grep "${base}.tar.gz" "$tmp/checksums.txt" | cut -d' ' -f1)"
        [ -z "$expected" ] && error "Checksum entry not found for ${base}.tar.gz"
        actual="$(sha256_file "$tmp/harness.tar.gz")"
        [ "$actual" = "$expected" ] || error "Checksum mismatch — download may be corrupted"
    fi

    tar -xzf "$tmp/harness.tar.gz" -C "$tmp"
    mv "$tmp/$BINARY_NAME" "$dest/$BINARY_NAME"
    chmod +x "$dest/$BINARY_NAME"
}

# ── shell config ───────────────────────────────────────────────────────────────

shell_config_block() {
    local shell_name
    shell_name="$(basename "${SHELL:-bash}")"
    printf '# <HarnessCLI>\n'
    if [ "$shell_name" = "fish" ]; then
        printf 'fish_add_path "$HOME/.local/bin"\n'
        printf 'harness completion fish | source\n'
    else
        printf 'export PATH="$HOME/.local/bin:$PATH"\n'
        printf 'source <(harness completion %s)\n' "$shell_name"
    fi
    printf '# </HarnessCLI>\n'
}

patch_shell_rc() {
    local rc="$1"
    touch "$rc"
    printf '\n%s\n' "$(shell_config_block)" >> "$rc"
}

already_patched() {
    local rc="$1"
    grep -q '<HarnessCLI>' "$rc" 2>/dev/null
}

# ── main ───────────────────────────────────────────────────────────────────────

main() {
    printf '\n  \033[1mHarness CLI installer\033[0m\n\n'

    local platform version
    platform="$(detect_platform)"
    version="$(latest_version)"

    [ -z "$version" ] && error "Could not determine latest version"

    # create install dir if needed
    mkdir -p "$INSTALL_DIR"

    # install binary
    download_binary "$version" "$platform" "$INSTALL_DIR"
    success "Installed $BINARY_NAME $version to $INSTALL_DIR/$BINARY_NAME"

    # check if binary is reachable
    if ! command -v "$BINARY_NAME" >/dev/null 2>&1; then
        warn "$INSTALL_DIR is not on your PATH"
    fi

    # shell config — only if interactive and user didn't override install dir
    if is_interactive && [ -z "$USER_OVERRIDE" ]; then
        local rc
        rc="$(detect_shell_rc)"
        local rc_name
        rc_name="$(basename "$rc")"

        if already_patched "$rc"; then
            info "Shell config already set up in ~/$rc_name, skipping"
        else
            printf '\n'
            info "Would you like us to update ~/$rc_name?"
            info "  - Add ~/.local/bin to PATH"
            info "  - Add shell completions"
            printf '\n'

            if confirm "Update ~/$rc_name"; then
                patch_shell_rc "$rc"
                success "Updated ~/$rc_name"
                info "Run 'source ~/$rc_name' or open a new terminal to apply"
            else
                printf '\n'
                info "To set up manually, add to ~/$rc_name:"
                printf '\n%s\n' "$(shell_config_block)"
            fi
        fi
    fi

    printf '\n'
    success "Done! Run 'harness version' to verify.\n"
}

main
