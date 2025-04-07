#!/bin/bash

# Exit on error
set -e

echo "Starting ZSH setup..."

# Function to detect Linux distribution type
detect_distro() {
    # Check for /etc/os-release file (most modern distributions have this)
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME=$ID
        DISTRO_FAMILY=$ID_LIKE
        echo "Detected distribution: $DISTRO_NAME"
        echo "Distribution family: $DISTRO_FAMILY"

        # Determine distribution type
        if [[ "$DISTRO_NAME" == "ubuntu" || "$DISTRO_NAME" == "debian" || "$DISTRO_FAMILY" == *"debian"* ]]; then
            echo "Detected Debian-based system"
            DISTRO_TYPE="debian"
        elif [[ "$DISTRO_NAME" == "fedora" || "$DISTRO_NAME" == "rhel" || "$DISTRO_NAME" == "centos" || "$DISTRO_NAME" == "rocky" || "$DISTRO_NAME" == "ol" || "$DISTRO_NAME" == "oracle" || "$DISTRO_NAME" == "almalinux" || "$DISTRO_FAMILY" == *"fedora"* || "$DISTRO_FAMILY" == *"rhel"* || "$DISTRO_FAMILY" == *"centos"* ]]; then
            echo "Detected RHEL-based system"
            DISTRO_TYPE="rhel"
        elif [[ "$DISTRO_NAME" == "arch" || "$DISTRO_NAME" == "manjaro" || "$DISTRO_FAMILY" == *"arch"* ]]; then
            echo "Detected Arch-based system"
            DISTRO_TYPE="arch"
        else
            echo "Unknown distribution: $DISTRO_NAME"
            echo "Attempting to detect package manager..."
            # Try to detect based on available package managers
            if command -v apt &> /dev/null || command -v apt-get &> /dev/null; then
                echo "Found apt/apt-get, assuming Debian-based"
                DISTRO_TYPE="debian"
            elif command -v dnf &> /dev/null || command -v yum &> /dev/null; then
                echo "Found dnf/yum, assuming RHEL-based"
                DISTRO_TYPE="rhel"
            elif command -v pacman &> /dev/null; then
                echo "Found pacman, assuming Arch-based"
                DISTRO_TYPE="arch"
            else
                echo "ERROR: Could not determine distribution type or package manager."
                echo "Please install ZSH and fzf manually, then run this script again."
                exit 1
            fi
        fi
    else
        echo "ERROR: /etc/os-release not found. Cannot determine distribution."
        exit 1
    fi
}

# Function to install packages based on distribution
install_package() {
    local package_name=$1
    echo "Installing $package_name..."
    
    case $DISTRO_TYPE in
        debian)
            sudo apt-get update
            sudo apt-get install -y $package_name
            ;;
        rhel)
            if command -v dnf &> /dev/null; then
                sudo dnf install -y $package_name
            else
                sudo yum install -y $package_name
            fi
            ;;
        arch)
            sudo pacman -Sy --noconfirm $package_name
            ;;
        *)
            echo "ERROR: Unknown distribution type: $DISTRO_TYPE"
            exit 1
            ;;
    esac
}

# Function to clean existing setup
clean_existing_setup() {
    echo "Cleaning existing setup..."
    
    # Check if oh-my-zsh is installed and uninstall it
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "Uninstalling existing Oh My ZSH..."
        # Try to run the uninstall script first
        if [ -f "$HOME/.oh-my-zsh/tools/uninstall.sh" ]; then
            sh "$HOME/.oh-my-zsh/tools/uninstall.sh" -y
        else
            echo "Manual cleanup of Oh My ZSH..."
            rm -rf "$HOME/.oh-my-zsh"
        fi
    fi

    # Remove existing zsh configurations
    echo "Removing existing ZSH configurations..."
    rm -f "$HOME/.zshrc" "$HOME/.zshrc.pre-oh-my-zsh" "$HOME/.zcompdump*"
    rm -rf "$HOME/.zsh_history"
}

# Detect the distribution
detect_distro

# Install dependencies
# Install ZSH if not already installed
if ! command -v zsh &> /dev/null; then
    install_package "zsh"
fi

# Install git if not already installed (needed for plugin installation)
if ! command -v git &> /dev/null; then
    install_package "git"
fi

# Install curl if not already installed (needed for Oh My ZSH installation)
if ! command -v curl &> /dev/null; then
    install_package "curl"
fi

# Install fzf
if ! command -v fzf &> /dev/null; then
    case $DISTRO_TYPE in
        debian)
            install_package "fzf"
            ;;
        rhel)
            # Some RHEL-based systems might need to enable additional repositories
            if command -v dnf &> /dev/null; then
                # Try to install from default repos first
                sudo dnf install -y fzf || {
                    echo "Could not install fzf from default repositories."
                    echo "Installing from git repository..."
                    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
                    ~/.fzf/install --all
                }
            else
                # Older RHEL systems with yum might not have fzf in repositories
                echo "Installing fzf from git repository..."
                git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
                ~/.fzf/install --all
            fi
            ;;
        arch)
            install_package "fzf"
            ;;
    esac
fi

# Clean existing setup
clean_existing_setup

# Install Oh My ZSH
echo "Installing Oh My ZSH..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh-autosuggestions
echo "Installing zsh-autosuggestions..."
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Install zsh-syntax-highlighting
echo "Installing zsh-syntax-highlighting..."
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Install Spaceship theme
echo "Installing Spaceship theme..."
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship-prompt" --depth=1
ln -sf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship-prompt/spaceship.zsh-theme" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/spaceship.zsh-theme"

# Create new .zshrc with desired configuration
echo "Creating new .zshrc..."
cat > "$HOME/.zshrc" << 'EOL'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Theme configuration
ZSH_THEME="spaceship"

# Plugins
plugins=(git docker docker-compose zsh-autosuggestions zsh-syntax-highlighting fzf zsh-interactive-cd)

# Source oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Spaceship Theme Configuration
SPACESHIP_PROMPT_ORDER=(
  user
  dir
  git
  python
  venv
  docker
  line_sep
  char
)

SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="❯ "
SPACESHIP_CHAR_SUFFIX=" "
SPACESHIP_USER_SHOW=always
SPACESHIP_PYTHON_SHOW=true
SPACESHIP_DOCKER_SHOW=true
EOL

# Check if ZSH is already the default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Would you like to change your default shell to ZSH? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        # Change default shell to ZSH
        echo "Changing default shell to ZSH..."
        chsh -s "$(which zsh)"
        echo "Default shell changed to ZSH."
    else
        echo "Default shell not changed. You can run 'chsh -s $(which zsh)' to change it later."
    fi
else
    echo "ZSH is already your default shell."
fi

echo "Setup complete! Please restart your terminal or run 'exec zsh' to see the new theme."
