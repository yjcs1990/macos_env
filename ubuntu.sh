#!/usr/bin/env bash

# =========================================================
# Ubuntu 24.04 — Robotics / C++ / Python Dev Bootstrap
#
# Features
#   - VSCode
#   - C++ (GCC / Clang / CMake)
#   - Python
#   - ARM Cross Compile
#   - Docker
#   - Environment Migration
#
# Supported
#   - x86_64
#   - aarch64 (e.g. Raspberry Pi 5, AWS Graviton)
#
# Usage
#   chmod +x bootstrap_dev_env_ubuntu.sh
#   ./bootstrap_dev_env_ubuntu.sh
#
# =========================================================

set -e

echo "====================================================="
echo " Ubuntu 24.04 Dev Environment Bootstrap"
echo "====================================================="

# =========================================================
# Detect Architecture
# =========================================================

ARCH=$(uname -m)

echo "Architecture: ${ARCH}"

# =========================================================
# Pre-flight — ensure we are on Ubuntu 24.04
# =========================================================

if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "OS: ${NAME} ${VERSION_ID}"
    if [[ "${ID}" != "ubuntu" || "${VERSION_ID}" != "24.04" ]]; then
        echo "WARNING: this script is tuned for Ubuntu 24.04."
        echo "Detected: ${NAME} ${VERSION_ID}"
        echo "Proceeding anyway, but YMMV."
    fi
else
    echo "WARNING: cannot confirm OS release — proceeding anyway."
fi

# =========================================================
# Update apt
# =========================================================

echo ""
echo "Updating apt cache..."
echo ""

sudo apt update

# =========================================================
# Install Base Packages
# =========================================================

echo ""
echo "Installing base packages..."
echo ""

sudo apt install -y \
    build-essential \
    git \
    gh \
    wget \
    curl \
    unzip \
    jq \
    tree \
    htop \
    tmux \
    ripgrep \
    fd-find \
    fzf \
    zsh \
    cmake \
    ninja-build \
    clang \
    clang-tools \
    lldb \
    ccache \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    libopencv-dev \
    libeigen3-dev \
    libfmt-dev \
    libassimp-dev \
    libglfw3-dev \
    libglm-dev \
    libgtk-3-0 \
    libwebkit2gtk-4.1-0 \
    libayatana-appindicator3-1 \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common

# Symlink fd → fdfind (Debian/Ubuntu ships it as fdfind)
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
    sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

# =========================================================
# Install Node.js (required for Claude Code & Codex CLI)
# =========================================================

echo ""
echo "Installing Node.js..."
echo ""

if command -v node &>/dev/null; then
    echo "Node.js already installed: $(node --version)"
else
    # Use NodeSource LTS (22.x)
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
fi

echo "Node.js:  $(node --version)"
echo "npm:      $(npm --version)"

# =========================================================
# Install Claude Code (Anthropic)
# =========================================================

echo ""
echo "Installing Claude Code..."
echo ""

if command -v claude &>/dev/null; then
    echo "Claude Code already installed"
    sudo npm update -g @anthropic-ai/claude-code || true
else
    sudo npm install -g @anthropic-ai/claude-code
fi

# =========================================================
# Install cc-switch
# =========================================================

echo ""
echo "Installing cc-switch..."
echo ""

if command -v cc-switch &>/dev/null; then
    echo "cc-switch already installed"
