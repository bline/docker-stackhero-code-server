#!/bin/sh
set -e  # Exit on error

# Ensure PORT is set, default to 8080 if not provided
PORT=${PORT:-8080}

# Change root's home directory to /workspace
export HOME="${DEFAULT_WORKSPACE}"

# Create necessary directories
echo "Creating directories..."
mkdir -p "${HOME}" || { echo "Failed to create ${HOME}"; exit 1; }
mkdir -p "${XDG_DATA_HOME}" || { echo "Failed to create ${XDG_DATA_HOME}"; exit 1; }
mkdir -p "${XDG_CONFIG_HOME}" || { echo "Failed to create ${XDG_CONFIG_HOME}"; exit 1; }
mkdir -p "${XDG_CACHE_HOME}" || { echo "Failed to create ${XDG_CACHE_HOME}"; exit 1; }

echo "Starting code-server on 0.0.0.0:${PORT}"

# Start code-server with correct bind address
exec /app/code-server/bin/code-server \
    --bind-addr 0.0.0.0:${PORT} \
    --host 0.0.0.0 \
    --disable-telemetry \
    "${DEFAULT_WORKSPACE}"