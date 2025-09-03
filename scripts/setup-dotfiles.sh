#!/bin/bash
# Setup dotfiles script - run this after container starts
# This keeps the Docker image smaller and improves layer caching

set -euo pipefail

echo "Setting up dotfiles..."

# Ensure git is available (needed to clone dotfiles). Installation is handled in provisioning.
if ! command -v git >/dev/null 2>&1; then
    echo "git not found. Please ensure git is installed during provisioning." >&2
    exit 127
fi

# Check if dotfiles already exist
if [ -d "$HOME/.dotfiles" ]; then
    echo "Dotfiles already exist, updating..."
    cd "$HOME/.dotfiles"
    git pull
else
    echo "Cloning dotfiles..."
    git clone https://github.com/mikecuoco/cluster_dotfiles "$HOME/.dotfiles"
    cd "$HOME/.dotfiles"
    touch .extra
fi

# Remove .vimrc and symlink other dotfiles
rm -rf .vimrc
for file in .[^.]*; do 
    if [ -f "$file" ] && [ "$file" != ".git" ]; then
        echo "Linking $file"
        ln -sf "$(pwd)/$file" "$HOME/$file"
    fi
done

echo "Dotfiles setup complete!"