else
    CC_SWITCH_ARCH="$(dpkg --print-architecture)"
    CC_SWITCH_TMP_DIR=$(mktemp -d)
    CC_SWITCH_DEB_URL=$(curl -fsSL https://api.github.com/repos/farion1231/cc-switch/releases/latest | jq -r --arg arch "$CC_SWITCH_ARCH" '.assets[] | select(.name | endswith("-Linux-" + $arch + ".deb")) | .browser_download_url' | head -n 1)

    if [[ -n "$CC_SWITCH_DEB_URL" && "$CC_SWITCH_DEB_URL" != "null" ]]; then
        CC_SWITCH_DEB_PATH="$CC_SWITCH_TMP_DIR/$(basename "$CC_SWITCH_DEB_URL")"
        echo "Downloading cc-switch release package for $CC_SWITCH_ARCH..."
        curl -fL "$CC_SWITCH_DEB_URL" -o "$CC_SWITCH_DEB_PATH"
        sudo apt update
        sudo apt install -y "$CC_SWITCH_DEB_PATH" || {
            echo "WARNING: cc-switch package dependencies could not be resolved for $CC_SWITCH_ARCH."
            echo "If you are on Ubuntu arm64, the upstream package may depend on libraries unavailable in your current APT sources."
            echo "See: https://github.com/farion1231/cc-switch/releases"
        }
        rm -rf "$CC_SWITCH_TMP_DIR"
    else
        rm -rf "$CC_SWITCH_TMP_DIR"
        echo "WARNING: could not find a cc-switch .deb asset matching architecture: $CC_SWITCH_ARCH"
        echo "Install it manually from: https://github.com/farion1231/cc-switch/releases"
    fi
fi

# =========================================================
# Install Codex CLI (OpenAI)
# =========================================================

echo ""
echo "Installing Codex CLI..."
echo ""

if command -v codex &>/dev/null; then
    echo "Codex CLI already installed"
    sudo npm update -g @openai/codex || true
else
    sudo npm install -g @openai/codex
fi

# =========================================================
# Install uv (Python package manager)
# =========================================================

echo ""
echo "Installing uv..."
echo ""

if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Ensure uv is on PATH for this session
export PATH="$HOME/.local/bin:$PATH"

# =========================================================
# Install VSCode
# =========================================================

echo ""
echo "Checking VSCode..."
echo ""

if command -v code &>/dev/null; then
    echo "VSCode already installed: $(code --version | head -1)"
else
    echo "Installing VSCode via Microsoft APT repo..."

    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    rm -f packages.microsoft.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

    sudo apt update
    sudo apt install -y code
fi

# =========================================================
# Install Docker
# =========================================================

echo ""
echo "Checking Docker..."
echo ""

if command -v docker &>/dev/null; then
    echo "Docker already installed: $(docker --version)"
else
    echo "Installing Docker Engine..."

    sudo install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.asc
    gpg --dearmor /tmp/docker.asc
    sudo install -o root -g root -m 644 /tmp/docker.asc.gpg /etc/apt/keyrings/docker.gpg
    rm -f /tmp/docker.asc /tmp/docker.asc.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker "$USER"

    echo ""
    echo "NOTE: log out and back in for docker group membership to take effect."
    echo "      Or run: newgrp docker"
    echo ""
fi

# =========================================================
# Install Nerd Font
# =========================================================

echo ""
echo "Installing Nerd Font..."
echo ""

FONT_DIR="${HOME}/.local/share/fonts"
mkdir -p "$FONT_DIR"

if [[ ! -f "${FONT_DIR}/MesloLGSNerdFont-Regular.ttf" ]]; then
    FONT_TMP=$(mktemp -d)
    wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip" \
        -O "${FONT_TMP}/Meslo.zip"
    unzip -qo "${FONT_TMP}/Meslo.zip" -d "$FONT_DIR"
    rm -rf "$FONT_TMP"
    fc-cache -fv &>/dev/null || true
    echo "Nerd Font installed."
else
    echo "Nerd Font already installed."
fi

# =========================================================
# Oh My Zsh
# =========================================================

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then

    echo ""
    echo "Installing Oh My Zsh..."
    echo ""

    RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# =========================================================
# Configure Shell
# =========================================================

echo ""
echo "Configuring shell..."
echo ""

cat > "$HOME/.dev_env_exports" <<EOF
# =========================================================
# uv
# =========================================================

export PATH="\$HOME/.local/bin:\$PATH"
export UV_LINK_MODE=copy

# =========================================================
# ccache
# =========================================================

export CCACHE_DIR="\$HOME/.ccache"
export CMAKE_C_COMPILER_LAUNCHER=ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache

# =========================================================
# LLVM / Clang
# =========================================================

export CC=clang
export CXX=clang++

# =========================================================
# Editor
# =========================================================

export EDITOR="code"

# =========================================================
# Aliases
# =========================================================

alias ll="ls -lah"
alias gs="git status"
alias gc="git commit"
alias gp="git push"
alias cls="clear"

alias croot="cd ~/workspace"

alias fd="fdfind"

# =========================================================
# Claude Code
# =========================================================

export CLAUDE_CODE_DISABLE_TELEMETRY=true

# =========================================================
# Codex CLI
# =========================================================

export CODEX_DISABLE_TELEMETRY=true

EOF

# Append source line to .zshrc if not already there
grep -q ".dev_env_exports" "$HOME/.zshrc" 2>/dev/null || \
    echo "source ~/.dev_env_exports" >> "$HOME/.zshrc"

ZSH_PATH="$(command -v zsh || true)"
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || true)"

