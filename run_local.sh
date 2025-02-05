#!/bin/bash
set -euo pipefail

OUTPUT_LOG="/tmp/fly-code-server_run_local-$(date +%Y%m%d_%H%M%S).log"
OUTPUT_LOG_COLOR=$(mktemp)
#
###############################################################################
# Load Logging & Utility Functions
###############################################################################
if [[ -f "./functions.lib.sh" ]]; then
  source "./functions.lib.sh"
else
  echo -e "$(tput setaf 1)ERROR: Must be run in bline-code-server root directory$(tput sgr0)" >&2
  exit 1
fi

echo -e "$(color_blue " ===== Log file: ") $(color_cyan "$OUTPUT_LOG") $(color_blue "=====")"
echo

# save a copy of output in color for tmux, save a copy without color for debugging
# and still output to the user
exec > >(tee >(tee "$OUTPUT_LOG_COLOR" >/dev/null) >(sed 's/\x1b\[[0-9;]*m//g' >> "$OUTPUT_LOG"))

non_interactive=false
no_tmux=false

while getopts ":tn-:" opt; do
  case "${opt}" in
    n) non_interactive=true; shift ;;
    t) no_tmux=true; shift ;;
    -)
      case "${OPTARG}" in
        non-interactive) non_interactive=true; shift ;;
        no-tmux) no_tmux=true; shift ;;
        *) echo "Invalid option: --${OPTARG}" >&2; exit 1 ;;
      esac
      ;;
    *) echo "Usage: $0 [-n|--non-interactive][-t|--no-tmux]" >&2; exit 1 ;;
  esac
done

if [ "$non_interactive" = true ]; then
    log_status "Running in non-interactive mode"
fi


prompt() {
  local prompt="${1:-Hit enter to continue, ctrl+c to stop}"
  local post_prompt="${2:-"$(color_green "continuing")"}"
  if [ "$non_interactive" = false ]; then
    echo
    echo -e "$prompt"
    read
    echo -e "$post_prompt"
  fi
}

CAT="cat"
type -P batcat &> /dev/null
if [ $? -eq 0 ]; then
  CAT="batcat --paging=never --style=plain -f --language bash"
fi

add_docker_env() {
  local key="$1"
  local value="$2"
  log_status "Adding '$key' to docker env"
  if [[ -f "$ENV_FILE" ]] then
    echo "$key=$value" >> "$ENV_FILE"
  else
    echo "$key=$value" > "$ENV_FILE"
  fi
}

cmd_tmux() {
  if [ "$no_tmux" = false ]; then
    log_status "Run command: $(echo "$*" | $CAT)"
    prompt "Hit enter to run this command or Ctrl+c to exit" "$(color_green "running!")"
    if ! run_in_tmux "$OUTPUT_LOG_COLOR" "$@"; then
      log_error "$1 command failed. See log file listed above"
    fi
  else
    cmd "$@"
  fi
}

cmd() {
  log_status "Run command $(echo "$*" | $CAT)"
  prompt "Hit enter to run this command or Ctrl+c to exit" "$(color_green "running!")"
  local out_log="$(pwd)/fly-code-server_${1}-${2}-$(date +%Y%m%d_%H%M%S).log"
  if ! $* 2>&1 | tee >(sed -E 's/\x1B\[[0-9;]*[mK]//g' >> "$out_log"); then
    log_error "$(color_yellow "$1 $2") command failed. See log file $(color_cyan "$out_log")"
  else
    rm -f "$out_log"
  fi
}

log_head "Checking environment"
# Ensure Bash 4.3 or newer
log_status "Checking bash version"
assert_bash_version "4.3"

# Ensure tmux 3.2 or newer
if [ "$no_tmux" = false ]; then
  log_status "Checking tmux version"
  assert_tmux_version "3.2"
fi

###############################################################################
# Securely Capture Password Input
###############################################################################
if [[ -z "${CODE_SERVER_PASSWORD:-}" ]]; then
  CODE_SERVER_PASSWORD="$(read_password 'code-server login password: ')"
fi
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  GITHUB_TOKEN="$(read_password 'Github Token: ')"
fi

# Create a temporary environment file to store the password securely
ENV_FILE=$(mktemp)
chmod 600 "$ENV_FILE"  # Restrict file permissions


