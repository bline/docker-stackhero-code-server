#!/bin/bash
# entrypoint.lib.sh
# This library contains helper functions for the entrypoint script,
# including logging functions and common utility routines.
#
# Terminal Colors (Portable)
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

CONFIG_DIR="${CONFIG_DIR:-/config}"
SUDOERS_DIR="${SUDOERS_DIR:-/etc/sudoers.d}"
CODE_SERVER_PATH="${CODE_SERVER_PATH:-/app/code-server/bin/code-server}"

###############################################################################
# Logging Functions
###############################################################################
log_head() {
  echo -e "${BLUE}==== $* ====${RESET}"
}

log_status() {
  echo -e "${GREEN}  *${RESET} $*"
}

log_warning() {
  echo -e "${RED}  *${RESET} Warning: $*"
}

log_error() {
  echo -e "${RED}ERROR:${RESET} $*"
}

###############################################################################
# Helper Functions
###############################################################################

# get_fly_env_vars:
#   Extracts environment variable keys from the [env] section of fly.toml.
#   Ignores commented/empty lines and strips quotes and extra whitespace.
get_fly_env_vars() {
  local fly_toml="$1"
  [[ -f "$fly_toml" ]] || return 0

  awk '
    BEGIN { in_env=0 }
    /^\[env\]/ { in_env=1; next }
    /^\[/ { in_env=0 }
    in_env {
      split($0, a, "=");
      key = a[1];
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key);
      if (key != "" && key !~ /^#/) print key;
    }
  ' "$fly_toml"
}


# get_env_vars_array:
#   Reads a file and extracts non-commented, non-empty environment variable names.
get_env_vars_array() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0

  awk '!/^#/ && NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }' "$env_file"
}

# write_sudoers_for_vars:
#   Writes a sudoers entry to allow the specified user to preserve a list of
#   environment variables. Each variable gets its own Defaults line.
#   Only updates the file if the content has changed.
write_sudoers_for_vars() {
  local username="$1"
  shift
  [[ $# -eq 0 ]] && return 0  # Nothing to do if no variables provided

  local sudoers_file="${SUDOERS_DIR}/${username}_env"
  local temp_file
  temp_file="$(mktemp)"

  for var in "$@"; do
    echo "Defaults:${username} env_keep += \"$var\"" >> "$temp_file"
  done

  if [[ ! -f "$sudoers_file" ]] || ! cmp -s "$temp_file" "$sudoers_file"; then
    mv "$temp_file" "$sudoers_file"
    chmod 0440 "$sudoers_file"
  else
    rm "$temp_file"
  fi
}

# ensure_dir:
#   Ensures that a directory exists and applies the specified permissions.
ensure_dir() {
  local dir_name="$1"
  local dir_path="$2"
  local permissions="$3"

  if [[ ! -d "$dir_path" ]]; then
    log_status "Creating ${dir_name} directory at ${dir_path}..."
    mkdir -p "$dir_path" && chmod "$permissions" "$dir_path" || {
      log_error "Failed to create ${dir_path}"
      exit 1
    }
  else
    log_status "${dir_name} directory already exists."
  fi
}

# configure_git:
#   Configures Git if GIT_USER and GIT_EMAIL are provided.
configure_git() {
  if [[ -n "${GIT_USER:-}" && -n "${GIT_EMAIL:-}" ]]; then
    if ! git config --global user.name >/dev/null 2>&1; then
      log_status "Configuring Git user: ${LIGHT_BLUE}${GIT_USER}${RESET}"
      git config --global user.name "${GIT_USER}"
    fi
    if ! git config --global user.email >/dev/null 2>&1; then
      log_status "Configuring Git email: ${LIGHT_BLUE}${GIT_EMAIL}${RESET}"
      git config --global user.email "${GIT_EMAIL}"
    fi
  else
    log_warning "Git user/email not set, skipping configuration."
  fi
}

# process_env_vars:
#   Reads environment variable names from configuration files,
#   deduplicates them, writes sudoers entries, and exports them with logging.
process_env_vars() {
  local fly_vars=() extra_vars=()
  readarray -t fly_vars < <(get_fly_env_vars "${CONFIG_DIR}/fly.toml")
  readarray -t extra_vars < <(get_env_vars_array "${CONFIG_DIR}/extra_env.list")

  declare -A seen
  local -a vars_array=()
  for var in "${fly_vars[@]}" "${extra_vars[@]}"; do
    [[ -n "$var" && -z "${seen[$var]}" ]] || continue
    seen[$var]=1
    vars_array+=("$var")
  done

  write_sudoers_for_vars "${USER_NAME}" "${vars_array[@]}"

  for var in "${vars_array[@]}"; do
    if [[ -v $var ]]; then
      if [[ -z "${!var}" ]]; then
        log_warning "$var is defined but empty."
      else
        log_status "Exported: ${LIGHT_BLUE}$var${RESET} (value: ${!var})"
      fi
      export "$var"
    else
      log_warning "$var is defined in config but unset in the environment."
    fi
  done
}

# prepare_workspace:
#   Prepares the workspace by copying configuration files and setting ownership.
prepare_workspace() {
  mkdir -p "${DEFAULT_WORKSPACE}"
  if [[ -f "/tmp/.bashrc" ]]; then
    if [[ ! -f "${DEFAULT_WORKSPACE}/.bashrc" ]] || ! cmp -s "/tmp/.bashrc" "${DEFAULT_WORKSPACE}/.bashrc"; then
      log_status "Updating .bashrc in workspace..."
      cp "/tmp/.bashrc" "${DEFAULT_WORKSPACE}/.bashrc"
    else
      log_status ".bashrc in workspace is up to date."
    fi
  else
    log_warning "/tmp/.bashrc not found. Skipping .bashrc copy."
  fi
  chown -R "${USER_NAME}:${USER_NAME}" "${DEFAULT_WORKSPACE}"
}

# launch_code_server:
#   Launches code-server as the non-root user.
launch_code_server() {
  log_head "Launching code-server as ${USER_NAME}"
  echo -e "${GREEN}  *${RESET} Code-server will be accessible at: ${LIGHT_BLUE}https://${FLY_APP_NAME}.fly.dev/${RESET}"
  exec sudo -i -u "${USER_NAME}" "${CODE_SERVER_PATH}" \
    --bind-addr "0.0.0.0:${PORT}" \
    --host "0.0.0.0" \
    --disable-telemetry
}