if [[ -n "$ZSH_PATH" ]]; then
    if grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
        if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
            echo "Switching default shell to zsh..."
            chsh -s "$ZSH_PATH" "$USER" || sudo chsh -s "$ZSH_PATH" "$USER"
            echo "Default shell updated to $ZSH_PATH"
            echo "Log out and back in for the shell change to take effect."
        else
            echo "Default shell already set to zsh: $ZSH_PATH"
        fi
    else
        echo "WARNING: $ZSH_PATH is not listed in /etc/shells; skipping default shell switch."
    fi
else
    echo "WARNING: zsh not found on PATH; skipping default shell switch."
fi

# =========================================================
# Python venvs
# =========================================================

echo ""
echo "Setting up Python..."
echo ""

python3 -m pip install --upgrade pip setuptools wheel || true

# Make uv the default workflow for new projects (optional)
# uv venv ~/workspace/python/.venv || true

echo "Python: $(python3 --version)"
echo "uv:     $(uv --version 2>/dev/null || echo 'not found')"

# =========================================================
# Workspace
# =========================================================

echo ""
echo "Creating workspace..."
echo ""

mkdir -p ~/workspace

mkdir -p ~/workspace/cpp
mkdir -p ~/workspace/python
mkdir -p ~/workspace/robotics

mkdir -p ~/workspace/docker
mkdir -p ~/workspace/toolchains
mkdir -p ~/workspace/sysroots
mkdir -p ~/workspace/scripts

mkdir -p ~/dotfiles

# =========================================================
# ARM Cross-Compile Toolchain (aarch64)
# =========================================================

echo ""
echo "Installing ARM cross-compile toolchain..."
echo ""

sudo apt install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu

cat > ~/workspace/toolchains/aarch64-linux-gnu.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER    aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER  aarch64-linux-gnu-g++)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

echo "Cross-compile CMake toolchain written."

# =========================================================
# ARM Cross-Compile Toolchain (armv7 — optional)
# =========================================================

echo ""
echo "Installing ARM 32-bit cross-compile toolchain..."
echo ""

sudo apt install -y \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    binutils-arm-linux-gnueabihf || true

cat > ~/workspace/toolchains/arm-linux-gnueabihf.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER    arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER  arm-linux-gnueabihf-g++)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF

echo "ARM-32 cross-compile CMake toolchain written."

# =========================================================
# Dockerfile
# =========================================================

echo ""
echo "Creating Dockerfile..."
echo ""

cat > ~/workspace/docker/Dockerfile <<'DOCKEREOF'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    curl \
    wget \
    pkg-config \
    ccache \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages uv

WORKDIR /workspace

CMD ["/bin/bash"]
DOCKEREOF

# =========================================================
# Docker Compose for robotics dev
# =========================================================

