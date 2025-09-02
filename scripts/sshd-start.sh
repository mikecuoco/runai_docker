#!/usr/bin/env bash
set -euo pipefail

# Ensure runtime dir exists
mkdir -p /var/run/sshd

# Generate host keys if missing (do not bake into image)
ssh-keygen -A >/dev/null 2>&1 || true

# Start sshd in the foreground
exec /usr/sbin/sshd -D