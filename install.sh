#!/bin/zsh

# Handle .bashrc
# Use -f to force overwrite the default devcontainer .zshrc
ln -sf $(pwd)/.zshrc ~/.zshrc

# Install oh-my-zsh theme and plugins
# Define the custom directory
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

# Function to clone if directory doesn't exist
install_plugin() {
    local repo_url=$1
    local dest_path=$2
    if [ ! -d "$dest_path" ]; then
        echo "Installing $(basename "$dest_path")..."
        git clone "$repo_url" "$dest_path"
    else
        echo "$(basename "$dest_path") already installed, skipping."
    fi
}

# Install Theme
install_plugin "https://github.com" "$ZSH_CUSTOM/themes/typewritten"

# Install Plugins
install_plugin "https://github.com" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
install_plugin "https://github.com" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

# Handle OpenCode config
# Create the .config directory if it doesn't exist
mkdir -p ~/.config

# Symlink your OpenCode folder from the repo to the expected location
# -s = symlink, -f = force, -n = treat folder symlink as a file
rm -rf ~/.config/opencode
ln -sfn $(pwd)/.config/opencode ~/.config/

echo "✅ Dotfiles applied: .zshrc and OpenCode config linked."

