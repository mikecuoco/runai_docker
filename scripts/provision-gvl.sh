#!/usr/bin/env bash
set -euo pipefail

# Provision a base image with:
# - system packages + SSH
# - non-root user with sudo (or rename micromamba default user)
# - micromamba install (if missing)
# - GVL environment (lockfile-first)
# - dotfiles and shell activation

NEW_USER="${NEW_USER:-mcuoco}"
NEW_USER_ID="${NEW_USER_ID:-2022}"
NEW_USER_GID="${NEW_USER_GID:-2022}"
MAMBA_ROOT_PREFIX="${MAMBA_ROOT_PREFIX:-/opt/conda}"
MAMBA_EXE="${MAMBA_EXE:-/usr/local/bin/micromamba}"

export DEBIAN_FRONTEND=noninteractive

# System deps and SSH
APT_LIST_FILE="${APT_LIST_FILE:-/apt-packages.txt}"
if [ ! -f "$APT_LIST_FILE" ]; then
  echo "Apt package list not found at $APT_LIST_FILE" >&2
  exit 1
fi

apt-get update && \
  xargs -a "$APT_LIST_FILE" -r apt-get install -y --no-install-recommends && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

mkdir -p /var/run/sshd && chmod 755 /var/run/sshd

# Handle micromamba base user if present
if id -u "${MAMBA_USER:-}" >/dev/null 2>&1; then
  # Try to rename default micromamba user to NEW_USER to satisfy entrypoint checks
  if [ "${MAMBA_USER}" != "${NEW_USER}" ]; then
    usermod "--login=${NEW_USER}" "--home=/home/${NEW_USER}" --move-home "-u ${NEW_USER_ID}" "${MAMBA_USER}" || true
    groupmod "--new-name=${NEW_USER}" "-g ${NEW_USER_GID}" "${MAMBA_USER}" || true
    echo "${NEW_USER}" > /etc/arg_mamba_user || true
    echo "MAMBA_USER=${NEW_USER}" >> /etc/environment || true
    export MAMBA_USER="${NEW_USER}"
  fi
else
  # Create standard user
  if ! id -u "$NEW_USER" >/dev/null 2>&1; then
    groupadd -g "$NEW_USER_GID" "$NEW_USER"
    useradd -m -u "$NEW_USER_ID" -g "$NEW_USER_GID" -s /bin/bash "$NEW_USER"
  fi
fi

USER_PASSWORD="${USER_PASSWORD:-}"
if [ -z "$USER_PASSWORD" ] && [ -f /run/secrets/user_password ]; then
  USER_PASSWORD="$(cat /run/secrets/user_password)"
fi
if [ -z "$USER_PASSWORD" ]; then
  USER_PASSWORD="password"
fi
echo "$NEW_USER:$USER_PASSWORD" | chpasswd
usermod -aG sudo "$NEW_USER" || true
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

chown -R "$NEW_USER_ID":"$NEW_USER_GID" "/home/$NEW_USER" || true

# Micromamba
mkdir -p "$MAMBA_ROOT_PREFIX"
chown -R "$NEW_USER_ID":"$NEW_USER_GID" "$MAMBA_ROOT_PREFIX"
if ! command -v micromamba >/dev/null 2>&1; then
  curl -L -o /tmp/micromamba.tar.bz2 https://micro.mamba.pm/api/micromamba/linux-64/latest
  tar -xvj -C /usr/local/bin -f /tmp/micromamba.tar.bz2 bin/micromamba --strip-components=1
  rm -f /tmp/micromamba.tar.bz2
fi

# Install env (expects /tmp/env populated). Use external helper script.
cp /root/user_env_install.sh /tmp/user_env_install.sh

chown "$NEW_USER_ID":"$NEW_USER_GID" /tmp/user_env_install.sh
chmod +x /tmp/user_env_install.sh
su - "$NEW_USER" -c "bash /tmp/user_env_install.sh"

# Clean
"$MAMBA_EXE" clean --all --yes || true

# Dotfiles and shell activation (expects setup-dotfiles.sh in user's home)
cp /root/user_post_setup.sh /tmp/user_post_setup.sh

chown "$NEW_USER_ID":"$NEW_USER_GID" /tmp/user_post_setup.sh
chmod +x /tmp/user_post_setup.sh

# Ensure dotfiles setup script is available in the user's home directory
cp /root/setup-dotfiles.sh "/home/${NEW_USER}/setup-dotfiles.sh"
chown "$NEW_USER_ID":"$NEW_USER_GID" "/home/${NEW_USER}/setup-dotfiles.sh"
chmod +x "/home/${NEW_USER}/setup-dotfiles.sh"

su - "$NEW_USER" -c "bash /tmp/user_post_setup.sh"


