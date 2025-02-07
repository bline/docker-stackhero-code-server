#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if Hadolint installation is not enabled
if [[ ${INSTALL_HADOLINT:-false} != "true" ]]; then
  echo "**** Skipping Hadolint install ****"
  exit 0
fi

echo "**** Installing Hadolint (Version: ${HADOLINT_VERSION}) ****"

# Download and install Hadolint
curl -L "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
chmod +x /usr/local/bin/hadolint
