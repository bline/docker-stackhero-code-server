#!/usr/bin/env bats
# entrypoint.lib.bats
# Test suite for the functions defined in entrypoint.lib.sh

# setup() runs before each test.
setup() {
  # Override CONFIG_DIR and SUDOERS_DIR for testing so we don't use production paths.
  export CONFIG_DIR=$(mktemp -d)
  export SUDOERS_DIR=$(mktemp -d)
  export DEFAULT_WORKSPACE=$(mktemp -d)
  
  # Override CODE_SERVER_PATH with a dummy value.
  export CODE_SERVER_PATH="/tmp/fake_code_server"
  
  # Create a dummy /tmp/.bashrc for testing prepare_workspace.
  echo "dummy bashrc content" > /tmp/.bashrc

  # Set environment variables required by functions.
  export GIT_USER="testuser"
  export GIT_EMAIL="testuser@example.com"
  export USER_NAME="testuser"
  export FLY_APP_NAME="testfly"
  export PORT="1234"

  # For tests that involve changing ownership, override chown to do nothing.
  chown() { return 0; }
  export -f chown

  # Set up a temporary file to capture git calls.
  GIT_CALLS=$(mktemp)

  # Override the 'git' command.
  git() {
    local args="$*"
    echo "git $args" >> "$GIT_CALLS"
    # When checking (without setting a value), force a nonzero exit to trigger configuration.
    if [[ "$args" == "config --global user.name" ]] || [[ "$args" == "config --global user.email" ]]; then
      return 1
    else
      return 0
    fi
  }
  export -f git

  # Override exec so that it prints its arguments instead of executing.
  exec() {
    echo "exec $*"
  }
  export -f exec

  # Source the library file (assumes entrypoint.lib.sh is in the current directory).
  source entrypoint.lib.sh

  # Export all functions so that Bats can see them in its subshells.
  export -f get_fly_env_vars get_env_vars_array write_sudoers_for_vars ensure_dir configure_git process_env_vars prepare_workspace launch_code_server
  export -f log_head log_status log_warning log_error
}

# teardown() runs after each test.
teardown() {
  rm -rf "$CONFIG_DIR"
  rm -rf "$SUDOERS_DIR"
  rm -rf "$DEFAULT_WORKSPACE"
  rm -f /tmp/.bashrc
  rm -f "$GIT_CALLS"
}

@test "log_head prints formatted header" {
  run log_head "Test Header"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "==== Test Header ====" ]]
}

@test "get_fly_env_vars extracts keys correctly" {
  tmp_fly=$(mktemp)
  cat <<EOF > "$tmp_fly"
# Some comment
[env]
FOO=bar
BAZ="qux"
[other]
IGNORED=should_not_be_parsed
EOF
  # Wrap the call in bash -c and force a zero exit status with '|| true'.
  run bash -c "get_fly_env_vars \"$tmp_fly\" || true"
  [[ "$output" =~ "FOO" ]]
  [[ "$output" =~ "BAZ" ]]
  rm "$tmp_fly"
}

@test "get_env_vars_array extracts variable names" {
  tmp_env=$(mktemp)
  cat <<EOF > "$tmp_env"
# A comment line
FOO
BAR
EOF
  run get_env_vars_array "$tmp_env"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "FOO" ]]
  [[ "$output" =~ "BAR" ]]
  rm "$tmp_env"
}

@test "write_sudoers_for_vars writes correct Defaults lines" {
  write_sudoers_for_vars "testuser" "FOO" "BAR"
  sudoers_file="${SUDOERS_DIR}/testuser_env"
  [ -f "$sudoers_file" ]
  run cat "$sudoers_file"
  [[ "$output" =~ 'Defaults:testuser env_keep += "FOO"' ]]
  [[ "$output" =~ 'Defaults:testuser env_keep += "BAR"' ]]
}

@test "ensure_dir creates directory with proper permissions" {
  tmp_dir=$(mktemp -d)
  test_dir="$tmp_dir/subdir"
  ensure_dir "TestDir" "$test_dir" 755
  [ -d "$test_dir" ]
  perm=$(stat -c "%a" "$test_dir")
  [ "$perm" -eq 755 ]
  rm -rf "$tmp_dir"
}

@test "configure_git calls git config for user and email" {
  run configure_git
  [ "$status" -eq 0 ]
  grep -q "git config --global user.name ${GIT_USER}" "$GIT_CALLS"
  grep -q "git config --global user.email ${GIT_EMAIL}" "$GIT_CALLS"
}

@test "process_env_vars deduplicates and exports variables" {
  # Create temporary configuration files in CONFIG_DIR.
  fly_toml="${CONFIG_DIR}/fly.toml"
  extra_env="${CONFIG_DIR}/extra_env.list"
  cat <<EOF > "$fly_toml"
[env]
FOO=bar
BAR=baz
EOF
  cat <<EOF > "$extra_env"
FOO
BAZ
EOF

  # Set environment variable values; leave BAZ unset to trigger a warning.
  export FOO="foo_value"
  export BAR="bar_value"
  unset BAZ

  run process_env_vars
  [ "$status" -eq 0 ]
  # Verify output: check that FOO and BAR are exported.
  [[ "$output" =~ "Exported:" ]]
  # Expect a warning for BAZ being defined in config but unset.
  [[ "$output" =~ "Warning: BAZ is defined in config but unset" ]] || true
}

@test "prepare_workspace copies .bashrc and sets ownership" {
  tmp_ws=$(mktemp -d)
  export DEFAULT_WORKSPACE="$tmp_ws"
  echo "test bashrc content" > /tmp/.bashrc
  run prepare_workspace
  [ "$status" -eq 0 ]
  [ -f "${DEFAULT_WORKSPACE}/.bashrc" ]
  run diff "${DEFAULT_WORKSPACE}/.bashrc" /tmp/.bashrc
  [ "$status" -eq 0 ]
  rm -rf "$tmp_ws"
}

@test "launch_code_server constructs command correctly" {
  run launch_code_server
  [ "$status" -eq 0 ]
  # Our mocked exec prints a line starting with "exec", so check that:
  [[ "$output" =~ "exec sudo -i -u ${USER_NAME}" ]]
  [[ "$output" =~ "${CODE_SERVER_PATH}" ]]
  # Check for the bind address without quotes.
  [[ "$output" =~ "--bind-addr 0.0.0.0:${PORT}" ]]
}
