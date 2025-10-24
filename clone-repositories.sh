#!/bin/bash

# =============================================================================
# Repository Cloning Script
# =============================================================================
# This script clones all required repositories for TikTok Internal APIs.
# Reads configuration from config/repositories.conf
#
# Usage:
#   ./clone-repositories.sh [--parallel] [--force]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/repositories.conf"
GITHUB_DIR="$HOME/github"
PARALLEL=false
FORCE=false

# Counters
TOTAL_REPOS=0
SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

# Temporary files tracking
declare -a TEMP_LOG_FILES=()

# Cleanup function for temporary files
cleanup_temp_files() {
    for temp_file in "${TEMP_LOG_FILES[@]}"; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file" 2>/dev/null || true
        fi
    done
}

# Register cleanup on exit
trap cleanup_temp_files EXIT

# =============================================================================
# Network Connectivity Check
# =============================================================================

check_network() {
    local test_hosts=("github.com" "8.8.8.8")
    local connected=false

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 2 "$host" &> /dev/null; then
            connected=true
            break
        fi
    done

    if [[ "$connected" == false ]]; then
        print_error "No network connectivity detected"
        print_info "This script requires internet access to clone repositories from GitHub"
        echo ""
        print_info "Please check your network connection and try again"
        exit 1
    fi
}

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
${BLUE}TikTok Internal APIs - Repository Cloning${NC}

${YELLOW}DESCRIPTION:${NC}
  Clones all 4 TikTok Internal API service repositories:
  • tiktok-user-posts (Port 8083)
  • tiktok-user-info (Port 8082)
  • tiktok-search-users (Port 8084)
  • tiktok-post-detail (Port 8085)

${YELLOW}USAGE:${NC}
  ./clone-repositories.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  --parallel            Clone repositories in parallel (faster)
  --force              Remove existing directories and re-clone
  --help, -h           Show this help message

${YELLOW}EXAMPLES:${NC}
  # Sequential cloning (safer)
  ./clone-repositories.sh

  # Parallel cloning (faster)
  ./clone-repositories.sh --parallel

  # Force re-clone existing repositories
  ./clone-repositories.sh --force

  # Parallel + Force
  ./clone-repositories.sh --parallel --force

${YELLOW}CONFIGURATION:${NC}
  Repositories are defined in: config/repositories.conf
  Target directory: ~/github/

${YELLOW}NEXT STEPS:${NC}
  After cloning:
  ./deploy-services.sh              # Deploy all services

${YELLOW}REQUIREMENTS:${NC}
  • GitHub authentication configured (run ./setup-github.sh first)
  • Network access to GitHub

EOF
    exit 0
}

# =============================================================================
# Input Validation
# =============================================================================