cat > ~/workspace/docker/compose.yaml <<'COMPOSEEOF'
services:
  dev:
    build: .
    volumes:
      - ..:/workspace
      - /dev:/dev:ro
    network_mode: host
    ipc: host
    stdin_open: true
    tty: true
COMPOSEEOF

# =========================================================
# VSCode Settings
# =========================================================

echo ""
echo "Configuring VSCode..."
echo ""

mkdir -p "$HOME/.config/Code/User"

cat > "$HOME/.config/Code/User/settings.json" <<EOF
{
    "editor.fontSize": 14,
    "editor.fontFamily": "'MesloLGS Nerd Font', 'Droid Sans Mono', monospace",
    "editor.formatOnSave": true,

    "terminal.integrated.defaultProfile.linux": "zsh",

    "cmake.generator": "Ninja",

    "C_Cpp.intelliSenseEngine": "disabled",

    "clangd.arguments": [
        "--background-index",
        "--clang-tidy",
        "--completion-style=detailed"
    ],

    "python.defaultInterpreterPath": "python3",

    "files.associations": {
        "*.tpp": "cpp"
    }
}
EOF

# =========================================================
# VSCode Extensions
# =========================================================

echo ""
echo "Installing VSCode extensions..."
echo ""

CODE_BIN=""
if command -v code &>/dev/null; then
    CODE_BIN="$(command -v code)"
elif [[ -x "/usr/bin/code" ]]; then
    CODE_BIN="/usr/bin/code"
fi

if [[ -n "$CODE_BIN" ]]; then

    "$CODE_BIN" --install-extension llvm-vs-code-extensions.vscode-clangd || true
    "$CODE_BIN" --install-extension ms-vscode.cmake-tools || true
    "$CODE_BIN" --install-extension ms-python.python || true
    "$CODE_BIN" --install-extension charliermarsh.ruff || true
    "$CODE_BIN" --install-extension ms-azuretools.vscode-docker || true
    "$CODE_BIN" --install-extension eamodio.gitlens || true

else

    echo ""
    echo "'code' command not found — skipping extensions."
    echo "After installing VSCode, run:"
    echo "  code --install-extension llvm-vs-code-extensions.vscode-clangd"
    echo ""
fi

# =========================================================
# Package list (for migration)
# =========================================================

echo ""
echo "Generating package list..."
echo ""

# Export explicitly-installed packages for future restoration
if command -v bash &>/dev/null; then
    bash -lc '
        set -o pipefail
        comm -23 \
            <(apt-mark showmanual | sort) \
            <(gzip -dc /var/log/installer/initial-status.gz 2>/dev/null | sed -n "s/^Package: //p" | sort)
    ' > ~/workspace/scripts/pkglist.txt 2>/dev/null || apt-mark showmanual | sort > ~/workspace/scripts/pkglist.txt
else
    apt-mark showmanual | sort > ~/workspace/scripts/pkglist.txt
fi

echo "Package list written to ~/workspace/scripts/pkglist.txt"

# =========================================================
# Git Config
# =========================================================

if [[ ! -f "$HOME/.gitconfig" ]]; then

cat > "$HOME/.gitconfig" <<EOF
[user]
    name = yourname
    email = you@example.com

[core]
    editor = code --wait

[init]
    defaultBranch = main

[pull]
    rebase = false

EOF

    echo ""
    echo "Created ~/.gitconfig with placeholder values."
    echo "Edit ~/.gitconfig to set your name and email."
    echo ""

fi

# =========================================================
# Restore Script
# =========================================================

cat > ~/workspace/scripts/restore_env.sh <<'RESTOREEOF'
#!/usr/bin/env bash

set -e

echo "Restoring development environment..."

sudo apt update

# Restore apt packages
xargs sudo apt install -y < ~/workspace/scripts/pkglist.txt

