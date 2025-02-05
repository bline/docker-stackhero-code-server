#!/bin/bash
set -euo pipefail # Enable strict mode

# Exit early if CST installation is not enabled
[[ ${INSTALL_CST:-false} == "true" ]] || exit 0

echo "**** Installing Container Structure Test (CST) ****"
curl -Lo /usr/local/bin/container-structure-test \
  "https://storage.googleapis.com/container-structure-test/${CST_VERSION}/container-structure-test"
chmod +x /usr/local/bin/container-structure-test
