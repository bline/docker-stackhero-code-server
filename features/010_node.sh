#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if Node.js installation is not enabled
if [[ ${INSTALL_NODE:-false} != "true" ]]; then
  echo "**** Skipping Node.js install ****"
  exit 0
fi

echo "**** Installing Node.js ${NODE_MAJOR_VERSION} from NodeSource ****"

# Add NodeSource repository and install Node.js
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR_VERSION}.x" | bash -
apt-get install -y nodejs
