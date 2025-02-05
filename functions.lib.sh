#!/bin/bash
# functions.lib.sh
# This library contains helper functions for the entrypoint script,
# including logging functions and common utility routines.
#

###############################################################################
# Utility Functions
###############################################################################

read_password()
{
  local prompt="${1:-Enter your password: }"
  local password=""
  local char=""

  # Print prompt and force it to display immediately
  echo -n "$prompt" >&2
  flush_stdout

  while IFS= read -r -s -n 1 char; do
    if [[ -z $char ]]; then
      break # Enter key pressed
    elif [[ $char == $'\177' ]]; then
      # Handle backspace (ASCII 127)
      if [[ -n $password ]]; then
        password="${password%?}"
        printf '\b \b' >&2 # Move cursor back, erase character, move back again
      fi
    else
      password+="$char"
      printf '*' >&2
    fi
  done
  echo "" >&2 # Move to a new line

  echo "$password"
}

# Ensures prompt is shown immediately
flush_stdout()
{
  [[ -t 1 ]] && {
    sleep 0.01
  }
}

# Function to extract values from fly.toml
extract_toml_value()
{
  local key_input="$1"
  local section=""
  local key=""
  local file="${FLY_TOML:-/config/fly.toml}"

  # Check if the key contains a dot (.) to determine if it's sectioned
  if [[ $key_input == *.* ]]; then
    section="${key_input%.*}" # Extract section name (everything before the last dot)
    key="${key_input##*.}"    # Extract key name (everything after the last dot)
  else
    key="$key_input" # No section, treat as top-level key
  fi

  # Ensure the TOML file exists.
  if [[ ! -f $file ]]; then
    log_error "TOML file '$(color_yellow "$file")' not found."
    exit 1
  fi

  local value

  if [[ -z $section ]]; then
    # Extract key from the top (before any section header appears)
    value=$(awk -v key="$key" '
      BEGIN { }
      # Stop if a section header is encountered.
      /^\s*\[.*\]\s*$/ { exit }
      # Match a line that begins with the key followed by an "="
      $0 ~ "^[[:space:]]*"key"[[:space:]]*=" {
        # Remove everything up to and including the "=" and print the rest.
        sub(/^[^=]*=[[:space:]]*/, "", $0)
        print
        exit
      }
    ' "$file")
  else
    # Extract key from within a specific section.
    value=$(awk -v section="$section" -v key="$key" '
      BEGIN { in_section = 0 }
      # When a section header is encountered:
      /^\s*\[.*\]\s*$/ {
        # If this is the desired section header, start capturing.
        if ($0 ~ ("\\[" section "\\]")) {
          in_section = 1
          next
        }
        # If we were in the section and now hit a different section, stop.
        if (in_section == 1) exit
      }
      # If inside the desired section, look for the key.
      in_section == 1 && $0 ~ "^[[:space:]]*"key"[[:space:]]*=" {
        sub(/^[^=]*=[[:space:]]*/, "", $0)
        print
        exit
      }
    ' "$file")
  fi

  # Process the extracted value:
  # 1. Trim leading/trailing whitespace.
  # 2. If the value is quoted, remove the surrounding quotes and ignore any trailing comment.
  # 3. Otherwise, remove any trailing comment (a hash "#" preceded by whitespace).
  value="$(echo "$value" | sed -E '
    s/^[[:space:]]*//;
    s/[[:space:]]*$//;
    /^["'"'"']/ {
      # If the line starts with a quote, capture whats inside quotes and ignore trailing comments.
      s/^([\"'"'"'])(.*)\1.*$/\2/;
      b done
    }
    # For unquoted values, remove trailing inline comments.
    s/[[:space:]]+#.*$//
    :done
  ')"

  echo "$value"
}

extract_toml_section()
{
  local fly_toml="${FLY_TOML:-/config/fly.toml}" # Default file
  local section="$1"
  declare -n result_array="$2" # Use nameref for reference passing

  if [[ ! -f $fly_toml ]]; then
    echo "Error: TOML file '$fly_toml' not found!" >&2
    return 1
  fi

  # Ensure the result array is empty before filling it
  result_array=()

  # Extract section key-value pairs
  while IFS='=' read -r key value; do
    [[ -z $key || $key =~ ^# ]] && continue    # Skip empty and commented lines
    key=$(echo "$key" | xargs)                 # Trim spaces
    value=$(echo "$value" | tr -d '"' | xargs) # Remove quotes

    result_array["$key"]="$value" # Store in referenced array
  done < <(awk -v section="$section" '
    /^\[+[^]]+\]+/ { in_section=($0 ~ "\\[+" section "\\]+") }
    in_section && /^[^#]+=/ { print }
  ' "$fly_toml")
}

###############################################################################
# Logging Functions
###############################################################################
log_head()
{
  echo
  color_blue "==== $* ===="
  echo
}

log_status()
{
  echo -e "  $(color_green '*') $*"
}

log_error()
{
  echo -e "$(color_red 'ERROR:') $*" >&2
}

log_warning()
{
  echo -e "  $(color_yellow '* Warning:') $*" >&2
}

color_red()
{
  echo -e "$(tput setaf 1)$*$(tput sgr0)"
}

color_green()
{
  echo -e "$(tput setaf 2)$*$(tput sgr0)"
}

color_yellow()
{
  echo -e "$(tput setaf 3)$*$(tput sgr0)"
}

color_blue()
{
  echo -e "$(tput setaf 4)$*$(tput sgr0)"
}

color_magenta()
{
  echo -e "$(tput setaf 5)$*$(tput sgr0)"
}

color_cyan()
{
  echo -e "$(tput setaf 6)$*$(tput sgr0)"
}

assert_bash_version()
{
  local required_version="${1:-4.3}" # Default to 4.3 if no argument is provided

  # Split required_version into major and minor parts
  local required_major="${required_version%%.*}" # Extract major version (before the dot)
  local required_minor="${required_version#*.}"  # Extract minor version (after the dot)

  if [[ ${BASH_VERSINFO[0]} -lt $required_major ||
    (${BASH_VERSINFO[0]} -eq $required_major && ${BASH_VERSINFO[1]} -lt $required_minor) ]]; then
    log_error "This script requires Bash $(color_cyan "${required_major}.${required_minor}") or newer."
    log_error "You are using Bash $(color_yellow "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}")"
    exit 1
  fi
}

assert_tmux_version()
{
  local min_version="${1:-3.2}" # Default to "3.2" if no argument is passed
  local version_str major minor min_major min_minor

  local required_major="${min_version%%.*}" # Extract major version (before the dot)
  local required_minor="${min_version#*.}"  # Extract minor version (after the dot)
  # Check if tmux is installed
  if ! command -v tmux &>/dev/null; then
    log_error "$(color_yellow "tmux") is not installed. Please install tmux $(color_cyan "$min_version+") and try again."
    exit 1
  fi

  # Extract installed tmux version (e.g., "tmux 3.2" -> "3.2")
  version_str=$(tmux -V | awk '{print $2}')

  # Extract major and minor versions from installed tmux
  IFS='.' read -r major minor <<<"$version_str"

  # Ensure minor versions are treated correctly (default to 0 if missing)
  minor=${minor:-0}
  min_minor=${min_minor:-0}

  # Compare versions
  if [ "$major" -lt "$required_major" ] || {
    [ "$major" -eq "$required_major" ] && [ "$minor" -lt "$required_minor" ]
  }; then
    log_error "tmux version $(color_cyan "$min_version+") required, but found $(color_yellow "$version_str")."
    exit 1
  fi
}

create_tail_script()
{
  local tmpfile="$1"

  cat <<'EOF' >"$tmpfile"
#!/usr/bin/env bash

# Ensure a log file argument is provided
if [[ -z "$1" || ! -f "$1" ]]; then
  echo "Usage: $0 <log_file>"
  exit 1
fi

log_file="$1"

# Hide cursor
tput civis

# Function to update terminal size
update_terminal_size() {
  rows=$(tput lines)
  cols=$(tput cols)
}

# Capture terminal size initially
update_terminal_size

# Start timer (in seconds with nanoseconds)
start_time=$(date +%s.%N)

sleep 0.5

# Handle terminal resize
trap update_terminal_size SIGWINCH

# Function to format elapsed time dynamically with milliseconds
format_time() {
  local now=$(date +%s.%N)
  local elapsed=$(echo "$now - $start_time" | bc)

  local total_seconds=${elapsed%.*}  # Get whole seconds
  local milliseconds=$(echo "$elapsed * 1000" | bc | cut -d'.' -f1 | tail -c 4)  # Get last 3 digits

  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  local formatted_time=""

  if ((hours > 0)); then
    formatted_time="${hours}h "
  fi
  if ((minutes > 0 || hours > 0)); then
    formatted_time+="${minutes}m "
  fi
  formatted_time+="${seconds}.${milliseconds}s"

  echo -n "$formatted_time"
}

# Function to update the timer **without printing extra lines**
update_timer() {
  last_timer_text=""

  while true; do
    sleep 0.01  # 10ms delay for better precision

    # Get the formatted timer text
    timer_text=$(format_time)

    # Prevent unnecessary prints (only update when the text changes)
    if [[ "$timer_text" != "$last_timer_text" ]]; then
      # Update terminal size dynamically
      update_terminal_size

      # Move cursor to bottom-right **only if there's text to update**
      tput sc  # Save cursor position
      tput cup $((rows - 1)) $((cols - ${#timer_text} - 1))  # Adjust dynamically
      echo -ne "$timer_text "  # Print with padding
      tput rc  # Restore cursor position

      last_timer_text="$timer_text"
    fi
  done
}

# Start timer in the background
update_timer &

# Capture the PID of the timer process
timer_pid=$!

# Run tail -f on the specified log file
tail -f "$log_file"

# Cleanup when script exits
trap "kill $timer_pid; tput cnorm; exit" SIGINT SIGTERM

EOF

  chmod +x "$tmpfile"
}

run_in_tmux()
{
  local log_file="$1" # 1) The file we tail in the top pane
  shift
  local command_name="$1" # 2) The 'name' used in the log file
  shift                   # The rest of the args will be the actual command to run

  # We'll build a log file named like:
  #   /tmp/fly-code-server_<COMMAND_NAME>-YYYYmmdd_HHMMSS.log
  local out_log codefile session_name
  local -a cmd
  local -i ret
  out_log="$(pwd)/fly-code-server_${command_name}-$1-$(date +%Y%m%d_%H%M%S).log"

  # We'll store the exit code from the bottom command here:
  codefile="/tmp/tmux_cmd_exit_$$"

  # store a temporary script for the tail command
  tail_script="$(mktemp)"
  create_tail_script "$tail_script"

  # A unique tmux session name
  session_name="tmux_session_$$"

  # Empty out the file (or create it)
  : >"$codefile"

  # Create a new DETACHED tmux session
  tmux new-session -d -s "$session_name"

  # Top pane: run tail -f on the given log_file
  tmux send-keys -t "$session_name:0.0" "clear && $tail_script \"$log_file\"" C-m

  # Prevent leftover "[exited]" if possible (though some tmux versions still show it briefly)
  tmux set-window-option -t "${session_name}:0" remain-on-exit off

  # Resize automatically if the terminal changes size
  tmux set-option -t "$session_name" aggressive-resize on

  # disable the tmux status bar
  tmux set-option -t "$session_name" status off

  # disable pane borders
  tmux set-option -t "$session_name" pane-active-border-style none
  tmux set-option -t "$session_name" pane-border-style none

  # Split the window horizontally, creating the bottom pane
  tmux split-window -v -t "$session_name:0"

  # Resize the bottom pane to 50% of current terminal height
  tmux resize-pane -t "$session_name:0.1" -y "$(($(tput lines) / 2))"

  # If the tmux window is resized, re-resize the bottom pane
  tmux set-hook -g -t "$session_name" window-layout-changed \
    "run-shell \"tmux resize-pane -t '$session_name:0.1' -y \$(($(tput lines) / 2))\""

  # Remaining arguments form the actual command to run
  cmd=("$command_name" "$@")

  # Build a small script in /tmp that runs the bottom command:
  #   ( cmd ) 2>&1 | tee >(sed 's/\e\[[0-9;]*[mK]//g' >> out_log)
  #   rc=$?
  #   echo $rc > codefile
  #   tmux kill-session ...
  #
  # We'll insert a literal ESC via $'\033' in the sed pattern.
  tmp_script="/tmp/tmux_bottom_cmd_$$.sh"

  # Clean up our temporary script
  function cleanup()
  {
    rm -f "$tmp_script"
    rm -f "$tail_script"
  }
  trap cleanup SIGINT SIGTERM EXIT

  cat <<'EOF' >"$tmp_script"
#!/usr/bin/env bash
out_log="$1"
shift
session_name="$1"
shift
codefile="$1"
shift
( "$@" ) 2>&1 | tee >(sed "s/$(printf '\033')\\[[0-9;]*[a-zA-Z]//g" >> "$out_log")
rc=$?
echo "$rc" > "$codefile"
tmux kill-session -t "$session_name"
EOF

  chmod +x "$tmp_script"

  # In the bottom pane, run this script
  local keys
  keys="$tmp_script $(printf '%q ' "$out_log" "$session_name" "$codefile" "${cmd[@]}")"
  tmux send-keys -t "$session_name:0.1" "$keys" C-m

  # Attach to the session (blocks until 'tmux kill-session' is called)
  tmux attach -t "$session_name"

  # Once we return here, tmux is done. Retrieve the exit code from $codefile.
  ret=1
  if [[ -f $codefile ]]; then
    # Must be numeric; if not, default to 1
    if grep -Eq '^[0-9]+$' "$codefile"; then
      ret=$(<"$codefile")
    fi
    rm -f "$codefile"
  fi

  cleanup

  if [ $ret -ne 0 ]; then
    log_error "See log file $(color_cyan "$out_log")"
  else
    rm -f "$out_log"
  fi

  return $ret
}
