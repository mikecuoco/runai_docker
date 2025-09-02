#!/usr/bin/env bash
set -euo pipefail

NEW_USER="${NEW_USER:-mcuoco}"
NEW_USER_ID="${NEW_USER_ID:-2022}"
NEW_USER_GID="${NEW_USER_GID:-2022}"
USER_PASSWORD="${USER_PASSWORD:-password}"

if ! id -u "$NEW_USER" >/dev/null 2>&1; then
  groupadd -g "$NEW_USER_GID" "$NEW_USER"
  useradd -m -u "$NEW_USER_ID" -g "$NEW_USER_GID" -s /bin/bash "$NEW_USER"
fi

echo "$NEW_USER:$USER_PASSWORD" | chpasswd
usermod -aG sudo "$NEW_USER"
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
chown -R "$NEW_USER_ID":"$NEW_USER_GID" "/home/$NEW_USER"
