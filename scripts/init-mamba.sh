#!/usr/bin/env bash
set -euo pipefail

cat >> ~/.extra <<'EOT'
set +e
# Micromamba init for bash login shells
export MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-/opt/conda}"
export MAMBA_EXE="${MAMBA_EXE:-/usr/local/bin/micromamba}"
if command -v micromamba >/dev/null 2>&1; then
  eval "$(micromamba shell hook -s bash)" || true
  micromamba activate base >/dev/null 2>&1 || true
fi
set -e
EOT
