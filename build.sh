#!/bin/bash

if [ ! -f ".env" ]; then
  echo "You must create a .env file first. See .env.example file for a starting point"
  exit 1
fi

while read -r line; do
  # Skip comments and empty lines
  if [[ $line == \#* || -z "$line" ]]; then
    continue
  fi

  # Evaluate the line to expand expressions
  eval "line=$line"

  # Export the variable
  export "$line"
done < .env

cat fly-template.toml | envsubst > fly.toml

CAT="cat"
type -P batcat &> /dev/null
if [ $? -eq 0 ]; then
  CAT="batcat --paging=never --style=plain -f"
fi

echo "Generated fly.toml"
$CAT fly.toml

echo
echo "Ready to flyctl deploy! 🚀"
