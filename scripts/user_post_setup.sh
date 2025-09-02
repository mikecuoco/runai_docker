#!/usr/bin/env bash
set -euo pipefail

chmod +x ~/setup-dotfiles.sh || true
cd ~ && ./setup-dotfiles.sh

cat >> ~/.extra <<'EOT'
set +e
export MAMBA_USER=${NEW_USER}
export MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX}
export MAMBA_EXE=${MAMBA_EXE}
eval "$(micromamba shell hook -s bash)"
micromamba activate base
EOT


