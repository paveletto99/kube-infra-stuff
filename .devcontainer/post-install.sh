#!/bin/bash

# Post-install script for devcontainer
# This script installs Cilium CLI

echo "Installing Cilium CLI..."

# Get the latest Cilium CLI version
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

# Determine architecture
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then
    CLI_ARCH=arm64
fi

echo "Installing Cilium CLI version: ${CILIUM_CLI_VERSION} for architecture: ${CLI_ARCH}"

# Download Cilium CLI
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# Verify checksum
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum

# Extract and install
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin

# Clean up
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

echo "Cilium CLI installation completed successfully!"

# Verify installation
cilium version --client