# Ensure cleanup runs on script exit (including Ctrl+C)
cleanup() {
  echo
  log_status "Cleanup: Removing temp files"
  rm -f "$ENV_FILE"
  rm -f "$OUTPUT_LOG_COLOR"
}
trap cleanup EXIT  # Triggers cleanup even if the script is interrupted

###############################################################################
# Load Configuration from fly.toml
###############################################################################

# Get the first argument as the fly.toml file, defaulting to "fly.toml"
FLY_TOML="${1:-fly.toml}"

# Always build a fresh copy
if ! ./build.sh "$FLY_TOML" >/dev/null 2>&1; then
  log_error "Failed to build $FLY_TOML"
fi
if [[ ! -f "$FLY_TOML" ]]; then
  log_error "File '$FLY_TOML' not found!"
  exit 1
fi

log_head "Parsing fly.toml: $FLY_TOML"


# Extract key configuration values
APP_NAME=$(extract_toml_value "app")
log_status "extracted app='$APP_NAME'"
if [[ -z "$APP_NAME" ]]; then
  log_error "app setting in $FLY_TOML is required"
  exit 1
fi
IMAGE_NAME="${APP_NAME}:local"
DOCKERFILE=$(extract_toml_value "build.dockerfile")
log_status "extracted build.dockerfile='$DOCKERFILE'"
INTERNAL_PORT=$(extract_toml_value "http_service.internal_port")
log_status "extracted http_service.internal_port='$INTERNAL_PORT'"

# Extract volume mount details
MOUNT_SOURCE=$(extract_toml_value "mounts.source")
log_status "extracted mounts.source='$MOUNT_SOURCE'"
MOUNT_DEST=$(extract_toml_value "mounts.destination")
log_status "extracted mounts.destination='$MOUNT_DEST'"

###############################################################################
# Build Docker Image
###############################################################################
log_head "Building Docker Image: $IMAGE_NAME"
log_status "Using Dockerfile: $DOCKERFILE"

# Extract and format Docker build arguments
declare -A BUILD_ARGS
extract_toml_section "build.args" BUILD_ARGS

DOCKER_BUILD_ARGS=""
for key in "${!BUILD_ARGS[@]}"; do
  DOCKER_BUILD_ARGS+=" --build-arg ${key}=${BUILD_ARGS[$key]}"
done

log_status "Build args: ${!BUILD_ARGS[*]}"

# Ensure BuildKit is enabled
export DOCKER_BUILDKIT=1

# Use buildx if available, fallback to normal build
if docker buildx version >/dev/null 2>&1; then
  log_status "Using Docker BuildKit (buildx)..."
  BUILD_CMD="docker buildx build --progress=auto"
else
  log_warning "BuildKit not available! Falling back to legacy build."
  BUILD_CMD="docker build"
fi

# Run Docker build
cmd_tmux $BUILD_CMD -t "$IMAGE_NAME" -f "$DOCKERFILE" $DOCKER_BUILD_ARGS .

log_status "Build complete."

###############################################################################
# Prepare & Run the Docker Container
###############################################################################
log_head "Running the container"

# Extract and format environment variables for docker run
declare -A ENV_VARS
extract_toml_section "env" ENV_VARS



if [[ -n "$CODE_SERVER_PASSWORD" ]]; then
  add_docker_env "PASSWORD" "$CODE_SERVER_PASSWORD"
fi
if [[ -n "$GITHUB_TOKEN" ]]; then
  add_docker_env "GITHUB_TOKEN", "$GITHUB_TOKEN"
fi
add_docker_env "FLY_APP_NAME" "$APP_NAME"

for key in "${!ENV_VARS[@]}"; do
  add_docker_env "$key" "${ENV_VARS[$key]}"
done


log_status "Environment variables: ${!ENV_VARS[*]}"
log_status "Exposing port: $INTERNAL_PORT"
log_status "Mounting: $MOUNT_SOURCE -> $MOUNT_DEST"
log_status "Will be available on http://localhost:$INTERNAL_PORT 🚀"

# Run the container in interactive mode
cmd docker run -it --rm \
  --name "$APP_NAME" \
  -p "$INTERNAL_PORT:$INTERNAL_PORT" \
  -v "$MOUNT_SOURCE:$MOUNT_DEST" \
  --env-file "$ENV_FILE" \
  "$IMAGE_NAME"
