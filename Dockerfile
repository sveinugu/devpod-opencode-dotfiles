FROM mcr.microsoft.com/devcontainers/python:3

# Prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
# 2. Add NodeSource GPG key and repository
# 3. Install Node.js
RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && mkdir -p /etc/apt/extra-sources.list.d \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://nodesource.com nodistro main" | tee /etc/apt/extra-sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs npm \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install additional packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends direnv emacs gh ripgrep \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install 'uv' globally
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV SHELL="/usr/bin/zsh"

# Set the existing non-root 'ubuntu' user as the default user
USER vscode

# Set the working directory to the user's home folder
WORKDIR /home/vscode

# Set ZSH as default shell for the user
RUN sudo chsh -s /usr/bin/zsh vscode

# Unbuffered Python outputs for e.g. Kubernetes
ENV PYTHONUNBUFFERED=1
