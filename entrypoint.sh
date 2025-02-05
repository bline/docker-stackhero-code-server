#!/bin/bash
# entrypoint.sh
# Main entrypoint script that sets up the environment and launches code-server.
set -euo pipefail

###############################################################################
# Environment Variables & Defaults
###############################################################################
# These variables should be set via the Dockerfile or container environment.

ENV_PATH=${ENV_PATH:-"/config/env.sh"}
# /config/env.sh is generated in Dockerfile
# ./env.sh is just for testing and to make shellcheck happy
# shellcheck source=./env.sh
source "$ENV_PATH"

# Setup our environment
DEFAULT_WORKSPACE="${DEFAULT_WORKSPACE:-/workspace}"
SERVER_PORT="${SERVER_PORT:-8080}"
PORT=${SERVER_PORT}
SSH_DIR="${DEFAULT_WORKSPACE}/.ssh"
USER_NAME="${USER_NAME:-coder}"
USER_SHELL="${USER_SHELL:-/bin/bash}"
ENABLE_GIT_CONFIG="${ENABLE_GIT_CONFIG:-"false"}"
GIT_USER="${GIT_USER:-""}"
GIT_EMAIL="${GIT_EMAIL:-""}"
FLY_TOML="${FLY_TOML:-/config/fly.toml}"

: "${DEFAULT_WORKSPACE:?DEFAULT_WORKSPACE must be set}"
: "${USER_NAME:?USER_NAME must be set}"
: "${FLY_APP_NAME:?FLY_APP_NAME must be set}"

###############################################################################
# Source Helper Functions
###############################################################################
# Source the helper library which also sets up terminal colors.
LIB_PATH=${LIB_PATH:-"/usr/local/bin/entrypoint.lib.sh"}
# shellcheck source=./entrypoint.lib.sh
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
