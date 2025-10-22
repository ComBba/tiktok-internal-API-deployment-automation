#!/bin/bash

# =============================================================================
# Service Deployment Script
# =============================================================================
# This script deploys all TikTok Internal API services.
# Reads configuration from config/services.conf
#
# Usage:
#   ./deploy-services.sh [--parallel] [--service SERVICE_NAME] [--env prod|test]
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
CONFIG_FILE="$SCRIPT_DIR/config/services.conf"
GITHUB_DIR="$HOME/github"
PARALLEL=false
SPECIFIC_SERVICE=""
ENVIRONMENT="prod"

# Counters
TOTAL_SERVICES=0
SUCCESS_COUNT=0
FAIL_COUNT=0

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

# Cross-platform sed in-place function
# macOS (BSD sed) requires -i '', Linux (GNU sed) accepts -i
sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS (BSD sed)
        sed -i '' "$@"
    else
        # Linux (GNU sed)
        sed -i "$@"
    fi
}

# Docker Compose command wrapper
# Supports both docker-compose (v1) and docker compose (v2)
docker_compose() {
    if command -v docker-compose &> /dev/null; then
        docker-compose "$@"
    else
        docker compose "$@"
    fi
}

# =============================================================================
# Help Function
# =============================================================================

show_help() {
    cat << EOF
${BLUE}TikTok Internal APIs - Service Deployment${NC}

${YELLOW}DESCRIPTION:${NC}
  Deploys 4 TikTok Internal API services with Docker Compose:
  • user-info (Port 8082) - TikTok user information provider
  • user-posts (Port 8083) - User posts data provider
  • search-users (Port 8084) - CAPTCHA-free user discovery
  • post-detail (Port 8085) - Post detail with 4-tier fallback

${YELLOW}USAGE:${NC}
  ./deploy-services.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  --parallel                Deploy all services in parallel (faster)
  --service SERVICE_NAME    Deploy specific service only
  --env prod|test          Environment (default: prod)
  --stop                   Stop all services
  --restart SERVICE_NAME   Restart specific service
  --setup-env              Interactive environment variable setup
  --help, -h               Show this help message

${YELLOW}EXAMPLES:${NC}
  # Interactive environment setup (RECOMMENDED for first time)
  ./deploy-services.sh --setup-env
    → Guides through: environment, MongoDB, API keys, and PORTS
    → Default ports: 8082, 8083, 8084, 8085
    → Can customize ports for new server

  # Deploy all services (sequential)
  ./deploy-services.sh

  # Deploy all services (parallel - faster)
  ./deploy-services.sh --parallel

  # Deploy specific service
  ./deploy-services.sh --service user-posts

  # Stop all services
  ./deploy-services.sh --stop

  # Restart specific service
  ./deploy-services.sh --restart user-info

${YELLOW}ENVIRONMENT SETUP:${NC}
  Before deployment, ensure .env files exist in each service directory.
  Use --setup-env for interactive configuration including port customization.

${YELLOW}CONFIGURATION:${NC}
  Services are defined in: config/services.conf

${YELLOW}NEXT STEPS:${NC}
  After deployment:
  ./health-check.sh                 # Verify all services are healthy

EOF
    exit 0
}

# =============================================================================
# Cache Management Functions
# =============================================================================

CACHE_FILE="$SCRIPT_DIR/.deployment_cache"

save_cache() {
    local key=$1
    local value=$2

    # Create or update cache file
    if [[ -f "$CACHE_FILE" ]]; then
        # Remove existing key if present
        grep -v "^${key}=" "$CACHE_FILE" > "${CACHE_FILE}.tmp" 2>/dev/null || true
        mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
    fi

    # Append new value
    echo "${key}=${value}" >> "$CACHE_FILE"
}

load_cache() {
    local key=$1

    if [[ -f "$CACHE_FILE" ]]; then
        grep "^${key}=" "$CACHE_FILE" | cut -d= -f2-
    fi
}

clear_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        rm -f "$CACHE_FILE"
        print_info "Cache cleared"
    fi
}

