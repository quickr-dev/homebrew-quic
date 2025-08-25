#!/bin/bash

# QuicDB CLI Installer/Updater
# Always installs the latest version

set -e

INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="quic"

# Get latest version from VERSION file
get_latest_version() {
    local version_url="https://raw.githubusercontent.com/quickr-dev/quic-cli/main/VERSION"
    local latest_version=""

    # Get VERSION file content (quietly)
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s "$version_url" 2>/dev/null | tr -d '\n\r')
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "$version_url" 2>/dev/null | tr -d '\n\r')
    else
        echo "❌ Need curl or wget" >&2
        exit 1
    fi

    if [ -z "$latest_version" ]; then
        echo "❌ Could not determine latest version" >&2
        exit 1
    fi

    # Remove 'v' prefix if present and return version
    echo "$latest_version" | sed 's/^v//'
}

# Detect platform
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "❌ Unsupported architecture: $arch"; exit 1 ;;
    esac

    case "$os" in
        darwin) echo "darwin-$arch" ;;
        linux) echo "linux-$arch" ;;
        *) echo "❌ Unsupported OS: $os"; exit 1 ;;
    esac
}

# Install binary
install_binary() {
    local version="$1"
    local platform="$2"
    local binary_name="quic-${platform}"
    local download_url="https://github.com/quickr-dev/quic-cli/raw/main/bin/${binary_name}"

    local temp_file="/tmp/quic-$$"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$download_url" -o "$temp_file" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O "$temp_file" 2>/dev/null
    else
        echo "❌ Need curl or wget"
        exit 1
    fi

    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        echo "❌ Download failed"
        exit 1
    fi

    chmod +x "$temp_file"

    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Install (no sudo needed)
    mv "$temp_file" "${INSTALL_DIR}/${BINARY_NAME}"
}

# Main
main() {
    # Get current version if installed
    local current_version=""
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        current_version=$(quic version 2>/dev/null | grep -o 'v[0-9]\.[0-9]\.[0-9]' | head -1 | sed 's/v//')
    fi

    local latest_version=$(get_latest_version)
    local platform=$(detect_platform)

    if [ -n "$current_version" ]; then
        if [ "$current_version" = "$latest_version" ]; then
            echo "Already on latest version v${latest_version}"
            exit 0
        fi
    fi

    echo "Installing quic v${latest_version}..."
    install_binary "$latest_version" "$platform"

    # Add to PATH if needed
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        # Add to shell profile
        local shell_profile=""
        if [ -n "$ZSH_VERSION" ]; then
            shell_profile="$HOME/.zshrc"
        elif [ -n "$BASH_VERSION" ]; then
            shell_profile="$HOME/.bashrc"
        else
            shell_profile="$HOME/.profile"
        fi

        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$shell_profile"
        
        # Source the profile to update current session
        export PATH="$HOME/.local/bin:$PATH"
        if [ -f "$shell_profile" ]; then
            source "$shell_profile" 2>/dev/null || true
        fi
    fi

    echo "Done!"
}

main "$@"
