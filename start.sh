#!/bin/bash

# =============================================================================
# All-in-One Deployment Script
# =============================================================================
# This script orchestrates the complete deployment process:
#   1. Bootstrap (Server initialization)
#   2. GitHub Setup (Authentication)
#   3. Clone Repositories
#   4. Configure Environment
#   5. Deploy Services
#   6. Health Check
#
# Usage:
#   ./start.sh [--skip-bootstrap] [--skip-github] [--non-interactive]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKIP_BOOTSTRAP=false
SKIP_GITHUB=false
NON_INTERACTIVE=false
PARALLEL=true

# Step tracking
CURRENT_STEP=0
TOTAL_STEPS=6

# =============================================================================
# Help Function
# =============================================================================

show_help() {
    cat << EOF
${BLUE}TikTok Internal APIs - All-in-One Deployment${NC}

${YELLOW}DESCRIPTION:${NC}
  Complete automated deployment of all 4 TikTok Internal API services.
  This script runs all deployment steps in sequence:

  Step 1: Bootstrap       - Install Docker, Git, configure firewall
  Step 2: GitHub Setup    - Configure authentication (SSH or PAT)
  Step 3: Clone Repos     - Clone all 4 service repositories
  Step 4: Configure Env   - Interactive environment setup
  Step 5: Deploy Services - Build and start all containers
  Step 6: Health Check    - Verify all services are healthy

${YELLOW}USAGE:${NC}
  ./start.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  --skip-bootstrap      Skip server initialization (if already done)
  --skip-github         Skip GitHub setup (if already configured)
  --skip-clone          Skip repository cloning (if already cloned)
  --non-interactive     Run with minimal prompts (use defaults)
  --sequential          Use sequential mode instead of parallel
  --help, -h           Show this help message

${YELLOW}EXAMPLES:${NC}
  # Full deployment (first time)
  ./start.sh

  # Skip bootstrap (server already configured)
  ./start.sh --skip-bootstrap

  # Skip GitHub setup (authentication already done)
  ./start.sh --skip-bootstrap --skip-github

  # Skip to deployment only
  ./start.sh --skip-bootstrap --skip-github --skip-clone

  # Non-interactive mode (use all defaults)
  ./start.sh --non-interactive

${YELLOW}ESTIMATED TIME:${NC}
  • Full deployment: 15-20 minutes
  • With skips: 5-10 minutes
  • Non-interactive: 10-15 minutes

${YELLOW}REQUIREMENTS:${NC}
  • Ubuntu 20.04+ / Debian 10+ / macOS 11+
  • sudo permissions (Linux) or admin access (macOS)
  • macOS: Homebrew auto-installs (Docker CLI + Colima)
  • GitHub repository access
  • RapidAPI key ready

${YELLOW}WHAT YOU'LL NEED:${NC}
  1. GitHub username/organization
  2. MongoDB URI (default provided)
  3. RapidAPI key
  4. Port preferences (defaults: 8082-8085)

EOF
    exit 0
}

