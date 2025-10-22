#!/bin/bash

# =============================================================================
# Bootstrap Script - Server Initialization for Internal APIs
# =============================================================================
# This script initializes a new server with all required dependencies
# for deploying TikTok Internal API services.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ComBba/tiktok-internal-API-deployment-automation/main/bootstrap.sh | bash
#   OR
#   ./bootstrap.sh [--dry-run]
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEPLOYMENT_DIR="$HOME/deployment-automation"
GITHUB_DIR="$HOME/github"
DRY_RUN=false

# =============================================================================
# Help Function
# =============================================================================

show_help() {
    cat << EOF
${BLUE}TikTok Internal APIs - Server Bootstrap${NC}

${YELLOW}DESCRIPTION:${NC}
  Initializes a new server with all required dependencies for deploying
  TikTok Internal API services (User Posts, User Info, Search Users, Post Detail).

${YELLOW}USAGE:${NC}
  ./bootstrap.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  --dry-run         Preview changes without making modifications
  --help, -h        Show this help message

${YELLOW}WHAT IT INSTALLS:${NC}
  • Docker CE (latest)
  • Docker Compose
  • Git
  • Essential tools (curl, wget, jq, net-tools)
  • Firewall configuration (ports 8082-8085)

${YELLOW}EXAMPLES:${NC}
  # Standard installation
  ./bootstrap.sh

  # Preview what will be installed
  ./bootstrap.sh --dry-run

${YELLOW}NEXT STEPS:${NC}
  After bootstrap completes:
  1. ./setup-github.sh              # Configure GitHub authentication
  2. ./clone-repositories.sh        # Clone all service repositories
  3. ./deploy-services.sh           # Deploy services
  4. ./health-check.sh              # Verify deployment

${YELLOW}REQUIREMENTS:${NC}
  • Ubuntu 20.04+ / Debian 10+ / macOS 11+
  • sudo permissions (Linux) or admin access (macOS)
  • Internet connection

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            echo -e "${YELLOW}🔍 DRY RUN MODE - No changes will be made${NC}"
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# =============================================================================
# System Checks
# =============================================================================

check_os() {
    print_header "Checking Operating System"

    # Detect MacOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_VERSION=$(sw_vers -productVersion)
        print_success "Detected OS: macOS $OS_VERSION"
        return 0
    fi

    # Detect Linux
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_success "Detected OS: $NAME $VERSION"
    else
        print_error "Cannot detect OS. This script supports Ubuntu/Debian/macOS only."
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        print_error "This script supports Ubuntu/Debian/macOS only. Detected: $OS"
        exit 1
    fi
}

check_sudo() {
    print_header "Checking Sudo Permissions"

    # MacOS - Check admin access differently
    if [[ "$OS" == "macos" ]]; then
        if groups | grep -q admin; then
            print_success "Admin permissions available"
        else
            print_warning "This script requires admin permissions."
            print_info "You may be prompted for your password."
        fi
        return 0
    fi

    # Linux - Check sudo
    if sudo -n true 2>/dev/null; then
        print_success "Sudo permissions available"
    else
        print_warning "This script requires sudo permissions for installing packages."
        print_info "You may be prompted for your password."
    fi
}

# =============================================================================
# Docker Installation
# =============================================================================

install_docker() {
    print_header "Installing Docker"

    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
        print_success "Docker already installed (version: $DOCKER_VERSION)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would install Docker"
        return 0
    fi

    # MacOS Docker Installation
    if [[ "$OS" == "macos" ]]; then
        print_warning "Docker Desktop is required for macOS"
        print_info "Please install Docker Desktop manually:"
        echo ""
        echo "  1. Download Docker Desktop for Mac:"
        echo "     https://www.docker.com/products/docker-desktop/"
        echo ""
        echo "  2. Install Docker Desktop"
        echo "  3. Start Docker Desktop from Applications"
        echo "  4. Wait for Docker to start (you'll see a whale icon in the menu bar)"
        echo ""
        read -p "Press Enter after Docker Desktop is installed and running..."

        # Verify Docker is running
        if command -v docker &> /dev/null && docker ps &> /dev/null; then
            print_success "Docker is running!"
            return 0
        else
            print_error "Docker is not running. Please start Docker Desktop and try again."
            exit 1
        fi
    fi

    # Linux Docker Installation
    print_info "Installing Docker..."

    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Update package index
    sudo apt-get update

    # Install prerequisites
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker $USER

    print_success "Docker installed successfully"
    print_warning "You may need to log out and back in for docker group membership to take effect"
}

# =============================================================================
# Docker Compose Installation
# =============================================================================

install_docker_compose() {
    print_header "Installing Docker Compose"

    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | cut -d ' ' -f4 | cut -d ',' -f1)
        print_success "Docker Compose already installed (version: $COMPOSE_VERSION)"
        return 0
    fi

    # Check if docker compose plugin is available
    if docker compose version &> /dev/null; then
        print_success "Docker Compose plugin available (docker compose)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would install Docker Compose"
        return 0
    fi

    # MacOS - Docker Desktop includes Docker Compose
    if [[ "$OS" == "macos" ]]; then
        print_success "Docker Compose is included in Docker Desktop"
        return 0
    fi

    # Linux - Install Docker Compose standalone
    print_info "Installing Docker Compose standalone..."

    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    print_success "Docker Compose installed successfully (version: $COMPOSE_VERSION)"
}

