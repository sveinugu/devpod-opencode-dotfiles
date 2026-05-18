#!/bin/zsh

# Handle .bashrc
# Use -f to force overwrite the default devcontainer .zshrc
ln -sf $(pwd)/.zshrc ~/.zshrc

# Install oh-my-zsh theme and plugins
git clone https://github.com/reobin/typewritten ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/typewritten
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Handle OpenCode config
# Create the .config directory if it doesn't exist
mkdir -p ~/.config

# Symlink your OpenCode folder from the repo to the expected location
# -s = symlink, -f = force, -n = treat folder symlink as a file
rm -rf ~/.config/opencode
ln -sfn $(pwd)/.config.opencode ~/.config/

echo "✅ Dotfiles applied: .zshrc and OpenCode config linked."

