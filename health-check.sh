#!/bin/bash

# =============================================================================
# Health Check Script
# =============================================================================
# This script checks the health of all TikTok Internal API services.
# Reads configuration from config/services.conf
#
# Usage:
#   ./health-check.sh [--json] [--watch] [--service SERVICE_NAME]
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
JSON_OUTPUT=false
WATCH_MODE=false
SPECIFIC_SERVICE=""
WATCH_INTERVAL=5

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    if [[ "$JSON_OUTPUT" == false ]]; then
        echo -e "\n${BLUE}===================================================================${NC}"
        echo -e "${BLUE}$1${NC}"
        echo -e "${BLUE}===================================================================${NC}\n"
    fi
}

print_success() {
    if [[ "$JSON_OUTPUT" == false ]]; then
        echo -e "${GREEN}✅ $1${NC}"
    fi
}

print_error() {
    if [[ "$JSON_OUTPUT" == false ]]; then
        echo -e "${RED}❌ $1${NC}"
    fi
}

print_warning() {
    if [[ "$JSON_OUTPUT" == false ]]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    fi
}

print_info() {
    if [[ "$JSON_OUTPUT" == false ]]; then
        echo -e "${BLUE}ℹ️  $1${NC}"
    fi
}

# =============================================================================
# Help Function
# =============================================================================

show_help() {
    cat << EOF
${BLUE}TikTok Internal APIs - Health Check${NC}

${YELLOW}DESCRIPTION:${NC}
  Monitors the health of all 4 TikTok Internal API services.
  Checks HTTP endpoints, port status, Docker containers, and uptime.

${YELLOW}USAGE:${NC}
  ./health-check.sh [OPTIONS]

${YELLOW}OPTIONS:${NC}
  --json                    Output in JSON format
  --watch                   Continuous monitoring mode
  --service SERVICE_NAME    Check specific service only
  --interval SECONDS        Watch mode refresh interval (default: 5)
  --help, -h               Show this help message

${YELLOW}EXAMPLES:${NC}
  # Check all services (human-readable)
  ./health-check.sh

  # JSON output (for automation)
  ./health-check.sh --json

  # Watch mode (continuous monitoring)
  ./health-check.sh --watch

  # Custom refresh interval (10 seconds)
  ./health-check.sh --watch --interval 10

  # Check specific service
  ./health-check.sh --service user-posts

  # JSON output with jq filtering
  ./health-check.sh --json | jq '.[] | select(.status=="unhealthy")'

${YELLOW}SERVICE STATUS:${NC}
  • healthy  - Service is running and responding
  • starting - Container running but HTTP not ready
  • unhealthy - Service is down or not responding

${YELLOW}OUTPUT FORMAT:${NC}
  Status: Overall service status
  Container: Docker container state
  Port: Network port listening state
  HTTP: HTTP endpoint health
  Uptime: Service uptime duration

${YELLOW}EXIT CODES:${NC}
  0 - All services healthy
  1 - One or more services unhealthy

EOF
    exit 0
}

# =============================================================================
# Health Check Functions
# =============================================================================

check_port_listening() {
    local port=$1

    if command -v netstat &> /dev/null; then
        netstat -tuln | grep -q ":${port} " && return 0
    elif command -v ss &> /dev/null; then
        ss -tuln | grep -q ":${port} " && return 0
    else
        # Fallback: try to connect
        timeout 1 bash -c "cat < /dev/null > /dev/tcp/localhost/${port}" 2>/dev/null && return 0
    fi

    return 1
}

check_http_endpoint() {
    local port=$1
    local endpoint=$2
    local timeout=5

    local url="http://localhost:${port}${endpoint}"

    if curl -sf --max-time "$timeout" "$url" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_docker_container() {
    local service_dir=$1

    if [[ ! -d "$service_dir" ]]; then
        return 1
    fi

    cd "$service_dir"

    # Get container name from docker-compose
    local container_name=$(docker-compose ps -q 2>/dev/null | head -n1)

    if [[ -z "$container_name" ]]; then
        return 1
    fi

    # Check if container is running
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)

    if [[ "$status" == "running" ]]; then
        return 0
    else
        return 1
    fi
}

get_container_uptime() {
    local service_dir=$1

    cd "$service_dir"

    local container_name=$(docker-compose ps -q 2>/dev/null | head -n1)

    if [[ -z "$container_name" ]]; then
        echo "N/A"
        return
    fi

    local started=$(docker inspect -f '{{.State.StartedAt}}' "$container_name" 2>/dev/null)

    if [[ -n "$started" ]]; then
        # Calculate uptime
        local started_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
        local now_epoch=$(date +%s)
        local uptime_seconds=$((now_epoch - started_epoch))

        if [[ $uptime_seconds -gt 0 ]]; then
            local days=$((uptime_seconds / 86400))
            local hours=$(( (uptime_seconds % 86400) / 3600 ))
            local minutes=$(( (uptime_seconds % 3600) / 60 ))

            if [[ $days -gt 0 ]]; then
                echo "${days}d ${hours}h ${minutes}m"
            elif [[ $hours -gt 0 ]]; then
                echo "${hours}h ${minutes}m"
            else
                echo "${minutes}m"
            fi
        else
            echo "Just started"
        fi
    else
        echo "N/A"
    fi
}

