#!/bin/bash

###############################################################################
# Load Logging & Utility Functions
###############################################################################
if [[ -f "./functions.lib.sh" ]]; then
  source "./functions.lib.sh"
else
  echo -e "$(tput setaf 1)ERROR: Must be run in bline-code-server root directory$(tput sgr0)" >&2
  exit 1
fi

FLY_TOML="${1:-fly.toml}"
shift
FLY_TOML_TEMPLATE="${1:-fly-template.toml}"

while read -r line || [[ -n "$line" ]]; do
  # Skip comments and empty lines
  if [[ $line == \#* || -z "$line" ]]; then
    continue
  fi

  # Evaluate the line to expand expressions
  eval "line=$line"

  # Export the variable
  export "$line"
done < .env

export BUILD_DATE=$(date +%Y-%m-%d)

cat "$FLY_TOML_TEMPLATE" | envsubst > "$FLY_TOML"

CAT="cat"
type -P batcat &> /dev/null
if [ $? -eq 0 ]; then
  CAT="batcat --paging=never --style=plain -f"
fi

log_status "Generated $FLY_TOML"
$CAT "$FLY_TOML"

echo
log_status "Ready to flyctl deploy! 🚀"
