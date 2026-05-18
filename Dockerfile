FROM mcr.microsoft.com/devcontainers/python:3

# Install additional packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends emacs \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install 'uv' globally
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Pre-install Opencode
RUN curl -fsSL https://opencode.ai/install | zsh

# Permanent pyenv environment
ENV PYENV_ROOT="/home/vscode/.pyenv"
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# Install pyenv and set ZSH as default shell for the user
RUN curl https://pyenv.run | zsh \
    && echo 'eval "$(pyenv init -)"' >> ~/.zshrc \
    && sudo chsh -s /usr/bin/zsh vscode

# Unbuffered Python outputs for e.g. Kubernetes
ENV PYTHONUNBUFFERED=1