# =============================================================================
# Service Health Check
# =============================================================================

check_service_health() {
    local service_name=$1
    local port=$2
    local directory=$3
    local health_endpoint=$4

    local status="unknown"
    local port_status="closed"
    local http_status="unreachable"
    local container_status="stopped"
    local uptime="N/A"

    # Check port
    if check_port_listening "$port"; then
        port_status="listening"
    fi

    # Check HTTP endpoint
    if check_http_endpoint "$port" "$health_endpoint"; then
        http_status="healthy"
    fi

    # Check Docker container
    if check_docker_container "$directory"; then
        container_status="running"
        uptime=$(get_container_uptime "$directory")
    fi

    # Determine overall status
    if [[ "$http_status" == "healthy" && "$container_status" == "running" ]]; then
        status="healthy"
    elif [[ "$container_status" == "running" ]]; then
        status="starting"
    else
        status="unhealthy"
    fi

    # Return results as JSON if requested
    if [[ "$JSON_OUTPUT" == true ]]; then
        cat << EOF
{
  "service": "$service_name",
  "port": $port,
  "status": "$status",
  "port_status": "$port_status",
  "http_status": "$http_status",
  "container_status": "$container_status",
  "uptime": "$uptime"
}
EOF
    else
        # Human-readable output
        local status_symbol=""
        local status_color=""

        case $status in
            healthy)
                status_symbol="✅"
                status_color="${GREEN}"
                ;;
            starting)
                status_symbol="🔄"
                status_color="${YELLOW}"
                ;;
            unhealthy)
                status_symbol="❌"
                status_color="${RED}"
                ;;
            *)
                status_symbol="❓"
                status_color="${NC}"
                ;;
        esac

        echo -e "${status_color}${status_symbol} ${service_name}${NC} (port: ${port})"
        echo "   Status: $status"
        echo "   Container: $container_status"
        echo "   Port: $port_status"
        echo "   HTTP: $http_status"
        echo "   Uptime: $uptime"
        echo ""
    fi

    # Return exit code based on status
    [[ "$status" == "healthy" ]] && return 0 || return 1
}

# =============================================================================
# Check All Services
# =============================================================================

check_all_services() {
    local healthy=0
    local unhealthy=0
    local total=0

    if [[ "$JSON_OUTPUT" == true ]]; then
        echo "["
    else
        print_header "Checking Service Health"
    fi

    local first=true

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue

        # Parse line
        read -r service_name port directory health_endpoint <<< "$line"

        # Skip if specific service requested
        if [[ -n "$SPECIFIC_SERVICE" && "$service_name" != "$SPECIFIC_SERVICE" ]]; then
            continue
        fi

        ((total++))

        if [[ "$JSON_OUTPUT" == true ]]; then
            if [[ "$first" == false ]]; then
                echo ","
            fi
            first=false
        fi

        if check_service_health "$service_name" "$port" "$directory" "$health_endpoint"; then
            ((healthy++))
        else
            ((unhealthy++))
        fi

    done < "$CONFIG_FILE"

    if [[ "$JSON_OUTPUT" == true ]]; then
        echo ""
        echo "]"
    else
        print_header "Summary"
        echo "Total services: $total"
        echo -e "${GREEN}Healthy: $healthy${NC}"
        echo -e "${RED}Unhealthy: $unhealthy${NC}"
    fi

    # Return exit code
    [[ $unhealthy -eq 0 ]] && return 0 || return 1
}

# =============================================================================
# Watch Mode
# =============================================================================

watch_health() {
    print_info "Starting health check monitor (press Ctrl+C to exit)..."
    print_info "Refresh interval: ${WATCH_INTERVAL}s"
    echo ""

    while true; do
        clear
        echo "Health Check Monitor - $(date '+%Y-%m-%d %H:%M:%S')"
        check_all_services
        sleep $WATCH_INTERVAL
    done
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                JSON_OUTPUT=true
                shift
                ;;
            --watch)
                WATCH_MODE=true
                shift
                ;;
            --service)
                SPECIFIC_SERVICE="$2"
                shift 2
                ;;
            --interval)
                WATCH_INTERVAL="$2"
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

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Run health check
    if [[ "$WATCH_MODE" == true ]]; then
        watch_health
    else
        if [[ "$JSON_OUTPUT" == false ]]; then
            print_header "TikTok Internal APIs - Health Check"
        fi

        if check_all_services; then
            exit 0
        else
            exit 1
        fi
    fi
}

# Run main function
main "$@"
