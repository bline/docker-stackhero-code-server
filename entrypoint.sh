#!/bin/sh
set -e  # Exit on error

# Color codes
LIGHT_BLUE="\e[94m"
BLUE="\e[34m"
GREEN="\e[32m"
RESET="\e[0m"

# Ensure PORT is set, default to 8080 if not provided
PORT=${PORT:-8080}
SSH_DIR="${DEFAULT_WORKSPACE}/.ssh"

# Function to ensure directories exist with correct permissions
ensure_dir() {
    local dir_name="$1"
    local dir_path="$2"
    local permissions="$3"

    if [ ! -d "$dir_path" ]; then
        echo -e "${GREEN}  *${RESET} Creating $dir_name directory at $dir_path..."
        mkdir -p "$dir_path" || { echo "ERROR: Failed to create $dir_path"; exit 1; }
        chmod "$permissions" "$dir_path" || { echo "ERROR: Failed to set permissions on $dir_path"; exit 1; }
    else
        echo -e "${GREEN}  *${RESET} $dir_name directory already exists at $dir_path"
    fi
}

echo -e "${BLUE}==== Setting up environment ====${RESET}"

# Ensure all required directories exist
ensure_dir "Workspace" "${DEFAULT_WORKSPACE}" 755
ensure_dir "SSH" "${SSH_DIR}" 700
ensure_dir "XDG Data Home" "${XDG_DATA_HOME}" 755
ensure_dir "XDG Config Home" "${XDG_CONFIG_HOME}" 755
ensure_dir "XDG Cache Home" "${XDG_CACHE_HOME}" 755
ensure_dir "SSH Config" "/etc/ssh/ssh_config.d" 755

echo -e "${BLUE}==== Creating necessary files ====${RESET}"

# Generate SSH config to specify the identity file location
if [ ! -f "/etc/ssh/ssh_config.d/custom.conf" ]; then
    echo -e "${GREEN}  *${RESET} Generating custom SSH config..."
    echo "IdentityFile ${SSH_DIR}/id_rsa" > /etc/ssh/ssh_config.d/custom.conf
else
    echo -e "${GREEN}  *${RESET} Custom SSH config already exists, skipping generation."
fi

# Generate SSH key if it doesn't exist
if [ ! -f "${SSH_DIR}/id_rsa" ]; then
    echo -e "${GREEN}  *${RESET} Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f "${SSH_DIR}/id_rsa" -N "" || { echo "Failed to generate SSH key"; exit 1; }
    chmod 600 "${SSH_DIR}/id_rsa" "${SSH_DIR}/id_rsa.pub"
else
    echo -e "${GREEN}  *${RESET} SSH key already exists, skipping generation."
fi

# Ensure .bashrc is copied only if missing
if [ ! -f "${DEFAULT_WORKSPACE}/.bashrc" ]; then
    echo -e "${GREEN}  *${RESET} Copying new .bashrc..."
    cp /tmp/.bashrc "${DEFAULT_WORKSPACE}/.bashrc"
else
    echo -e "${GREEN}  *${RESET} .bashrc already exists, skipping copy."
fi

# Set home directory for the root user
export HOME="${DEFAULT_WORKSPACE}"

echo -e "${BLUE}==== Launching code-server ====${RESET}"
echo -e "${GREEN}  *${RESET} Code-server will be accessible at: ${LIGHT_BLUE}https://${FLY_APP_NAME}.fly.dev/${RESET}"

exec /app/code-server/bin/code-server \
    --bind-addr 0.0.0.0:${PORT} \
    --host 0.0.0.0 \
    --disable-telemetry \
    "${DEFAULT_WORKSPACE}"
