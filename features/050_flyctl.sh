#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if Flyctl installation is not enabled
if [[ ${INSTALL_FLYCTL:-false} != "true" ]]; then
  echo "**** Skipping Flyctl install ****"
  exit 0
fi

echo "**** Installing Flyctl ****"

# Install Flyctl using Fly.io’s official install script
curl -L https://fly.io/install.sh | sh