apply_configuration_from_cache() {
    local cached_ports=("$@")

    print_header "Applying Configuration from Cache"

    # Service definitions
    local service_defs=(
        "8082:$GITHUB_DIR/tiktok-user-info:User Info API"
        "8083:$GITHUB_DIR/tiktok-user-posts:User Posts API"
        "8084:$GITHUB_DIR/tiktok-search-users:Search Users API"
        "8085:$GITHUB_DIR/tiktok-post-detail:Post Detail API"
    )

    local idx=0
    for service_def in "${service_defs[@]}"; do
        IFS=':' read -r default_port dir description <<< "$service_def"
        local service_name=$(basename "$dir")

        if [[ ! -d "$dir" ]]; then
            print_warning "$service_name: Directory not found, skipping"
            ((idx++))
            continue
        fi

        local port=${cached_ports[$idx]}
        print_info "Configuring $service_name (Port: $port)..."

        # Check if .env already exists
        if [[ -f "$dir/.env" ]]; then
            print_warning "$service_name: .env file already exists (backing up)"
            local backup_file="$dir/.env.backup.$(date +%Y%m%d_%H%M%S)"
            mv "$dir/.env" "$backup_file"
            print_info "Backed up to: $(basename $backup_file)"
        fi

        # Use service's .env.example if it exists, otherwise use our template
        local source_template=""
        if [[ -f "$dir/.env.example" ]]; then
            source_template="$dir/.env.example"
            print_info "Using service's .env.example"
        else
            source_template="$TEMPLATE"
            print_info "Using deployment template"
        fi

        # Copy template
        cp "$source_template" "$dir/.env"

        # Detect environment variable naming convention from the copied file
        local uses_mongodb_uri=false
        if grep -q "MONGODB_URI" "$dir/.env"; then
            uses_mongodb_uri=true
        fi

        # Replace values (using cross-platform sed_inplace function)
        # Use | as delimiter to avoid conflicts with special chars in values
        sed_inplace "s|PORT=.*|PORT=$port|" "$dir/.env"

        if [[ "$uses_mongodb_uri" == true ]]; then
            # Service uses MONGODB_URI naming
            sed_inplace "s|MONGODB_URI=.*|MONGODB_URI=$MONGO_URI|" "$dir/.env"
            sed_inplace "s|MONGODB_DATABASE=.*|MONGODB_DATABASE=$MONGO_DB|" "$dir/.env"
        else
            # Service uses MONGO_URI naming
            sed_inplace "s|MONGO_URI=.*|MONGO_URI=$MONGO_URI|" "$dir/.env"
            sed_inplace "s|MONGO_DB=.*|MONGO_DB=$MONGO_DB|" "$dir/.env"
        fi

        sed_inplace "s|INTERNAL_API_KEY=.*|INTERNAL_API_KEY=$API_KEY|" "$dir/.env"
        sed_inplace "s|API_MASTER_KEY=.*|API_MASTER_KEY=$API_KEY|" "$dir/.env"

        print_success "$service_name configured (Port: $port)"
        ((idx++))
    done

    # Update services.conf
    update_services_conf "${cached_ports[@]}"

    print_success "All services configured from cache!"
}

update_services_conf() {
    local ports=("$@")

    print_header "Updating Service Configuration"
    print_info "Updating config/services.conf with new ports..."

    # Backup original
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    fi

    # Create new services.conf
    cat > "$CONFIG_FILE" << EOF
# =============================================================================
# Service Configuration
# =============================================================================
# Format: SERVICE_NAME PORT DIRECTORY HEALTH_ENDPOINT
#
# This file was auto-generated by deploy-services.sh --setup-env
# Generated at: $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

EOF

    # Service definitions
    local service_defs=(
        "8082:$GITHUB_DIR/tiktok-user-info:User Info API"
        "8083:$GITHUB_DIR/tiktok-user-posts:User Posts API"
        "8084:$GITHUB_DIR/tiktok-search-users:Search Users API"
        "8085:$GITHUB_DIR/tiktok-post-detail:Post Detail API"
    )

    local idx=0
    for service_def in "${service_defs[@]}"; do
        IFS=':' read -r default_port dir description <<< "$service_def"
        local service_name=$(basename "$dir")

        if [[ ! -d "$dir" ]]; then
            ((idx++))
            continue
        fi

        local port=${ports[$idx]}

        # Convert full service names to short names
        case $service_name in
            tiktok-user-info)
                short_name="user-info"
                ;;
            tiktok-user-posts)
                short_name="user-posts"
                ;;
            tiktok-search-users)
                short_name="search-users"
                ;;
            tiktok-post-detail)
                short_name="post-detail"
                ;;
            *)
                short_name=$service_name
                ;;
        esac

        echo "$short_name $port $dir /health" >> "$CONFIG_FILE"
        ((idx++))
    done

    print_success "Service configuration updated"

    # Display summary
    print_header "Configuration Summary"

    echo "Environment: $ENV_TYPE"
    echo "MongoDB Database: $MONGO_DB"
    echo ""
    echo "Service Ports:"
    idx=0
    for service_def in "${service_defs[@]}"; do
        IFS=':' read -r default_port dir description <<< "$service_def"
        if [[ -d "$dir" ]]; then
            local port=${ports[$idx]}
            echo "  • $description: $port"
        fi
        ((idx++))
    done
    echo ""

    print_success "All services configured!"
    echo ""
    print_info "Next steps:"
    echo "  1. Deploy services:"
    echo "     ./deploy-services.sh --parallel"
    echo ""
    echo "  2. Check health:"
    echo "     ./health-check.sh"
}