# =============================================================================
# Git Installation
# =============================================================================

install_git() {
    print_header "Installing Git"

    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | cut -d ' ' -f3)
        print_success "Git already installed (version: $GIT_VERSION)"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would install Git"
        return 0
    fi

    # MacOS - Prompt to install Xcode Command Line Tools
    if [[ "$OS" == "macos" ]]; then
        print_info "Installing Xcode Command Line Tools (includes Git)..."
        xcode-select --install 2>/dev/null || true
        print_warning "If a popup appears, please click 'Install' and wait for completion"
        read -p "Press Enter after installation completes..."

        if command -v git &> /dev/null; then
            print_success "Git installed successfully"
            return 0
        else
            print_error "Git installation failed. Please install Xcode Command Line Tools manually."
            exit 1
        fi
    fi

    # Linux - Install Git via apt
    print_info "Installing Git..."
    sudo apt-get update
    sudo apt-get install -y git

    print_success "Git installed successfully"
}

# =============================================================================
# Additional Tools Installation
# =============================================================================

install_additional_tools() {
    print_header "Installing Additional Tools"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would install: curl, wget, jq, net-tools"
        return 0
    fi

    # MacOS - Install via Homebrew
    if [[ "$OS" == "macos" ]]; then
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            print_warning "Homebrew is not installed"
            print_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi

        print_info "Installing essential tools via Homebrew..."
        brew install curl wget jq
        print_success "Additional tools installed successfully"
        return 0
    fi

    # Linux - Install via apt
    print_info "Installing essential tools..."
    sudo apt-get update
    sudo apt-get install -y curl wget jq net-tools

    print_success "Additional tools installed"
}

# =============================================================================
# Firewall Configuration
# =============================================================================

configure_firewall() {
    print_header "Configuring Firewall"

    # MacOS - No firewall configuration needed for local development
    if [[ "$OS" == "macos" ]]; then
        print_success "Firewall configuration not required for macOS (local development)"
        return 0
    fi

    if ! command -v ufw &> /dev/null; then
        print_warning "UFW not installed, skipping firewall configuration"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would configure firewall ports: 8082, 8083, 8084, 8085"
        return 0
    fi

    print_info "Opening ports for Internal APIs..."

    # Allow SSH first
    sudo ufw allow 22/tcp >/dev/null 2>&1 || true

    # Allow Internal API ports
    sudo ufw allow 8082/tcp >/dev/null 2>&1 || true  # User Info
    sudo ufw allow 8083/tcp >/dev/null 2>&1 || true  # User Posts
    sudo ufw allow 8084/tcp >/dev/null 2>&1 || true  # Search Users
    sudo ufw allow 8085/tcp >/dev/null 2>&1 || true  # Post Detail

    print_success "Firewall configured for ports: 8082, 8083, 8084, 8085"
}

