#!/usr/bin/env bash
set -euo pipefail

cd /tmp/env
if [ -f gvl-linux-64.lock ]; then
  echo "Using lockfile: gvl-linux-64.lock"
  micromamba install --name base --yes --file gvl-linux-64.lock
else
  echo "Falling back to YAML: gvl.yml"
  micromamba install --name base --yes --file gvl.yml
fi


