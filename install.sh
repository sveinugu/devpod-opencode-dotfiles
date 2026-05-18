#!/bin/zsh

# 1. Handle .bashrc
# Use -f to force overwrite the default devcontainer .zshrc
ln -sf $(pwd)/.zshrc ~/.zshrc


# 2. Handle OpenCode config
# Create the .config directory if it doesn't exist
mkdir -p ~/.config

# Symlink your OpenCode folder from the repo to the expected location
# -s = symlink, -f = force, -n = treat folder symlink as a file
rm -rf ~/.config/opencode
ln -sfn $(pwd)/.config.opencode ~/.config/

echo "✅ Dotfiles applied: .zshrc and OpenCode config linked."