# =============================================================================
# Interactive Environment Setup
# =============================================================================

interactive_env_setup() {
    print_header "Interactive Environment Setup"

    print_info "This will guide you through environment variable configuration."
    echo ""

    # Check for existing cache
    if [[ -f "$CACHE_FILE" ]]; then
        echo ""
        print_warning "Found previous deployment configuration cache"
        echo ""
        echo "Options:"
        echo "  1) Resume from cache (use previous values)"
        echo "  2) Start fresh (clear cache and re-enter all values)"
        echo "  3) View cached values"
        read -p "Enter choice (1/2/3): " cache_choice
        echo ""

        case $cache_choice in
            1)
                print_info "Loading configuration from cache..."

                # Load cached values
                ENV_TYPE=$(load_cache "ENV_TYPE")
                MONGO_URI=$(load_cache "MONGO_URI")
                MONGO_DB=$(load_cache "MONGO_DB")
                API_KEY=$(load_cache "API_KEY")

                # Load port configurations
                declare -a cached_ports=()
                for i in 0 1 2 3; do
                    cached_ports[$i]=$(load_cache "PORT_$i")
                done

                # Display loaded values
                echo ""
                print_success "Cached configuration:"
                echo "  Environment: $ENV_TYPE"
                echo "  MongoDB URI: ${MONGO_URI:0:30}..."
                echo "  MongoDB Database: $MONGO_DB"
                echo "  API Key: ${API_KEY:0:20}..."
                if [[ -n "${cached_ports[0]}" ]]; then
                    echo "  Ports: ${cached_ports[0]}, ${cached_ports[1]}, ${cached_ports[2]}, ${cached_ports[3]}"
                fi
                echo ""

                read -p "Use these values? (Y/n): " confirm
                if [[ $confirm =~ ^[Nn]$ ]]; then
                    clear_cache
                    print_info "Starting fresh configuration..."
                    echo ""
                else
                    # Set template based on cached env type
                    if [[ "$ENV_TYPE" == "production" ]]; then
                        TEMPLATE="$SCRIPT_DIR/config/.env.production.template"
                    else
                        TEMPLATE="$SCRIPT_DIR/config/.env.test.template"
                    fi

                    # Skip to port configuration if ports not cached
                    if [[ -z "${cached_ports[0]}" ]]; then
                        print_info "Port configuration not found in cache, will prompt for ports..."
                    else
                        # Use cached ports
                        print_success "Using cached configuration"

                        # Apply configuration directly
                        apply_configuration_from_cache "${cached_ports[@]}"
                        return 0
                    fi
                fi
                ;;
            2)
                clear_cache
                print_info "Starting fresh configuration..."
                echo ""
                ;;
            3)
                print_info "Cached configuration:"
                cat "$CACHE_FILE" | while IFS= read -r line; do
                    echo "  $line"
                done
                echo ""
                read -p "Press Enter to continue with fresh setup..."
                clear_cache
                ;;
            *)
                print_error "Invalid choice, starting fresh..."
                clear_cache
                ;;
        esac
    fi

    # Ask for environment
    echo "Select environment:"
    echo "  1) Production"
    echo "  2) Test"
    read -p "Enter choice (1 or 2): " env_choice

    case $env_choice in
        1)
            ENV_TYPE="production"
            TEMPLATE="$SCRIPT_DIR/config/.env.production.template"
            ;;
        2)
            ENV_TYPE="test"
            TEMPLATE="$SCRIPT_DIR/config/.env.test.template"
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac

    save_cache "ENV_TYPE" "$ENV_TYPE"
    print_success "Selected: $ENV_TYPE environment"
    echo ""

    # Collect common values
    print_header "Common Configuration"

    read -p "MongoDB URI: " MONGO_URI_INPUT
    if [[ -z "$MONGO_URI_INPUT" ]]; then
        print_error "MongoDB URI is required"
        exit 1
    fi
    MONGO_URI=$MONGO_URI_INPUT
    save_cache "MONGO_URI" "$MONGO_URI"

    if [[ "$ENV_TYPE" == "production" ]]; then
        MONGO_DB_DEFAULT="production_database"
    else
        MONGO_DB_DEFAULT="test_database"
    fi

    read -p "MongoDB Database [$MONGO_DB_DEFAULT]: " MONGO_DB_INPUT
    MONGO_DB=${MONGO_DB_INPUT:-$MONGO_DB_DEFAULT}
    save_cache "MONGO_DB" "$MONGO_DB"

    read -p "Internal API Key: " API_KEY_INPUT
    if [[ -z "$API_KEY_INPUT" ]]; then
        print_error "Internal API Key is required"
        exit 1
    fi
    API_KEY=$API_KEY_INPUT
    save_cache "API_KEY" "$API_KEY"

    print_success "Configuration collected"
    echo ""

    # Port Configuration
    print_header "Port Configuration"

    print_info "Configure ports for each service (press Enter to use default)"
    echo ""

    # Service definitions: default_port:directory:description
    local service_defs=(
        "8082:$GITHUB_DIR/tiktok-user-info:User Info API"
        "8083:$GITHUB_DIR/tiktok-user-posts:User Posts API"
        "8084:$GITHUB_DIR/tiktok-search-users:Search Users API"
        "8085:$GITHUB_DIR/tiktok-post-detail:Post Detail API"
    )

    # Use indexed array for bash 3.2 compatibility (macOS default bash)
    declare -a service_ports=()
    declare -a service_names=()
    declare -a service_dirs=()
    declare -a service_descs=()

    local idx=0
    for service_def in "${service_defs[@]}"; do
        IFS=':' read -r default_port dir description <<< "$service_def"
        local service_name=$(basename "$dir")

        if [[ ! -d "$dir" ]]; then
            print_warning "$service_name: Directory not found, will skip"
            continue
        fi

        # Ask for port
        echo -e "${BLUE}$description${NC}"
        echo -e "  Directory: $dir"
        read -p "  Port [default: $default_port]: " new_port
        new_port=${new_port:-$default_port}

        # Validate port
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
            print_error "Invalid port: $new_port (must be 1024-65535)"
            print_info "Using default port: $default_port"
            new_port=$default_port
        fi

        service_ports[$idx]=$new_port
        service_names[$idx]=$service_name
        service_dirs[$idx]=$dir
        service_descs[$idx]=$description
        save_cache "PORT_$idx" "$new_port"
        print_success "$service_name: Port $new_port"
        echo ""
        ((idx++))
    done

    # Apply to each service
    print_header "Applying Configuration to Services"

    for ((i=0; i<${#service_names[@]}; i++)); do
        local service_name=${service_names[$i]}
        local dir=${service_dirs[$i]}
        local port=${service_ports[$i]}

        print_info "Configuring $service_name (Port: $port)..."

        # Check if .env already exists
        if [[ -f "$dir/.env" ]]; then
            print_warning "$service_name: .env file already exists"
            echo ""
            echo "Options:"
            echo "  1) Backup and recreate (recommended)"
            echo "  2) Skip (keep existing .env)"
            echo "  3) Overwrite without backup"
            read -p "Enter choice (1/2/3): " env_choice

            case $env_choice in
                1)
                    local backup_file="$dir/.env.backup.$(date +%Y%m%d_%H%M%S)"
                    mv "$dir/.env" "$backup_file"
                    print_success "Backed up to: $(basename $backup_file)"
                    ;;
                2)
                    print_info "Skipping $service_name (keeping existing .env)"
                    continue
                    ;;
                3)
                    print_warning "Overwriting existing .env"
                    ;;
                *)
                    print_error "Invalid choice, skipping $service_name"
                    continue
                    ;;
            esac
            echo ""
        fi

        # Use service's .env.example if it exists, otherwise use our template
        local source_template=""
        if [[ -f "$dir/.env.example" ]]; then
            source_template="$dir/.env.example"
            print_info "Using service's .env.example"
        else
            source_template="$TEMPLATE"
            print_info "Using deployment template"
        fi

        # Copy template
        cp "$source_template" "$dir/.env"

        # Detect environment variable naming convention from the copied file
        local uses_mongodb_uri=false
        if grep -q "MONGODB_URI" "$dir/.env"; then
            uses_mongodb_uri=true
        fi

        # Replace values (using cross-platform sed_inplace function)
        # Use | as delimiter to avoid conflicts with special chars in values
        sed_inplace "s|PORT=.*|PORT=$port|" "$dir/.env"

        if [[ "$uses_mongodb_uri" == true ]]; then
            # Service uses MONGODB_URI naming
            sed_inplace "s|MONGODB_URI=.*|MONGODB_URI=$MONGO_URI|" "$dir/.env"
            sed_inplace "s|MONGODB_DATABASE=.*|MONGODB_DATABASE=$MONGO_DB|" "$dir/.env"
        else
            # Service uses MONGO_URI naming
            sed_inplace "s|MONGO_URI=.*|MONGO_URI=$MONGO_URI|" "$dir/.env"
            sed_inplace "s|MONGO_DB=.*|MONGO_DB=$MONGO_DB|" "$dir/.env"
        fi

        sed_inplace "s|INTERNAL_API_KEY=.*|INTERNAL_API_KEY=$API_KEY|" "$dir/.env"
        sed_inplace "s|API_MASTER_KEY=.*|API_MASTER_KEY=$API_KEY|" "$dir/.env"

        print_success "$service_name configured (Port: $port)"
    done

    # Update services.conf using shared function
    update_services_conf "${service_ports[@]}"
}

