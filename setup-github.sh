#!/bin/bash

# =============================================================================
# GitHub Setup Script - Authentication Configuration
# =============================================================================
# This script configures GitHub authentication for cloning private repositories.
# Supports both SSH key and Personal Access Token (PAT) methods.
#
# Usage:
#   ./setup-github.sh [--method ssh|pat] [--email your@email.com]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SSH_KEY_PATH="$HOME/.ssh/id_rsa_github"
SSH_CONFIG_PATH="$HOME/.ssh/config"
GIT_CONFIG_PATH="$HOME/.gitconfig"

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
# Help Function
# =============================================================================

show_help() {
    cat << EOF
${BLUE}TikTok Internal APIs - GitHub Authentication Setup${NC}

${YELLOW}DESCRIPTION:${NC}
  Configures GitHub authentication for cloning private repositories.
  Supports both SSH key and Personal Access Token (PAT) methods.

${YELLOW}USAGE:${NC}
  ./setup-github.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  --method ssh|pat       Authentication method (ssh or pat)
  --email EMAIL          Email for SSH key generation
  --help, -h            Show this help message

${YELLOW}AUTHENTICATION METHODS:${NC}

  ${GREEN}SSH Key (Recommended for servers):${NC}
    • Generates SSH key pair
    • Configures SSH automatically
    • More secure for long-term use
    • No expiration

  ${GREEN}Personal Access Token (PAT):${NC}
    • Uses GitHub token
    • Configures Git credential helper
    • Token can expire
    • Easier for temporary access

${YELLOW}EXAMPLES:${NC}
  # Interactive mode (choose method)
  ./setup-github.sh

  # SSH key method (automatic)
  ./setup-github.sh --method ssh

  # SSH with custom email
  ./setup-github.sh --method ssh --email you@example.com

  # Personal Access Token method
  ./setup-github.sh --method pat

${YELLOW}NEXT STEPS:${NC}
  After authentication setup:
  ./clone-repositories.sh           # Clone all repositories

${YELLOW}PAT REQUIREMENTS:${NC}
  If using PAT, create token at: https://github.com/settings/tokens/new
  Required scope: 'repo' (full control of private repositories)

EOF
    exit 0
}

# =============================================================================
# Git Configuration
# =============================================================================

configure_git() {
    print_header "Configuring Git"

    # Check if git is already configured
    if git config --global user.name &> /dev/null && git config --global user.email &> /dev/null; then
        CURRENT_NAME=$(git config --global user.name)
        CURRENT_EMAIL=$(git config --global user.email)
        print_success "Git already configured:"
        print_info "  Name: $CURRENT_NAME"
        print_info "  Email: $CURRENT_EMAIL"

        read -p "Keep current configuration? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            return 0
        fi
    fi

    # Configure git
    echo "Enter your Git configuration:"
    read -p "Name: " GIT_NAME
    read -p "Email: " GIT_EMAIL

    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"

    print_success "Git configured successfully"
    print_info "  Name: $GIT_NAME"
    print_info "  Email: $GIT_EMAIL"
}

# =============================================================================
# SSH Key Method
# =============================================================================

setup_ssh_key() {
    print_header "Setting Up SSH Key Authentication"

    # Check for existing SSH keys
    if [[ -f "$SSH_KEY_PATH" ]]; then
        print_warning "SSH key already exists at $SSH_KEY_PATH"
        read -p "Generate a new key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing SSH key"
            display_public_key
            return 0
        fi
    fi

    # Get email for SSH key
    if [[ -z "$SSH_EMAIL" ]]; then
        if git config --global user.email &> /dev/null; then
            SSH_EMAIL=$(git config --global user.email)
        else
            read -p "Enter email for SSH key: " SSH_EMAIL
        fi
    fi

    # Generate SSH key
    print_info "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -C "$SSH_EMAIL" -f "$SSH_KEY_PATH" -N ""

    print_success "SSH key generated successfully"

    # Add to SSH agent
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$SSH_KEY_PATH" 2>/dev/null || true

    # Configure SSH
    configure_ssh_config

    # Display public key
    display_public_key

    # Test connection
    test_ssh_connection
}

