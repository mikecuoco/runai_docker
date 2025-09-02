#!/usr/bin/env bash
set -euo pipefail

# Simplified provisioning script for base image
NEW_USER="${NEW_USER:-mcuoco}"
NEW_USER_ID="${NEW_USER_ID:-2022}"
NEW_USER_GID="${NEW_USER_GID:-2022}"
MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-/opt/conda}"
MAMBA_EXE="${MAMBA_EXE:-/usr/local/bin/micromamba}"

export DEBIAN_FRONTEND=noninteractive

# Install system packages
APT_LIST_FILE="${APT_LIST_FILE:-/apt-packages.txt}"
if [ -f "$APT_LIST_FILE" ]; then
  apt-get update && \
    xargs -a "$APT_LIST_FILE" -r apt-get install -y --no-install-recommends && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
fi

mkdir -p /var/run/sshd && chmod 755 /var/run/sshd

# Create or update user
if ! id -u "$NEW_USER" >/dev/null 2>&1; then
  groupadd -g "$NEW_USER_GID" "$NEW_USER"
  useradd -m -u "$NEW_USER_ID" -g "$NEW_USER_GID" -s /bin/bash "$NEW_USER"
fi

# Set password and sudo access
USER_PASSWORD="${USER_PASSWORD:-password}"
echo "$NEW_USER:$USER_PASSWORD" | chpasswd
usermod -aG sudo "$NEW_USER"
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

chown -R "$NEW_USER_ID":"$NEW_USER_GID" "/home/$NEW_USER"

# Setup micromamba
mkdir -p "$MAMBA_ROOT_PREFIX"
chown -R "$NEW_USER_ID":"$NEW_USER_GID" "$MAMBA_ROOT_PREFIX"
if ! command -v micromamba >/dev/null 2>&1; then
  curl -L -o /tmp/micromamba.tar.bz2 https://micro.mamba.pm/api/micromamba/linux-64/latest
  tar -xvj -C /usr/local/bin -f /tmp/micromamba.tar.bz2 bin/micromamba --strip-components=1
  rm -f /tmp/micromamba.tar.bz2
fi

# Install environment
cp /root/user_env_install.sh /tmp/user_env_install.sh
chown "$NEW_USER_ID":"$NEW_USER_GID" /tmp/user_env_install.sh
chmod +x /tmp/user_env_install.sh
su - "$NEW_USER" -c "bash /tmp/user_env_install.sh"

# Clean up
"$MAMBA_EXE" clean --all --yes || true

# Setup dotfiles
cp /root/setup-dotfiles.sh "/home/${NEW_USER}/setup-dotfiles.sh"
chown "$NEW_USER_ID":"$NEW_USER_GID" "/home/${NEW_USER}/setup-dotfiles.sh"
chmod +x "/home/${NEW_USER}/setup-dotfiles.sh"

cp /root/user_post_setup.sh /tmp/user_post_setup.sh
chown "$NEW_USER_ID":"$NEW_USER_GID" /tmp/user_post_setup.sh
chmod +x /tmp/user_post_setup.sh
su - "$NEW_USER" -c "bash /tmp/user_post_setup.sh"