validate_config_line() {
    local repo_url=$1
    local branch=$2
    local target_dir=$3

    # Validate repo URL format (GitHub only)
    if ! [[ "$repo_url" =~ ^(https://|git@)github\.com[:/][A-Za-z0-9_-]+/[A-Za-z0-9_-]+\.git$ ]]; then
        print_error "Invalid repository URL: $repo_url"
        print_info "Expected format: git@github.com:user/repo.git or https://github.com/user/repo.git"
        return 1
    fi

    # Validate branch name (alphanumeric, dash, underscore, slash)
    if ! [[ "$branch" =~ ^[A-Za-z0-9/_-]+$ ]]; then
        print_error "Invalid branch name: $branch"
        return 1
    fi

    # Validate target directory (no dangerous characters)
    if [[ "$target_dir" =~ [\$\`\;\|\&] ]]; then
        print_error "Invalid target directory: $target_dir"
        print_info "Directory path contains dangerous characters"
        return 1
    fi

    return 0
}

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    print_header "Loading Repository Configuration"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        print_info "Please create the file with repository information"
        exit 1
    fi

    # Count repositories (excluding comments and empty lines)
    TOTAL_REPOS=$(grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$' | wc -l)

    if [[ $TOTAL_REPOS -eq 0 ]]; then
        print_error "No repositories configured in $CONFIG_FILE"
        exit 1
    fi

    print_success "Found $TOTAL_REPOS repositories to clone"
}

# =============================================================================
# Repository Cloning
# =============================================================================

clone_repository() {
    local repo_url=$1
    local branch=$2
    local target_dir=$3

    local repo_name=$(basename "$target_dir")

    # Check if directory already exists
    if [[ -d "$target_dir" ]]; then
        if [[ "$FORCE" == true ]]; then
            print_warning "Removing existing directory: $target_dir"
            rm -rf "$target_dir"
        else
            print_warning "Directory already exists: $target_dir (skipped)"
            ((++SKIP_COUNT))
            return 2  # Return code 2 for skip
        fi
    fi

    # Clone repository
    print_info "Cloning $repo_name..."

    # Create secure temporary log file
    local temp_log=$(mktemp "${TMPDIR:-/tmp}/clone_${repo_name}_XXXXXX.log")
    TEMP_LOG_FILES+=("$temp_log")

    if git clone --branch "$branch" "$repo_url" "$target_dir" &> "$temp_log"; then
        print_success "$repo_name cloned successfully"
        ((++SUCCESS_COUNT))
        return 0  # Return code 0 for success
    else
        print_error "Failed to clone $repo_name"
        print_info "See log: $temp_log"
        ((++FAIL_COUNT))
        return 1  # Return code 1 for failure
    fi
}

# =============================================================================
# Parallel Cloning
# =============================================================================

clone_all_parallel() {
    print_header "Cloning Repositories (Parallel Mode)"

    local pids=()
    declare -a exit_codes=()

    # Reset counters (they'll be incremented in subshells, but we'll recount)
    local parallel_success=0
    local parallel_skip=0
    local parallel_fail=0

    # Read configuration and start cloning in background
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Parse line: REPO_URL BRANCH TARGET_DIR
        read -r repo_url branch target_dir <<< "$line"

        # Validate input
        if ! validate_config_line "$repo_url" "$branch" "$target_dir"; then
            print_warning "Skipping invalid config line"
            continue
        fi

        # Clone in background
        (clone_repository "$repo_url" "$branch" "$target_dir") &
        pids+=($!)

    done < "$CONFIG_FILE"

    # Wait for all background processes and collect exit codes
    print_info "Waiting for all cloning operations to complete..."

    for pid in "${pids[@]}"; do
        wait $pid
        local exit_code=$?
        exit_codes+=($exit_code)

        # Count based on exit code
        case $exit_code in
            0) ((++parallel_success)) ;;
            1) ((++parallel_fail)) ;;
            2) ((++parallel_skip)) ;;
        esac
    done

    # Update global counters with parallel results
    SUCCESS_COUNT=$parallel_success
    SKIP_COUNT=$parallel_skip
    FAIL_COUNT=$parallel_fail
}

# =============================================================================
# Sequential Cloning
# =============================================================================

clone_all_sequential() {
    print_header "Cloning Repositories (Sequential Mode)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Parse line: REPO_URL BRANCH TARGET_DIR
        read -r repo_url branch target_dir <<< "$line"

        # Validate input
        if ! validate_config_line "$repo_url" "$branch" "$target_dir"; then
            print_warning "Skipping invalid config line"
            continue
        fi

        clone_repository "$repo_url" "$branch" "$target_dir"

    done < "$CONFIG_FILE"
}

# =============================================================================
# Verification
# =============================================================================

verify_repositories() {
    print_header "Verifying Cloned Repositories"

    local verified=0
    local failed=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        read -r repo_url branch target_dir <<< "$line"
        local repo_name=$(basename "$target_dir")

        if [[ -d "$target_dir/.git" ]]; then
            # Check if correct branch
            cd "$target_dir"
            current_branch=$(git rev-parse --abbrev-ref HEAD)

            if [[ "$current_branch" == "$branch" ]]; then
                print_success "$repo_name: ✓ (branch: $branch)"
                ((++verified))
            else
                print_warning "$repo_name: branch mismatch (expected: $branch, got: $current_branch)"
                ((++failed))
            fi
        else
            print_error "$repo_name: not found or not a git repository"
            ((++failed))
        fi

    done < "$CONFIG_FILE"

    echo ""
    print_info "Verification: $verified verified, $failed failed"
}

# =============================================================================
# Summary Report
# =============================================================================

display_summary() {
    print_header "Cloning Summary"

    echo "Total repositories: $TOTAL_REPOS"
    echo -e "${GREEN}Successfully cloned: $SUCCESS_COUNT${NC}"
    echo -e "${YELLOW}Skipped (already exists): $SKIP_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""

    if [[ $FAIL_COUNT -gt 0 ]]; then
        print_warning "Some repositories failed to clone"
        print_info "Check logs in /tmp/clone_*.log for details"
        return 1
    else
        print_success "All repositories cloned successfully!"
        return 0
    fi
}

# =============================================================================
# Next Steps
# =============================================================================

display_next_steps() {
    print_header "Next Steps"

    print_info "Repositories are ready for deployment"
    echo ""
    echo "  1. Configure environment variables:"
    echo "     - Edit .env files in each repository"
    echo "     - Or use the deploy script with interactive mode"
    echo ""
    echo "  2. Deploy all services:"
    echo "     ./deploy-services.sh"
    echo ""
    echo "  3. Check service health:"
    echo "     ./health-check.sh"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "TikTok Internal APIs - Repository Cloning"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parallel)
                PARALLEL=true
                shift
                ;;
            --force)
                FORCE=true
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

    # Display options
    if [[ "$PARALLEL" == true ]]; then
        print_info "Parallel cloning enabled"
    fi

    if [[ "$FORCE" == true ]]; then
        print_warning "Force mode enabled - existing directories will be removed"
    fi

    # Check network connectivity
    check_network

    # Load configuration
    load_config

    # Create github directory
    mkdir -p "$GITHUB_DIR"

    # Clone repositories
    if [[ "$PARALLEL" == true ]]; then
        clone_all_parallel
    else
        clone_all_sequential
    fi

    # Verify repositories
    verify_repositories

    # Display summary
    if display_summary; then
        display_next_steps
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