configure_ssh_config() {
    print_info "Configuring SSH..."

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Check if GitHub config already exists
    if grep -q "Host github.com" "$SSH_CONFIG_PATH" 2>/dev/null; then
        print_warning "GitHub SSH configuration already exists"
        return 0
    fi

    # Add GitHub SSH configuration
    cat >> "$SSH_CONFIG_PATH" << EOF

# GitHub Configuration (added by deployment automation)
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
EOF

    chmod 600 "$SSH_CONFIG_PATH"
    print_success "SSH configuration updated"
}

display_public_key() {
    print_header "Add This SSH Key to GitHub"

    echo "1. Copy the SSH public key below:"
    echo ""
    echo -e "${GREEN}$(cat ${SSH_KEY_PATH}.pub)${NC}"
    echo ""
    echo "2. Go to GitHub: https://github.com/settings/ssh/new"
    echo "3. Paste the key and give it a title (e.g., 'Production Server')"
    echo "4. Click 'Add SSH key'"
    echo ""

    read -p "Press Enter after adding the key to GitHub..." -r
}

test_ssh_connection() {
    print_info "Testing SSH connection to GitHub..."

    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "SSH connection to GitHub successful!"
    else
        print_warning "SSH connection test inconclusive (this is often normal)"
        print_info "You can test manually with: ssh -T git@github.com"
    fi
}

# =============================================================================
# Personal Access Token Method
# =============================================================================

setup_pat() {
    print_header "Setting Up Personal Access Token (PAT)"

    print_info "You'll need to create a GitHub Personal Access Token:"
    echo ""
    echo "1. Go to: https://github.com/settings/tokens/new"
    echo "2. Select scopes: 'repo' (full control of private repositories)"
    echo "3. Generate token and copy it"
    echo ""

    read -p "Press Enter when you have your token ready..." -r
    echo ""

    read -sp "Paste your GitHub Personal Access Token: " GITHUB_TOKEN
    echo ""

    if [[ -z "$GITHUB_TOKEN" ]]; then
        print_error "No token provided"
        exit 1
    fi

    # Configure Git credential helper
    configure_git_credentials "$GITHUB_TOKEN"

    # Test token
    test_pat_connection "$GITHUB_TOKEN"
}

configure_git_credentials() {
    local token=$1

    print_info "Configuring Git credential helper..."

    # Store credentials
    git config --global credential.helper store

    # Create credentials file
    mkdir -p "$HOME/.git-credentials"
    echo "https://oauth2:${token}@github.com" > "$HOME/.git-credentials"
    chmod 600 "$HOME/.git-credentials"

    print_success "Git credentials configured"
}

test_pat_connection() {
    local token=$1

    print_info "Testing GitHub API access..."

    RESPONSE=$(curl -s -H "Authorization: token $token" https://api.github.com/user)

    if echo "$RESPONSE" | grep -q "login"; then
        USERNAME=$(echo "$RESPONSE" | grep -o '"login": "[^"]*' | cut -d'"' -f4)
        print_success "GitHub API access successful!"
        print_info "  Authenticated as: $USERNAME"
    else
        print_error "GitHub API access failed"
        print_warning "Please check your token and try again"
        exit 1
    fi
}

# =============================================================================
# Method Selection
# =============================================================================

select_method() {
    print_header "Select GitHub Authentication Method"

    echo "Choose authentication method:"
    echo "  1) SSH Key (recommended for servers)"
    echo "  2) Personal Access Token (PAT)"
    echo ""

    read -p "Enter choice (1 or 2): " -n 1 -r
    echo ""

    case $REPLY in
        1)
            AUTH_METHOD="ssh"
            ;;
        2)
            AUTH_METHOD="pat"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "GitHub Authentication Setup"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --method)
                AUTH_METHOD="$2"
                shift 2
                ;;
            --email)
                SSH_EMAIL="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Configure Git
    configure_git

    # Select authentication method if not specified
    if [[ -z "$AUTH_METHOD" ]]; then
        select_method
    fi

    # Execute selected method
    case $AUTH_METHOD in
        ssh)
            setup_ssh_key
            ;;
        pat)
            setup_pat
            ;;
        *)
            print_error "Invalid authentication method: $AUTH_METHOD"
            exit 1
            ;;
    esac

    # Summary
    print_header "GitHub Authentication Complete! 🎉"

    print_success "GitHub authentication configured successfully"
    echo ""
    print_info "Next steps:"
    echo "  1. Clone repositories:"
    echo "     ./clone-repositories.sh"
    echo ""
    echo "  2. Deploy services:"
    echo "     ./deploy-services.sh"
}

# Run main function
main "$@"