# =============================================================================
# Directory Setup
# =============================================================================

setup_directories() {
    print_header "Setting Up Directories"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would create: $DEPLOYMENT_DIR, $GITHUB_DIR"
        return 0
    fi

    mkdir -p "$DEPLOYMENT_DIR"
    mkdir -p "$DEPLOYMENT_DIR/config"
    mkdir -p "$GITHUB_DIR"

    print_success "Directories created:"
    print_info "  - $DEPLOYMENT_DIR (deployment scripts)"
    print_info "  - $GITHUB_DIR (service repositories)"
}

# =============================================================================
# Download Deployment Scripts
# =============================================================================

download_scripts() {
    print_header "Downloading Deployment Scripts"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would download deployment scripts from GitHub"
        return 0
    fi

    # Check if we're running from a local copy
    if [[ -f "$DEPLOYMENT_DIR/bootstrap.sh" ]]; then
        print_success "Running from local deployment directory"
        return 0
    fi

    print_warning "Script download from GitHub not implemented yet"
    print_info "Please clone the repository manually:"
    print_info "  cd $HOME"
    print_info "  git clone https://github.com/ComBba/tiktok-internal-API-deployment-automation.git"
}

# =============================================================================
# System Information
# =============================================================================

display_system_info() {
    print_header "System Information"

    echo "OS: $NAME $VERSION"
    echo "Architecture: $(uname -m)"
    echo "Kernel: $(uname -r)"

    if command -v docker &> /dev/null; then
        echo "Docker: $(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)"
    fi

    if command -v docker-compose &> /dev/null; then
        echo "Docker Compose: $(docker-compose --version | cut -d ' ' -f4 | cut -d ',' -f1)"
    elif docker compose version &> /dev/null; then
        echo "Docker Compose: $(docker compose version --short)"
    fi

    if command -v git &> /dev/null; then
        echo "Git: $(git --version | cut -d ' ' -f3)"
    fi

    echo ""
}

# =============================================================================
# Next Steps
# =============================================================================

display_next_steps() {
    print_header "Bootstrap Complete! 🎉"

    print_success "Server is ready for deployment"
    echo ""
    print_info "Next steps:"
    echo "  1. Set up GitHub authentication:"
    echo "     cd $DEPLOYMENT_DIR && ./setup-github.sh"
    echo ""
    echo "  2. Clone repositories:"
    echo "     ./clone-repositories.sh"
    echo ""
    echo "  3. Deploy services:"
    echo "     ./deploy-services.sh"
    echo ""
    echo "  4. Check service health:"
    echo "     ./health-check.sh"
    echo ""

    if groups | grep -q docker; then
        print_success "Docker group membership active"
    else
        print_warning "Please log out and back in to activate docker group membership"
        print_info "Or run: newgrp docker"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "TikTok Internal APIs - Server Bootstrap"

    echo "This script will install and configure:"
    echo "  - Docker & Docker Compose"
    echo "  - Git"
    echo "  - Essential tools (curl, wget, jq)"
    echo "  - Firewall rules for ports 8082-8085"
    echo ""

    if [[ "$DRY_RUN" == false ]]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Installation cancelled"
            exit 0
        fi
    fi

    # Execute installation steps
    check_os
    check_sudo
    install_docker
    install_docker_compose
    install_git
    install_additional_tools
    configure_firewall
    setup_directories
    download_scripts

    # Display results
    echo ""
    display_system_info
    display_next_steps
}

# Run main function
main "$@"
