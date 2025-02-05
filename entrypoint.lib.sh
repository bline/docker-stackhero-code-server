#!/bin/bash
# entrypoint.lib.sh
# This library contains helper functions for the entrypoint script,
# including logging functions and common utility routines.
#

source /usr/local/bin/functions.lib.sh

CONFIG_DIR="${CONFIG_DIR:-/config}"
SUDOERS_DIR="${SUDOERS_DIR:-/etc/sudoers.d}"
CODE_SERVER_PATH="${CODE_SERVER_PATH:-/app/code-server/bin/code-server}"

###############################################################################
# Helper Functions
###############################################################################

# get_fly_env_vars:
#   Extracts environment variable keys from the [env] section of fly.toml.
#   Ignores commented/empty lines and strips quotes and extra whitespace.
get_fly_env_vars() {
  local fly_toml="$1"
  declare -A env_vars

  [[ -f "$fly_toml" ]] || return 0
  FLY_TOML="$fly_toml"
  extract_toml_section "env" env_vars

  for key in "${!env_vars[@]}"; do
    echo "$key"
  done
}


# get_env_vars_array:
#   Reads a file and extracts non-commented, non-empty environment variable names.
get_env_vars_array() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0

  awk '!/^#/ && NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print }' "$env_file"
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
      log_status "Configuring Git user: $(color_cyan "$GIT_USER")"
      git config --global user.name "${GIT_USER}"
    fi
    if ! git config --global user.email >/dev/null 2>&1; then
      log_status "Configuring Git email: $(color_cyan "$GIT_EMAIL")"
      git config --global user.email "${GIT_EMAIL}"
    fi
  else
    log_warning "Git user/email not set, skipping configuration."
  fi
}

get_combined_unique_vars() {
  local fly_vars=() extra_vars=()
  readarray -t fly_vars < <(get_fly_env_vars "${CONFIG_DIR}/fly.toml")
  readarray -t extra_vars < <(get_env_vars_array "${CONFIG_DIR}/extra_env.list")

  declare -A seen
  local -a vars_array=()
  for var in "${fly_vars[@]}" "${extra_vars[@]}"; do
    [[ -n "$var" && -z "${seen[$var]:-}" ]] || continue
    seen[$var]=1
    vars_array+=("$var")
  done
  printf '%s\n' "${vars_array[@]}"
}

# process_env_vars:
#   Reads environment variable names from configuration files,
#   deduplicates them, writes sudoers entries, and unset any env vars not configured.
process_env_vars() {

  # get variables that are configured to keep
  readarray -t vars_array < <(get_combined_unique_vars)
  echo "vars_array: ${vars_array[*]}"

  KEEP_VARS=("PATH" "HOME" "SHELL" "LOGNAME" "USER" "USERNAME" "TERM" "PWD" "_" "HOSTNAME")
  KEEP_VARS+=("${vars_array[@]}")

  # remove any exposed environment variables (including functions)
  # that aren't in KEEP_VARS
  for var in $(compgen -e); do
    # if var is NOT in KEEP_VARS, unset it
    if [[ ! " ${KEEP_VARS[*]} " =~ " $var " ]]; then
      log_status "unset \"$var\""
      unset "$var"
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

  # Preserve USER_NAME in a local variable before resetting environment
  local USER_TO_RUN="${USER_NAME}"
  local APP="${FLY_APP_NAME}"
  local APP_PORT="${PORT}"

  log_status "Clearing environment"
  process_env_vars

  log_status "Code-server will be accessible at: $(color_cyan "https://${APP}.fly.dev/")"
  exec sudo -E -u "${USER_TO_RUN}" bash --login -c  "exec \"${CODE_SERVER_PATH}\" \
    --bind-addr \"0.0.0.0:${APP_PORT}\" \
    --host \"0.0.0.0\" \
    --disable-telemetry
  "
}
