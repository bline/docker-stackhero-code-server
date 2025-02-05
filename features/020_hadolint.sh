#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if Hadolint installation is not enabled
[[ ${INSTALL_HADOLINT:-false} == "true" ]] || exit 0

echo "**** Installing Hadolint (Version: ${HADOLINT_VERSION}) ****"

# Download and install Hadolint
curl -L "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
chmod +x /usr/local/bin/hadolint