# =============================================================================
# Utility Functions
# =============================================================================

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║          TikTok Internal APIs - All-in-One Deployment         ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step_header() {
    local step_num=$1
    local step_name=$2
    local description=$3

    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step $step_num/$TOTAL_STEPS: $step_name${NC}"
    echo -e "${BLUE}$description${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
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

print_progress() {
    local current=$1
    local total=$2
    local percentage=$((current * 100 / total))

    echo -ne "${CYAN}Progress: [$current/$total] ${percentage}%${NC}\r"
}

wait_user() {
    if [[ "$NON_INTERACTIVE" == false ]]; then
        echo ""
        read -p "Press Enter to continue or Ctrl+C to cancel..." -r
        echo ""
    fi
}

# =============================================================================
# Step 1: Bootstrap
# =============================================================================

step_bootstrap() {
    ((CURRENT_STEP++))
    print_step_header $CURRENT_STEP "Bootstrap Server" "Installing Docker, Git, and configuring firewall"

    if [[ "$SKIP_BOOTSTRAP" == true ]]; then
        print_warning "Skipping bootstrap (--skip-bootstrap)"
        return 0
    fi

    print_info "This will install Docker, Docker Compose, Git, and configure firewall"
    wait_user

    if bash "$SCRIPT_DIR/bootstrap.sh"; then
        print_success "Bootstrap completed successfully!"

        # Check if docker group was just added
        if ! groups | grep -q docker; then
            print_warning "Docker group added. You may need to re-run this script after logging out and back in."
            print_info "Or run: newgrp docker"
            wait_user
        fi
    else
        print_error "Bootstrap failed!"
        exit 1
    fi
}

# =============================================================================
# Step 2: GitHub Setup
# =============================================================================

step_github_setup() {
    ((CURRENT_STEP++))
    print_step_header $CURRENT_STEP "GitHub Authentication" "Configuring GitHub access for repository cloning"

    if [[ "$SKIP_GITHUB" == true ]]; then
        print_warning "Skipping GitHub setup (--skip-github)"
        return 0
    fi

    # Check if already configured
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        print_success "GitHub SSH already configured!"
        read -p "Reconfigure GitHub authentication? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing GitHub configuration"
            return 0
        fi
    fi

    print_info "You'll need to configure GitHub authentication"
    print_info "Recommended: SSH key (more secure for servers)"
    wait_user

    if bash "$SCRIPT_DIR/setup-github.sh" --method ssh; then
        print_success "GitHub authentication configured!"
    else
        print_error "GitHub setup failed!"
        exit 1
    fi
}

# =============================================================================
# Step 3: Clone Repositories
# =============================================================================

step_clone_repositories() {
    ((CURRENT_STEP++))
    print_step_header $CURRENT_STEP "Clone Repositories" "Cloning all 4 TikTok Internal API service repositories"

    # Check if repositories.conf is configured
    if grep -q "YOUR_GITHUB_USERNAME" "$SCRIPT_DIR/config/repositories.conf"; then
        print_error "GitHub username not configured in repositories.conf"
        echo ""
        print_info "Please edit config/repositories.conf:"
        print_info "Replace 'YOUR_GITHUB_USERNAME' with your actual GitHub username"
        echo ""

        if [[ "$NON_INTERACTIVE" == false ]]; then
            read -p "Enter your GitHub username: " github_username

            if [[ -n "$github_username" ]]; then
                sed -i "s/YOUR_GITHUB_USERNAME/$github_username/g" "$SCRIPT_DIR/config/repositories.conf"
                print_success "Updated repositories.conf with username: $github_username"
            else
                print_error "No username provided"
                exit 1
            fi
        else
            exit 1
        fi
    fi

    print_info "Cloning 4 repositories to ~/github/"
    wait_user

    local clone_flags=""
    if [[ "$PARALLEL" == true ]]; then
        clone_flags="--parallel"
        print_info "Using parallel cloning for faster setup"
    fi

    if bash "$SCRIPT_DIR/clone-repositories.sh" $clone_flags; then
        print_success "All repositories cloned successfully!"
    else
        print_error "Repository cloning failed!"
        exit 1
    fi
}

# =============================================================================
# Step 4: Configure Environment
# =============================================================================

step_configure_environment() {
    ((CURRENT_STEP++))
    print_step_header $CURRENT_STEP "Configure Environment" "Setting up environment variables and ports"

    print_info "This will guide you through environment configuration:"
    print_info "  • Environment selection (Production/Test)"
    print_info "  • MongoDB settings"
    print_info "  • API keys"
    print_info "  • Service ports"
    echo ""
    wait_user

    if bash "$SCRIPT_DIR/deploy-services.sh" --setup-env; then
        print_success "Environment configured successfully!"
    else
        print_error "Environment configuration failed!"
        exit 1
    fi
}

# =============================================================================
# Step 5: Deploy Services
# =============================================================================

step_deploy_services() {
    ((CURRENT_STEP++))
    print_step_header $CURRENT_STEP "Deploy Services" "Building and starting all Docker containers"

    print_info "Deploying 4 services:"
    print_info "  • user-info (User information provider)"
    print_info "  • user-posts (User posts data provider)"
    print_info "  • search-users (User discovery service)"
    print_info "  • post-detail (Post detail service)"
    echo ""
    wait_user

    local deploy_flags=""
    if [[ "$PARALLEL" == true ]]; then
        deploy_flags="--parallel"
        print_info "Using parallel deployment for faster setup"
    fi

    if bash "$SCRIPT_DIR/deploy-services.sh" $deploy_flags; then
        print_success "All services deployed successfully!"
    else
        print_error "Service deployment failed!"
        print_info "Check logs with: docker-compose logs"
        exit 1
    fi
}

# =============================================================================
# Step 6: Health Check
# =============================================================================

step_health_check() {
    ((CURRENT_STEP++))
    print_step_header $CURRENT_STEP "Health Check" "Verifying all services are running and healthy"

    print_info "Waiting 10 seconds for services to stabilize..."
    sleep 10

    echo ""
    if bash "$SCRIPT_DIR/health-check.sh"; then
        print_success "All services are healthy! 🎉"
    else
        print_warning "Some services may not be healthy yet"
        print_info "Services might still be starting up"
        print_info "You can check status with: ./health-check.sh --watch"
    fi
}

# =============================================================================
# Final Summary
# =============================================================================

print_summary() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   Deployment Complete! 🎉                      ║${NC}"
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo ""

    print_success "All 4 TikTok Internal API services are deployed!"
    echo ""

    echo -e "${YELLOW}📊 Service Status:${NC}"
    bash "$SCRIPT_DIR/health-check.sh" 2>/dev/null || true
    echo ""

    echo -e "${YELLOW}🔗 Service URLs:${NC}"

    # Read actual ports from services.conf
    if [[ -f "$SCRIPT_DIR/config/services.conf" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue

            read -r service_name port directory health_endpoint <<< "$line"
            echo "  • http://localhost:$port$health_endpoint ($service_name)"
        done < "$SCRIPT_DIR/config/services.conf"
    fi

    echo ""
    echo -e "${YELLOW}📚 Useful Commands:${NC}"
    echo "  • Check health:        ./health-check.sh"
    echo "  • Watch live status:   ./health-check.sh --watch"
    echo "  • View logs:           cd ../SERVICE_DIR && docker-compose logs -f"
    echo "  • Restart service:     ./deploy-services.sh --restart SERVICE_NAME"
    echo "  • Stop all:            ./deploy-services.sh --stop"
    echo ""

    echo -e "${GREEN}✨ Next steps:${NC}"
    echo "  1. Test API endpoints with curl"
    echo "  2. Configure your application to use these services"
    echo "  3. Set up monitoring and alerting"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-bootstrap)
                SKIP_BOOTSTRAP=true
                shift
                ;;
            --skip-github)
                SKIP_GITHUB=true
                shift
                ;;
            --skip-clone)
                SKIP_CLONE=true
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --sequential)
                PARALLEL=false
                shift
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

    # Print banner
    print_banner

    # Welcome message
    echo -e "${YELLOW}Welcome to TikTok Internal APIs Deployment!${NC}"
    echo ""
    echo "This script will guide you through the complete deployment process."
    echo "Estimated time: 15-20 minutes"
    echo ""

    if [[ "$NON_INTERACTIVE" == false ]]; then
        echo "You can press Ctrl+C at any time to cancel."
        echo ""
        read -p "Ready to start? (Y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            print_warning "Deployment cancelled"
            exit 0
        fi
    fi

    # Execute steps
    local start_time=$(date +%s)

    step_bootstrap
    step_github_setup

    if [[ "$SKIP_CLONE" != true ]]; then
        step_clone_repositories
    else
        print_warning "Skipping repository cloning (--skip-clone)"
        ((CURRENT_STEP++))
    fi

    step_configure_environment
    step_deploy_services
    step_health_check

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    # Print summary
    print_summary

    echo -e "${GREEN}⏱️  Total deployment time: ${minutes}m ${seconds}s${NC}"
    echo ""
}

# Check if running from correct directory
if [[ ! -f "$SCRIPT_DIR/bootstrap.sh" ]]; then
    print_error "Required scripts not found!"
    print_info "Please run this script from the deployment-automation directory"
    exit 1
fi

# Run main function
main "$@"
