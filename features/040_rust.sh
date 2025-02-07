#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if Rust installation is not enabled
if [[ ${INSTALL_RUST:-false} != "true" ]]; then
  echo "**** Skipping Rust install ****"
  exit 0
fi

# Default installation directory
RUST_INSTALL_PREFIX="/opt/rust"
RUST_INSTALLER="rust-${RUST_VERSION}-x86_64-unknown-linux-gnu.tar.xz"
RUST_URL="https://static.rust-lang.org/dist/${RUST_INSTALLER}"

echo "**** Installing Rust ${RUST_VERSION} system-wide (Docs Excluded) ****"

# Install dependencies
apt-get install -y curl xz-utils

# Create a temporary working directory
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# Download Rust installer
echo "Downloading Rust ${RUST_VERSION}..."
curl -fLO "$RUST_URL"

# Extract the installer
echo "Extracting Rust installer..."
tar -xf "$RUST_INSTALLER"

# Change directory into the extracted Rust source directory
cd "rust-${RUST_VERSION}-x86_64-unknown-linux-gnu"

# Install Rust system-wide (EXCLUDING docs)
echo "Installing Rust in ${RUST_INSTALL_PREFIX}..."
mkdir -p "$RUST_INSTALL_PREFIX"
./install.sh \
  --prefix="$RUST_INSTALL_PREFIX" \
  --bindir="$RUST_INSTALL_PREFIX/bin" \
  --libdir="$RUST_INSTALL_PREFIX/lib" \
  --components=rustc,cargo,clippy-preview,rustfmt-preview,llvm-tools-preview \
  --without=rust-docs,rust-docs-json-preview

# Ensure the Rust binaries are in the global PATH
echo "Configuring Rust environment..."
echo "export PATH=${RUST_INSTALL_PREFIX}/bin:\$PATH" >/etc/profile.d/rust.sh
echo "export PATH=${RUST_INSTALL_PREFIX}/bin:\$PATH" >>/etc/environment
export PATH="${RUST_INSTALL_PREFIX}/bin:$PATH"

# Verify Rust installation
if ! command -v rustc &>/dev/null; then
  echo "Error: Rust installation failed. 'rustc' not found."
  exit 1
fi

if ! command -v cargo &>/dev/null; then
  echo "Error: Cargo installation failed. 'cargo' not found."
  exit 1
fi

echo "Rust installed successfully:"
rustc --version
cargo --version

# Install additional Cargo packages if specified
if [[ -n ${RUST_PACKAGES:-} ]]; then
  echo "**** Installing additional Cargo packages: ${RUST_PACKAGES} ****"
  for package in ${RUST_PACKAGES}; do
    if [[ $package == *"/"* || $package == *"@"* ]]; then
      echo "Installing $package from Git..."
      cargo install --git "$package"
    else
      echo "Installing $package from crates.io..."
      cargo install "$package"
    fi
  done
fi

echo "**** Rust setup complete ****"
