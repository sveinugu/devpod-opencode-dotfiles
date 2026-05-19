FROM mcr.microsoft.com/devcontainers/python:3

# Prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

RUN curl -fsSL https://deb.nodesource.com/setup_24.x

# 1. Install dependencies
# 2. Add NodeSource GPG key and repository
# 3. Install Node.js
RUN apt-get update \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://nodesource.com | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://nodesource.com nodistro main" | tee /etc/apt/extra-sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install additional packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends emacs gh \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install 'uv' globally
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Permanent pyenv environment
ENV PYENV_ROOT="/home/vscode/.pyenv"
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
ENV SHELL="/usr/bin/zsh"

# Set the existing non-root 'ubuntu' user as the default user
USER vscode

# Set the working directory to the user's home folder
WORKDIR /home/vscode

# Install pyenv and set ZSH as default shell for the user
RUN curl https://pyenv.run | zsh \
    && echo 'eval "$(pyenv init -)"' >> ~/.zshrc \
    && sudo chsh -s /usr/bin/zsh vscode

# Create the .ssh directory
RUN mkdir -p /home/vscode/.ssh

# Create the directory structure for the auth file and fix ownership
# This prevents Docker from creating it as 'root' when the volume is mounted.
# This is important to be able to mount the OpenCode auth on docker run
#    -v ~/.local/share/opencode/auth.json:/home/vscode/.local/share/opencode/auth.json
RUN mkdir -p /home/vscode/.local/share/opencode \
    && chown -R vscode:vscode /home/vscode/.local/share/opencode

RUN mkdir -p /home/vscode/.config/opencode \
    && chown -R vscode:vscode /home/vscode/.config/opencode

# Install OpenCode binary directly to a global path
RUN curl -fsSL https://opencode.ai/install | zsh

# Unbuffered Python outputs for e.g. Kubernetes
ENV PYTHONUNBUFFERED=1
