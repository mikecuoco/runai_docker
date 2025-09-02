#!/bin/bash
# Simple conda-lock script: lock to linux-64 and save in same directory
set -e

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <environment.yml> [extra arguments]"
    exit 1
fi

ENVIRONMENT_FILE="$1"
EXTRA_ARGS="${@:2}"
# Check dependencies
if ! command -v conda-lock &> /dev/null; then
    echo "Error: conda-lock is not installed" >&2
    exit 1
fi

if [[ ! -f "$ENVIRONMENT_FILE" ]]; then
    echo "Error: Environment file not found: $ENVIRONMENT_FILE" >&2
    exit 1
fi

LOCKFILE_NAME="$(dirname "$ENVIRONMENT_FILE")/$(basename "$ENVIRONMENT_FILE" .yml)-linux-64.lock"
echo "Generating conda-lock file for linux-64..."
# Show the arguments
echo "Extra arguments: $EXTRA_ARGS"

conda-lock lock \
    --file "$ENVIRONMENT_FILE" \
    --lockfile "$LOCKFILE_NAME" \
    --platform linux-64 \
    --kind explicit \
    $EXTRA_ARGS

echo "✅ Generated: $LOCKFILE_NAME"

