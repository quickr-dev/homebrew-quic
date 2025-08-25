#!/bin/bash

# QuicDB CLI Installer/Updater
# Always installs the latest version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="quic"

echo -e "${BLUE}🚀 QuicDB CLI Installer${NC}"

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
        echo -e "${RED}❌ Need curl or wget${NC}" >&2
        exit 1
    fi

    if [ -z "$latest_version" ]; then
        echo -e "${RED}❌ Could not determine latest version${NC}" >&2
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
        *) echo -e "${RED}❌ Unsupported architecture: $arch${NC}"; exit 1 ;;
    esac

    case "$os" in
        darwin) echo "darwin-$arch" ;;
        linux) echo "linux-$arch" ;;
        *) echo -e "${RED}❌ Unsupported OS: $os${NC}"; exit 1 ;;
    esac
}

# Install binary
install_binary() {
    local version="$1"
    local platform="$2"
    local binary_name="quic-${platform}"
    local download_url="https://github.com/quickr-dev/quic-cli/raw/main/bin/${binary_name}"

    echo -e "${YELLOW}📥 Downloading ${binary_name} v${version}...${NC}"

    local temp_file="/tmp/quic-$$"

    if command -v curl >/dev/null 2>&1; then
        curl -fL "$download_url" -o "$temp_file"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O "$temp_file"
    else
        echo -e "${RED}❌ Need curl or wget${NC}"
        exit 1
    fi

    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        echo -e "${RED}❌ Download failed${NC}"
        exit 1
    fi

    chmod +x "$temp_file"

    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Install (no sudo needed)
    mv "$temp_file" "${INSTALL_DIR}/${BINARY_NAME}"

    echo -e "${GREEN}✅ Installed quic v${version} to ${INSTALL_DIR}${NC}"
}

# Main
main() {
    # Get current version if installed
    local current_version=""
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        current_version=$(quic version 2>/dev/null | grep -o 'v[0-9]\.[0-9]\.[0-9]' | head -1 | sed 's/v//')
    fi

    echo -e "${YELLOW}🔍 Finding latest version...${NC}"
    local latest_version=$(get_latest_version)
    local platform=$(detect_platform)

    if [ -n "$current_version" ]; then
        echo -e "${BLUE}📋 Current: v${current_version}, Latest: v${latest_version}${NC}"

        if [ "$current_version" = "$latest_version" ]; then
            echo -e "${GREEN}✅ Already on latest version v${latest_version}${NC}"
            exit 0
        fi
    else
        echo -e "${BLUE}📋 Installing latest version: v${latest_version}${NC}"
    fi

    install_binary "$latest_version" "$platform"

    # Add to PATH if needed
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        echo -e "${YELLOW}📝 Adding $INSTALL_DIR to PATH...${NC}"

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
        echo -e "${YELLOW}💡 Added to $shell_profile - restart your shell or run: source $shell_profile${NC}"

        # Add to current session
        export PATH="$HOME/.local/bin:$PATH"
    fi

    # Verify
    if command -v "$BINARY_NAME" >/dev/null 2>&1; then
        local installed_version=$(quic version 2>/dev/null | grep -o 'v[0-9]\.[0-9]\.[0-9]' | head -1)
        echo -e "${GREEN}🎉 Successfully installed QuicDB CLI ${installed_version}${NC}"
    else
        echo -e "${YELLOW}⚠️  Installation complete but quic not found in PATH${NC}"
        echo -e "${YELLOW}💡 Try: source ~/.zshrc (or restart your shell)${NC}"
    fi

    echo ""
    echo -e "${BLUE}📚 Usage:${NC}"
    echo "   quic version          # Check version"
    echo "   quic login            # Authenticate"
    echo "   quic checkout <name>  # Create database checkout"
    echo "   quic delete <name>    # Delete database checkout"
    echo ""
    echo -e "${BLUE}🔄 To update in the future:${NC}"
    echo "   curl -sf https://raw.githubusercontent.com/quickr-dev/quic-cli/main/install.sh | bash"
    echo "   # Or: quic update"
}

main "$@"
