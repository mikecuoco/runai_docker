#!/bin/bash
# Simple conda-lock script: lock to linux-64 and save in same directory

set -e

usage() {
    echo "Usage: $0 <environment.yml>"
    echo ""
    echo "Generates a conda-lock file for linux-64 from the specified environment file."
    echo ""
    echo "Arguments:"
    echo "  <environment.yml>   Path to the conda environment YAML file."
    echo ""
    echo "Example:"
    echo "  $0 environments/gvl.yml"
    exit 1
}

if [[ "$1" == "-h" || "$1" == "--help" || $# -ne 1 ]]; then
    usage
fi

ENVIRONMENT_FILE="$1"

if ! command -v conda-lock &> /dev/null; then
    echo "conda-lock is not installed" >&2
    exit 1
fi

if [[ ! -f "$ENVIRONMENT_FILE" ]]; then
    echo "Environment file not found: $ENVIRONMENT_FILE" >&2
    exit 1
fi

LOCKFILE_NAME="$(dirname "$ENVIRONMENT_FILE")/$(basename "$ENVIRONMENT_FILE" .yml)-linux-64.lock"
echo "Generating conda-lock file for linux-64..."
conda-lock lock \
    --file "$ENVIRONMENT_FILE" \
    --lockfile "$LOCKFILE_NAME" \
    --platform linux-64 \
    --kind explicit

echo "✅ Generated: $LOCKFILE_NAME"