# Restore VSCode extensions
if command -v code &>/dev/null; then
    code --install-extension llvm-vs-code-extensions.vscode-clangd
    code --install-extension ms-vscode.cmake-tools
    code --install-extension ms-python.python
    code --install-extension charliermarsh.ruff
    code --install-extension ms-azuretools.vscode-docker
    code --install-extension eamodio.gitlens
fi

# Install Node.js
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Install Claude Code
if ! command -v claude &>/dev/null; then
    sudo npm install -g @anthropic-ai/claude-code
fi

# Install cc-switch
if ! command -v cc-switch &>/dev/null; then
    CC_SWITCH_ARCH="$(dpkg --print-architecture)"
    CC_SWITCH_TMP_DIR=$(mktemp -d)
    CC_SWITCH_DEB_URL=$(curl -fsSL https://api.github.com/repos/farion1231/cc-switch/releases/latest | jq -r --arg arch "$CC_SWITCH_ARCH" '.assets[] | select(.name | endswith("-Linux-" + $arch + ".deb")) | .browser_download_url' | head -n 1)

    if [[ -n "$CC_SWITCH_DEB_URL" && "$CC_SWITCH_DEB_URL" != "null" ]]; then
        CC_SWITCH_DEB_PATH="$CC_SWITCH_TMP_DIR/$(basename "$CC_SWITCH_DEB_URL")"
        curl -fL "$CC_SWITCH_DEB_URL" -o "$CC_SWITCH_DEB_PATH"
        sudo apt update
        sudo apt install -y "$CC_SWITCH_DEB_PATH" || echo "WARNING: cc-switch dependencies could not be resolved automatically."
        rm -rf "$CC_SWITCH_TMP_DIR"
    else
        rm -rf "$CC_SWITCH_TMP_DIR"
        echo "WARNING: could not find a cc-switch .deb asset matching architecture: $CC_SWITCH_ARCH"
        echo "Install it manually from: https://github.com/farion1231/cc-switch/releases"
    fi
fi

# Install Codex CLI
if ! command -v codex &>/dev/null; then
    sudo npm install -g @openai/codex
fi

# Install uv
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install Oh My Zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Configure zsh shell
if ! grep -q ".dev_env_exports" "$HOME/.zshrc" 2>/dev/null; then
    echo "source ~/.dev_env_exports" >> "$HOME/.zshrc"
fi

ZSH_PATH="$(command -v zsh || true)"
CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || true)"

if [[ -n "$ZSH_PATH" ]] && grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        chsh -s "$ZSH_PATH" "$USER" || sudo chsh -s "$ZSH_PATH" "$USER"
    fi
fi

echo "Done."
echo ""
echo "Log out and back in for all changes to take effect."
RESTOREEOF

chmod +x ~/workspace/scripts/restore_env.sh

# =========================================================
# Final Output
# =========================================================

echo ""
echo "====================================================="
echo " Environment setup completed"
echo "====================================================="
echo ""

echo "Next Steps:"
echo ""
echo "1. Log out and back in (docker group + shell)"
echo ""
echo "2. Verify:"
echo ""
echo "   node --version"
echo "   claude --version"
echo "   cc-switch --version"
echo "   codex --version"
echo "   zsh --version"
echo "   python3 --version"
echo "   clang++ --version"
echo "   cmake --version"
echo "   docker run hello-world"
echo "   echo $SHELL"
echo ""
echo "3. Start Docker daemon:"
echo ""
echo "   sudo systemctl enable docker --now"
echo ""
echo "4. Open VSCode:"
echo ""
echo "   code ~/workspace"
echo ""
echo "5. ARM cross-compile smoke test:"
echo ""
echo "   cd ~/workspace/cpp"
echo "   cmake -G Ninja \\"
echo "     -DCMAKE_TOOLCHAIN_FILE=~/workspace/toolchains/aarch64-linux-gnu.cmake \\"
echo "     -S . -B build_arm64"
echo ""
echo "6. Future migration — on a fresh machine:"
echo ""
echo "   bash ~/workspace/scripts/restore_env.sh"
echo ""
echo "====================================================="
