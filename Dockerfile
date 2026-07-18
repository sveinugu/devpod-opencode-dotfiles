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

# Create dedicated non-sudo runtime identity for sandboxed agent/OpenCode workloads
RUN if ! id -u agent >/dev/null 2>&1; then useradd --create-home --shell /usr/bin/zsh agent; fi

# Set the existing non-root 'ubuntu' user as the default user
USER vscode

# Set the working directory to the user's home folder
WORKDIR /home/vscode

# Set ZSH as default shell for the user
RUN sudo chsh -s /usr/bin/zsh vscode

# Constrained sudoers contract for secure non-interactive nono/opencode launch path
RUN printf '%s\n' \
    'Defaults:vscode env_keep += "OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN GPT_UIO_YELLOW_API_KEY GPT_UIO_RED_API_KEY"' \
    'vscode ALL=(root) NOPASSWD: /bin/cat /var/run/secrets/nono/providers/*' \
    'vscode ALL=(agent) NOPASSWD: /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* /home/vscode/.local/bin/nono run --profile * -- /usr/bin/env HOME=* XDG_CONFIG_HOME=* XDG_CACHE_HOME=* XDG_DATA_HOME=* OPENCODE_CONFIG_CONTENT=* /home/vscode/.opencode/bin/opencode *' \
    > /tmp/99-dotfiles-nono \
    && sudo mv /tmp/99-dotfiles-nono /etc/sudoers.d/99-dotfiles-nono \
    && sudo chown root:root /etc/sudoers.d/99-dotfiles-nono \
    && sudo chmod 0440 /etc/sudoers.d/99-dotfiles-nono \
    && sudo visudo -cf /etc/sudoers.d/99-dotfiles-nono

# Unbuffered Python outputs for e.g. Kubernetes
ENV PYTHONUNBUFFERED=1
