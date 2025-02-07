#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if CST installation is not enabled
if [[ ${INSTALL_CST:-false} != "true" ]]; then
  echo "**** Skipping Container Structure Test install ****"
  exit 0
fi

echo "**** Installing Container Structure Test (CST) ****"
curl -Lo /usr/local/bin/container-structure-test \
  "https://storage.googleapis.com/container-structure-test/${CST_VERSION}/container-structure-test"
chmod +x /usr/local/bin/container-structure-test
