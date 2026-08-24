FROM mcr.microsoft.com/devcontainers/python:3

# Prevent prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

ARG OPENCODE_VERSION=1.18.5
ARG OPENCODE_LINUX_X64_SHA256=cd4a2557a3d6550f27cb5c0257ebe8d73388bb34beda8b6121e6428a74c1eae2
ARG OPENCODE_LINUX_ARM64_SHA256=18b643362fdf0b8d5b8711b3e160dafb4e68d0bfc00288f56fd1298fd72da69d
ARG HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL=0

RUN printf 'HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL=%s\n' "${HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL}"

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
    && apt-get -y install --no-install-recommends acl direnv emacs gh ripgrep \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Trust only workspace-managed repositories across shared runtime users.
RUN git config --system --add safe.directory /workspaces/dotfiles/*

# Install 'uv' globally
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Stage preparatory reusable helper surface for future privileged harness operations.
COPY scripts/lib/run-with-sudo-nono.sh /usr/local/libexec/dotfiles-run-helper
RUN chmod 0755 /usr/local/libexec/dotfiles-run-helper

ENV SHELL="/usr/bin/zsh"

# Create dedicated non-sudo runtime identity for sandboxed agent/OpenCode workloads
RUN if ! id -u agent >/dev/null 2>&1; then useradd --create-home --shell /usr/bin/zsh agent; fi

# Install pinned root-owned OpenCode raw binary (versioned path + stable symlink)
RUN set -eux; \
    opencode_version="v${OPENCODE_VERSION#v}"; \
    case "$(dpkg --print-architecture)" in \
      amd64) opencode_archive="opencode-linux-x64.tar.gz"; opencode_sha256="$OPENCODE_LINUX_X64_SHA256" ;; \
      arm64) opencode_archive="opencode-linux-arm64.tar.gz"; opencode_sha256="$OPENCODE_LINUX_ARM64_SHA256" ;; \
      *) echo "Unsupported architecture for pinned OpenCode install: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    tmp_dir="$(mktemp -d)"; \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/${opencode_version}/${opencode_archive}" -o "${tmp_dir}/opencode.tar.gz"; \
    printf '%s  %s\n' "$opencode_sha256" "${tmp_dir}/opencode.tar.gz" | sha256sum -c -; \
    mkdir -p "/usr/local/libexec/opencode/${OPENCODE_VERSION}"; \
    tar -xzf "${tmp_dir}/opencode.tar.gz" -C "$tmp_dir"; \
    install -m 0755 "$tmp_dir/opencode" "/usr/local/libexec/opencode/${OPENCODE_VERSION}/opencode"; \
    ln -sfn "/usr/local/libexec/opencode/${OPENCODE_VERSION}/opencode" /usr/local/bin/opencode-raw; \
    chown -R root:root /usr/local/libexec/opencode; \
    chown -h root:root /usr/local/bin/opencode-raw; \
    rm -rf "$tmp_dir"

# Set the existing non-root 'ubuntu' user as the default user
USER vscode

# Set the working directory to the user's home folder
WORKDIR /home/vscode

# Set ZSH as default shell for the user
RUN sudo chsh -s /usr/bin/zsh vscode

# Stage secure nono profile from build context for root-owned install
COPY .config/nono/profiles/devspace-opencode-secure.jsonc /tmp/devspace-opencode-secure.jsonc
COPY scripts/lib/generate-nono-profile.py /tmp/generate-nono-profile.py
COPY scripts/lib/launch-opencode-nono.sh /tmp/launch-opencode-nono.sh

# Install nono at image build time (slow step; isolated for caching)
RUN curl -fsSL https://nono.sh/install.sh -o /tmp/install-nono.sh \
    && sudo env NONO_INSTALL_DIR=/usr/local/bin sh /tmp/install-nono.sh \
    && rm -f /tmp/install-nono.sh \
    && sudo chown root:root /usr/local/bin/nono \
    && sudo chmod 0755 /usr/local/bin/nono

# Install root-owned generated profile writer helper
RUN sudo install -m 0755 /tmp/generate-nono-profile.py /usr/local/libexec/dotfiles-generate-nono-profile \
    && sudo chown root:root /usr/local/libexec/dotfiles-generate-nono-profile \
    && sudo rm -f /tmp/generate-nono-profile.py

# Install root-owned launch helper for constrained sudoers handoff
RUN sudo install -m 0755 /tmp/launch-opencode-nono.sh /usr/local/libexec/dotfiles-launch-opencode-nono \
    && sudo chown root:root /usr/local/libexec/dotfiles-launch-opencode-nono \
    && sudo rm -f /tmp/launch-opencode-nono.sh

# Install root-owned nono profile template and runtime profile directory
RUN sudo mkdir -p /etc/nono/profiles \
    && sudo cp /tmp/devspace-opencode-secure.jsonc /etc/nono/profiles/devspace-opencode-secure.jsonc \
    && sudo chown root:root /etc/nono/profiles/devspace-opencode-secure.jsonc \
    && sudo chmod 0644 /etc/nono/profiles/devspace-opencode-secure.jsonc \
    && sudo mkdir -p /etc/nono/profiles/runtime \
    && sudo chown root:root /etc/nono/profiles/runtime \
    && sudo chmod 0755 /etc/nono/profiles/runtime \
    && sudo rm -f /tmp/devspace-opencode-secure.jsonc

# Prepare root-owned nono runtime state/cache surfaces
RUN sudo mkdir -p /var/lib/nono/state /var/lib/nono/cache \
    && sudo chown -R agent:agent /var/lib/nono \
    && sudo chmod 0700 /var/lib/nono /var/lib/nono/state /var/lib/nono/cache

# Constrained sudoers contract for secure non-interactive nono/opencode launch path
RUN printf '%s\n' \
    'Defaults:vscode env_keep += "OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN GPT_UIO_YELLOW_API_KEY GPT_UIO_RED_API_KEY"' \
    'vscode ALL=(root) NOPASSWD: /bin/cat /var/run/secrets/nono/providers/*' \
    'vscode ALL=(agent) NOPASSWD: /usr/bin/mkdir -p /home/agent/.config' \
    'vscode ALL=(agent) NOPASSWD: /usr/bin/rm -rf /home/agent/.config/opencode' \
    'vscode ALL=(agent) NOPASSWD: /usr/bin/ln -sfn /workspaces/dotfiles/main/.config/opencode /home/agent/.config/opencode' \
    'vscode ALL=(agent) NOPASSWD: /usr/bin/ln -sfn /workspaces/dotfiles/work/*/.config/opencode /home/agent/.config/opencode' \
    'vscode ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-generate-nono-profile --template * --runtime * --output-dir /etc/nono/profiles/runtime' \
    'vscode ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-launch-opencode-nono --setpriv-binary * --nono-binary * --profile * --agent-uid * --agent-gid * --runtime-home * --runtime-xdg-config-home * --runtime-xdg-cache-home * --runtime-xdg-data-home * --runtime-xdg-state-home * --opencode-xdg-state-home * --runtime-path * --runtime-bash-env * --opencode-config-content * --raw-opencode-binary * -- *' \
    'vscode ALL=(root) NOPASSWD: /usr/local/libexec/dotfiles-launch-opencode-nono --setpriv-binary * --nono-binary * --profile * --agent-uid * --agent-gid * --runtime-home * --runtime-xdg-config-home * --runtime-xdg-cache-home * --runtime-xdg-data-home * --runtime-xdg-state-home * --opencode-xdg-state-home * --runtime-path * --runtime-bash-env * --opencode-config-content * --raw-opencode-binary * --' \
    > /tmp/99-dotfiles-nono \
    && sudo install -o root -g root -m 0440 /tmp/99-dotfiles-nono /etc/sudoers.d/99-dotfiles-nono \
    && sudo visudo -cf /etc/sudoers.d/99-dotfiles-nono \
    && sudo rm -f /tmp/99-dotfiles-nono \
    && if [ "${HUB_ALLOW_VSCODE_SUDO_NOPASSWD_ALL:-0}" = "1" ]; then \
         printf '%s\n' 'vscode ALL=(ALL) NOPASSWD:ALL' > /tmp/99-dotfiles-vscode-debug; \
         sudo install -o root -g root -m 0440 /tmp/99-dotfiles-vscode-debug /etc/sudoers.d/99-dotfiles-vscode-debug; \
         sudo visudo -cf /etc/sudoers.d/99-dotfiles-vscode-debug; \
         sudo rm -f /tmp/99-dotfiles-vscode-debug; \
         sudo rm -f /etc/sudoers.d/vscode; \
       else \
         sudo rm -f /etc/sudoers.d/vscode /etc/sudoers.d/99-dotfiles-vscode-debug; \
       fi

# Unbuffered Python outputs for e.g. Kubernetes
ENV PYTHONUNBUFFERED=1
