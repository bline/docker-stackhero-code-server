#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if Flyctl installation is not enabled
[[ ${INSTALL_FLYCTL:-false} == "true" ]] || exit 0

echo "**** Installing Flyctl ****"

# Install Flyctl using Fly.io’s official install script
curl -L https://fly.io/install.sh | sh
