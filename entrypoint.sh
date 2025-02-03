#!/bin/bash
# Exit immediately on error, undefined variable, or failed pipeline.
set -euo pipefail

###############################################################################
# Check for Critical Environment Variables
###############################################################################
: "${DEFAULT_WORKSPACE:?DEFAULT_WORKSPACE must be set}"
: "${USER_NAME:?USER_NAME must be set}"
: "${FLY_APP_NAME:?FLY_APP_NAME must be set}"

###############################################################################
# Terminal Colors (Portable)
###############################################################################
if command -v tput &>/dev/null; then
  BLUE=$(tput setaf 4)
  GREEN=$(tput setaf 2)
  RED=$(tput setaf 1)
  LIGHT_BLUE=$(tput setaf 6)
  RESET=$(tput sgr0)
else
  BLUE=""
  GREEN=""
  RED=""
  LIGHT_BLUE=""
  RESET=""
fi

###############################################################################
# Environment Variables & Defaults
###############################################################################
PORT=${PORT:-8080}
SSH_DIR="${DEFAULT_WORKSPACE}/.ssh"

###############################################################################
# Functions
###############################################################################

# -----------------------------------------------------------------------------
# get_fly_env_vars
# -----------------------------------------------------------------------------
# Optimized parser for fly.toml: extracts environment variable keys from the
# [env] section while ignoring commented/empty lines.
get_fly_env_vars() {
  local fly_toml="$1"
  [[ -f "$fly_toml" ]] || return 0

  awk '
    /^\[env\]/ { in_env=1; next }
    /^\[/ { in_env=0 }
    in_env && /^[[:space:]]*[^#[:space:]]/ {
      match($0, /^[[:space:]]*"?([^"=[:space:]]+)"?[[:space:]]*=/, arr)
      if (arr[1] != "") print arr[1]
    }
  ' "$fly_toml"
}

# -----------------------------------------------------------------------------
# get_env_vars_array
# -----------------------------------------------------------------------------
# Reads a file and extracts non-commented, non-empty environment variable names.
get_env_vars_array() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0

  awk '!/^#/ && NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }' "$env_file"
}

# -----------------------------------------------------------------------------
# write_sudoers_for_vars
# -----------------------------------------------------------------------------
# Writes a sudoers entry to allow the specified user to preserve a list of
# environment variables. Handles long lists by formatting them properly and
# only writes when the content has changed.
write_sudoers_for_vars() {
  local username="$1"
  shift
  [[ $# -eq 0 ]] && return 0  # Nothing to do if no variables provided

  local sudoers_file="/etc/sudoers.d/${username}_env"
  local temp_file
  temp_file="$(mktemp)"

  for var in "$@"; do
    echo "Defaults:${username} env_keep += \"$var\"" >> "$temp_file"
  done

  # Only update the sudoers file if the content has changed
  if [[ ! -f "$sudoers_file" ]] || ! cmp -s "$temp_file" "$sudoers_file"; then
    mv "$temp_file" "$sudoers_file"
    chmod 0440 "$sudoers_file"
  else
    rm "$temp_file"
  fi
}

# -----------------------------------------------------------------------------
# ensure_dir
# -----------------------------------------------------------------------------
# Ensures a directory exists and sets the proper permissions.
ensure_dir() {
  local dir_name="$1"
  local dir_path="$2"
  local permissions="$3"

  if [[ ! -d "$dir_path" ]]; then
    echo -e "${GREEN}  *${RESET} Creating ${dir_name} directory at ${dir_path}..."
    mkdir -p "$dir_path" && chmod "$permissions" "$dir_path" || {
      echo -e "${RED}ERROR:${RESET} Failed to create ${dir_path}"
      exit 1
    }
  else
    echo -e "${GREEN}  *${RESET} ${dir_name} directory already exists."
  fi
}

###############################################################################
# Main Execution
###############################################################################

echo -e "${BLUE}==== Setting up environment ====${RESET}"
ensure_dir "Workspace" "${DEFAULT_WORKSPACE}" 755
ensure_dir "SSH" "${SSH_DIR}" 700

# -----------------------------------------------------------------------------
# Git Configuration
# -----------------------------------------------------------------------------
if [[ -n "${GIT_USER:-}" && -n "${GIT_EMAIL:-}" ]]; then
  if ! git config --global user.name >/dev/null 2>&1; then
    echo -e "${GREEN}  *${RESET} Configuring Git user: ${LIGHT_BLUE}${GIT_USER}${RESET}"
    git config --global user.name "${GIT_USER}"
  fi
  if ! git config --global user.email >/dev/null 2>&1; then
    echo -e "${GREEN}  *${RESET} Configuring Git email: ${LIGHT_BLUE}${GIT_EMAIL}${RESET}"
    git config --global user.email "${GIT_EMAIL}"
  fi
else
  echo -e "${RED}  *${RESET} Git user/email not set, skipping configuration."
fi

# -----------------------------------------------------------------------------
# Process Environment Variables
# -----------------------------------------------------------------------------
# Read variable names from fly.toml and extra_env.list.
readarray -t fly_vars < <(get_fly_env_vars "/config/fly.toml")
readarray -t extra_vars < <(get_env_vars_array "/config/extra_env.list")

# Deduplicate variable names.
declare -A seen
vars_array=()
for var in "${fly_vars[@]}" "${extra_vars[@]}"; do
  [[ -n "$var" && -z "${seen[$var]}" ]] || continue
  seen[$var]=1
  vars_array+=("$var")
done

# Write sudoers entry to preserve these environment variables.
write_sudoers_for_vars "${USER_NAME}" "${vars_array[@]}"

# Export each variable and log its status.
for var in "${vars_array[@]}"; do
  if [[ -v $var ]]; then
    if [[ -z "${!var}" ]]; then
      echo -e "${RED}  *${RESET} Warning: $var is defined but empty."
    else
      echo -e "${GREEN}  *${RESET} Exported: ${LIGHT_BLUE}$var${RESET}"
    fi
    export "$var"
  else
    echo -e "${RED}  *${RESET} Warning: $var is defined in config but unset in the environment."
  fi
done

# -----------------------------------------------------------------------------
# Launch code-server
# -----------------------------------------------------------------------------
exec sudo -i -u "${USER_NAME}" /app/code-server/bin/code-server \
    --bind-addr "0.0.0.0:${PORT}" \
    --host "0.0.0.0" \
    --disable-telemetry