# =============================================================================
# Configuration Loading
# =============================================================================

load_config() {
    print_header "Loading Service Configuration"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Count services (excluding comments and empty lines)
    TOTAL_SERVICES=$(grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$' | wc -l)

    if [[ $TOTAL_SERVICES -eq 0 ]]; then
        print_error "No services configured in $CONFIG_FILE"
        exit 1
    fi

    print_success "Found $TOTAL_SERVICES services to deploy"
}

# =============================================================================
# Environment Check
# =============================================================================

check_environment() {
    local service_dir=$1
    local service_name=$2

    if [[ ! -d "$service_dir" ]]; then
        print_error "$service_name: Directory not found ($service_dir)"
        return 1
    fi

    if [[ ! -f "$service_dir/.env" ]]; then
        print_warning "$service_name: .env file not found"
        print_info "Looking for .env.example..."

        if [[ -f "$service_dir/.env.example" ]]; then
            print_info "Copying .env.example to .env"
            cp "$service_dir/.env.example" "$service_dir/.env"
            print_warning "Please edit $service_dir/.env with correct values"
            return 2  # Warning but not fatal
        else
            print_error "$service_name: No .env or .env.example found"
            return 1
        fi
    fi

    return 0
}

# =============================================================================
# Docker Operations
# =============================================================================

build_service() {
    local service_dir=$1
    local service_name=$2

    print_info "$service_name: Building Docker image..."

    cd "$service_dir"

    if docker_compose build &> /tmp/build_${service_name}.log; then
        print_success "$service_name: Build completed"
        return 0
    else
        print_error "$service_name: Build failed"
        print_info "See log: /tmp/build_${service_name}.log"
        return 1
    fi
}

start_service() {
    local service_dir=$1
    local service_name=$2

    print_info "$service_name: Starting service..."

    cd "$service_dir"

    if docker_compose up -d &> /tmp/start_${service_name}.log; then
        print_success "$service_name: Started successfully"
        return 0
    else
        print_error "$service_name: Failed to start"
        print_info "See log: /tmp/start_${service_name}.log"
        return 1
    fi
}

# =============================================================================
# Health Check
# =============================================================================

wait_for_health() {
    local port=$1
    local health_endpoint=$2
    local service_name=$3
    local max_attempts=30
    local attempt=0

    print_info "$service_name: Waiting for service to be healthy..."

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -sf "http://localhost:${port}${health_endpoint}" > /dev/null 2>&1; then
            print_success "$service_name: Service is healthy!"
            return 0
        fi

        ((attempt++))
        echo -n "."
        sleep 2
    done

    echo ""
    print_error "$service_name: Service did not become healthy within timeout"
    return 1
}

# =============================================================================
# Service Deployment
# =============================================================================

deploy_service() {
    local service_name=$1
    local port=$2
    local directory=$3
    local health_endpoint=$4

    print_header "Deploying: $service_name"

    # Check environment
    if ! check_environment "$directory" "$service_name"; then
        print_error "$service_name: Environment check failed"
        ((FAIL_COUNT++))
        return 1
    fi

    # Build service
    if ! build_service "$directory" "$service_name"; then
        ((FAIL_COUNT++))
        return 1
    fi

    # Start service
    if ! start_service "$directory" "$service_name"; then
        ((FAIL_COUNT++))
        return 1
    fi

    # Wait for health
    if ! wait_for_health "$port" "$health_endpoint" "$service_name"; then
        print_warning "$service_name: Health check failed, but service may still be starting"
        print_info "Check with: docker logs -f <container_name>"
    fi

    ((SUCCESS_COUNT++))
    return 0
}

# =============================================================================
# Parallel Deployment
# =============================================================================

deploy_all_parallel() {
    print_header "Deploying All Services (Parallel Mode)"

    local pids=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Parse line: SERVICE_NAME PORT DIRECTORY HEALTH_ENDPOINT
        read -r service_name port directory health_endpoint <<< "$line"

        # Deploy in background
        (deploy_service "$service_name" "$port" "$directory" "$health_endpoint") &
        pids+=($!)

    done < "$CONFIG_FILE"

    # Wait for all deployments
    print_info "Waiting for all deployments to complete..."

    for pid in "${pids[@]}"; do
        wait $pid
    done
}

# =============================================================================
# Sequential Deployment
# =============================================================================

deploy_all_sequential() {
    print_header "Deploying All Services (Sequential Mode)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Parse line: SERVICE_NAME PORT DIRECTORY HEALTH_ENDPOINT
        read -r service_name port directory health_endpoint <<< "$line"

        # Skip if specific service requested
        if [[ -n "$SPECIFIC_SERVICE" && "$service_name" != "$SPECIFIC_SERVICE" ]]; then
            continue
        fi

        deploy_service "$service_name" "$port" "$directory" "$health_endpoint"

    done < "$CONFIG_FILE"
}

# =============================================================================
# Service Management
# =============================================================================

stop_all_services() {
    print_header "Stopping All Services"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        read -r service_name port directory health_endpoint <<< "$line"

        if [[ -d "$directory" ]]; then
            print_info "Stopping $service_name..."
            cd "$directory"
            docker_compose down > /dev/null 2>&1 || true
            print_success "$service_name stopped"
        fi

    done < "$CONFIG_FILE"
}

restart_service() {
    local target_service=$1

    print_header "Restarting Service: $target_service"

    local found=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        read -r service_name port directory health_endpoint <<< "$line"

        if [[ "$service_name" == "$target_service" ]]; then
            found=true

            # Stop service
            print_info "Stopping $service_name..."
            cd "$directory"
            docker_compose down > /dev/null 2>&1 || true

            # Deploy service
            deploy_service "$service_name" "$port" "$directory" "$health_endpoint"
            break
        fi

    done < "$CONFIG_FILE"

    if [[ "$found" == false ]]; then
        print_error "Service not found: $target_service"
        exit 1
    fi
}

# =============================================================================
# Summary Report
# =============================================================================

display_summary() {
    print_header "Deployment Summary"

    echo "Total services: $TOTAL_SERVICES"
    echo -e "${GREEN}Successfully deployed: $SUCCESS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""

    if [[ $FAIL_COUNT -gt 0 ]]; then
        print_warning "Some services failed to deploy"
        print_info "Check logs in /tmp/build_*.log and /tmp/start_*.log"
        return 1
    else
        print_success "All services deployed successfully!"
        return 0
    fi
}

# =============================================================================
# Next Steps
# =============================================================================

display_next_steps() {
    print_header "Next Steps"

    print_info "Services are running!"
    echo ""
    echo "  1. Check service health:"
    echo "     ./health-check.sh"
    echo ""
    echo "  2. View service logs:"
    echo "     cd ../SERVICE_DIR && docker compose logs -f"
    echo ""
    echo "  3. Test API endpoints:"
    echo "     curl http://localhost:8082/health  # User Info"
    echo "     curl http://localhost:8083/health  # User Posts"
    echo "     curl http://localhost:8084/health  # Search Users"
    echo "     curl http://localhost:8085/health  # Post Detail"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    print_header "TikTok Internal APIs - Service Deployment"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parallel)
                PARALLEL=true
                shift
                ;;
            --service)
                SPECIFIC_SERVICE="$2"
                shift 2
                ;;
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --setup-env)
                interactive_env_setup
                exit 0
                ;;
            --stop)
                stop_all_services
                exit 0
                ;;
            --restart)
                restart_service "$2"
                exit 0
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

    # Load configuration
    load_config

    # Deploy services
    if [[ "$PARALLEL" == true ]]; then
        deploy_all_parallel
    else
        deploy_all_sequential
    fi

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
