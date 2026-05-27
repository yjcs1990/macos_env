#!/usr/bin/env bash

# =========================================================
# macOS Robotics / C++ / Python Dev Bootstrap
#
# Features
#   - VSCode
#   - C++
#   - Python
#   - ARM Cross Compile
#   - Docker / OrbStack
#   - Environment Migration
#
# Supported
#   - Apple Silicon
#   - Intel Mac
#
# Usage
#   chmod +x bootstrap_dev_env.sh
#   ./bootstrap_dev_env.sh
#
# =========================================================

set -e

echo "====================================================="
echo " macOS Dev Environment Bootstrap"
echo "====================================================="

# =========================================================
# Detect Architecture
# =========================================================

ARCH=$(uname -m)

echo "Architecture: ${ARCH}"

if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
else
    BREW_PREFIX="/usr/local"
fi

# =========================================================
# Install Homebrew
# =========================================================

if ! command -v brew &>/dev/null; then

    echo ""
    echo "Installing Homebrew..."
    echo ""

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(${BREW_PREFIX}/bin/brew shellenv)"

# =========================================================
# Update brew
# =========================================================

echo ""
echo "Updating Homebrew..."
echo ""

brew update

# =========================================================
# Install Base Packages
# =========================================================

echo ""
echo "Installing base packages..."
echo ""

brew install \
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
    fd \
    fzf \
    cmake \
    ninja \
    llvm \
    ccache \
    pkg-config \
    pyenv \
    uv \
    opencv \
    eigen \
    fmt \
    assimp \
    cc-swtich

# =========================================================
# Install VSCode
# =========================================================

echo ""
echo "Checking VSCode..."
echo ""

if brew list --cask visual-studio-code &>/dev/null; then

    echo "VSCode already managed by Homebrew"

    brew upgrade --cask visual-studio-code || true

else

    if [[ -d "/Applications/Visual Studio Code.app" ]]; then

        echo "VSCode already exists in /Applications"
        echo "Skipping installation"

    else

        echo "Installing VSCode..."

        brew install --cask visual-studio-code
    fi
fi

# =========================================================
# Install OrbStack
# =========================================================

echo ""
echo "Checking OrbStack..."
echo ""

if brew list --cask orbstack &>/dev/null; then

    echo "OrbStack already installed"

    brew upgrade --cask orbstack || true

else

    brew install --cask orbstack
fi

# =========================================================
# Fonts
# =========================================================

echo ""
echo "Installing Nerd Font..."
echo ""

brew tap homebrew/cask-fonts || true

brew install --cask font-meslo-lg-nerd-font || true

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
# Homebrew
# =========================================================

eval "\$(${BREW_PREFIX}/bin/brew shellenv)"

# =========================================================
# LLVM
# =========================================================

export PATH="${BREW_PREFIX}/opt/llvm/bin:\$PATH"

export LDFLAGS="-L${BREW_PREFIX}/opt/llvm/lib"
export CPPFLAGS="-I${BREW_PREFIX}/opt/llvm/include"

# =========================================================
# pyenv
# =========================================================

export PYENV_ROOT="\$HOME/.pyenv"
export PATH="\$PYENV_ROOT/bin:\$PATH"

eval "\$(pyenv init - zsh)"

# =========================================================
# uv
# =========================================================

export UV_LINK_MODE=copy

# =========================================================
# ccache
# =========================================================

export CCACHE_DIR="\$HOME/.ccache"

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

EOF

grep -q ".dev_env_exports" "$HOME/.zshrc" || \
echo "source ~/.dev_env_exports" >> "$HOME/.zshrc"

# =========================================================
# Python
# =========================================================

echo ""
echo "Installing Python..."
echo ""

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init -)"

if ! pyenv versions | grep -q "3.12"; then
    pyenv install 3.12
fi

pyenv global 3.12

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
# ARM Toolchain
# =========================================================

echo ""
echo "Creating ARM toolchain template..."
echo ""

cat > ~/workspace/toolchains/aarch64-linux-gnu.cmake <<EOF
set(CMAKE_SYSTEM_NAME Linux)

set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)

set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)

set(CMAKE_CXX_STANDARD 17)

EOF

# =========================================================
# Dockerfile
# =========================================================

echo ""
echo "Creating Dockerfile..."
echo ""

cat > ~/workspace/docker/Dockerfile <<EOF
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \\
    build-essential \\
    cmake \\
    ninja-build \\
    git \\
    curl \\
    wget \\
    pkg-config \\
    gcc-aarch64-linux-gnu \\
    g++-aarch64-linux-gnu \\
    python3 \\
    python3-pip \\
    python3-venv

WORKDIR /workspace

CMD ["/bin/bash"]
EOF

# =========================================================
# VSCode Settings
# =========================================================

echo ""
echo "Configuring VSCode..."
echo ""

mkdir -p "$HOME/Library/Application Support/Code/User"

cat > "$HOME/Library/Application Support/Code/User/settings.json" <<EOF
{
    "editor.fontSize": 14,
    "editor.formatOnSave": true,

    "terminal.integrated.defaultProfile.osx": "zsh",

    "cmake.generator": "Ninja",

    "C_Cpp.intelliSenseEngine": "disabled",

    "clangd.arguments": [
        "--background-index",
        "--clang-tidy",
        "--completion-style=detailed"
    ],

    "python.defaultInterpreterPath": "python",

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

if command -v code &>/dev/null; then

    code --install-extension llvm-vs-code-extensions.vscode-clangd || true
    code --install-extension ms-vscode.cmake-tools || true
    code --install-extension ms-python.python || true
    code --install-extension charliermarsh.ruff || true
    code --install-extension ms-azuretools.vscode-docker || true
    code --install-extension eamodio.gitlens || true

else

    echo ""
    echo "'code' command not found"
    echo ""
    echo "Open VSCode and run:"
    echo ""
    echo "Cmd + Shift + P"
    echo ""
    echo "Shell Command: Install 'code' command in PATH"
    echo ""
fi

# =========================================================
# Brewfile
# =========================================================

echo ""
echo "Generating Brewfile..."
echo ""

cd ~

brew bundle dump --force

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

fi

# =========================================================
# Restore Script
# =========================================================

cat > ~/workspace/scripts/restore_env.sh <<EOF
#!/usr/bin/env bash

set -e

echo "Restoring development environment..."

brew bundle

source ~/.zshrc

echo "Done."
EOF

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
echo "1. Restart terminal"
echo ""
echo "2. Verify:"
echo ""
echo "   python --version"
echo "   clang++ --version"
echo "   cmake --version"
echo ""
echo "3. Start OrbStack"
echo ""
echo "4. Open VSCode"
echo ""
echo "5. Future migration:"
echo ""
echo "   brew bundle"
echo ""
echo "====================================================="
