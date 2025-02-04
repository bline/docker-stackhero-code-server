#!/bin/bash
# entrypoint.sh
# Main entrypoint script that sets up the environment and launches code-server.
set -euo pipefail

###############################################################################
# Environment Variables & Defaults
###############################################################################
# These variables should be set via the Dockerfile or container environment.
: "${DEFAULT_WORKSPACE:?DEFAULT_WORKSPACE must be set}"
: "${USER_NAME:?USER_NAME must be set}"
: "${FLY_APP_NAME:?FLY_APP_NAME must be set}"
PORT=${PORT:-8080}
SSH_DIR="${DEFAULT_WORKSPACE}/.ssh"

###############################################################################
# Source Helper Functions
###############################################################################
# Source the helper library which also sets up terminal colors.
LIB_PATH=${LIB_PATH:-"/usr/local/bin/entrypoint.lib.sh"}
source "$LIB_PATH"

###############################################################################
# Main Execution
###############################################################################
log_head "Setting up environment"

# Ensure required directories exist.
ensure_dir "Workspace" "${DEFAULT_WORKSPACE}" 755
ensure_dir "SSH" "${SSH_DIR}" 700

# Configure Git if applicable.
configure_git

# Prepare the workspace (e.g., copy .bashrc and set ownership).
prepare_workspace

# Launch code-server.
launch_code_server
