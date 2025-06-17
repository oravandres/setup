#!/bin/bash

# Script to rename all .yml files to .yaml using git mv
# This preserves Git history for the renamed files

set -euo pipefail

echo "Starting YAML file renaming process..."
echo "Files to rename:"

while IFS= read -r file; do
  new_file="${file%.yml}.yaml"
  echo "  $file -> $new_file"
  
  # Use git mv to preserve history
  if git mv "$file" "$new_file"; then
    echo "    ✓ Successfully renamed"
  else
    echo "    ✗ Failed to rename"
    exit 1
  fi
done < files_to_rename.txt

echo ""
echo "All files renamed successfully!"
echo "Checking git status..."
git status --porcelain | grep "^R" | wc -l
echo "files were renamed." 