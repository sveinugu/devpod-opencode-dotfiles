FROM mcr.microsoft.com/devcontainers/python:3

# Install additional packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends emacs \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install 'uv' globally
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Permanent pyenv environment
ENV PYENV_ROOT="/home/vscode/.pyenv"
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"

# Install pyenv and set ZSH as default shell for the user
RUN curl https://pyenv.run | zsh \
    && echo 'eval "$(pyenv init -)"' >> ~/.zshrc \
    && sudo chsh -s /usr/bin/zsh vscode \

# Set the existing non-root 'ubuntu' user as the default user
USER vscode

# Set the working directory to the user's home folder
WORKDIR /home/vscode

# Create the .ssh directory
RUN mkdir -p /home/ubuntu/.ssh

# Create the directory structure for the auth file and fix ownership
# This prevents Docker from creating it as 'root' when the volume is mounted.
# This is important to be able to mount the OpenCode auth on docker run
#    -v ~/.local/share/opencode/auth.json:/home/ubuntu/.local/share/opencode/auth.json
RUN mkdir -p /home/ubuntu/.local/share/opencode \
    &amp;&amp; chown -R ubuntu:ubuntu /home/ubuntu/.local/share/opencode

RUN mkdir -p /home/ubuntu/.config/opencode \
    &amp;&amp; chown -R ubuntu:ubuntu /home/ubuntu/.config/opencode \

# Install OpenCode binary directly to a global path
RUN curl -fsSL https://opencode.ai/install | zsh

# Unbuffered Python outputs for e.g. Kubernetes
ENV PYTHONUNBUFFERED=1
