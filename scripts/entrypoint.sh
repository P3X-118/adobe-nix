#!/bin/bash
# Docker container entrypoint script for LinuxPDF build
# Sets up environment and ensures proper permissions

set -e

# Function to log messages
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Function to ensure directory exists with proper permissions
ensure_dir() {
    local dir="$1"
    local owner="${2:-builder}"
    mkdir -p "$dir"
    chown "$owner:$owner" "$dir"
    log "INFO" "Ensured directory $dir exists with owner $owner"
}

# Main setup
main() {
    log "INFO" "Starting LinuxPDF Docker container setup"
    
    # Create necessary directories with proper permissions
    ensure_dir "/app/out" "builder"
    ensure_dir "/app/cache" "builder" 
    ensure_dir "/app/logs" "builder"
    ensure_dir "/app/build" "builder"
    
    # Ensure builder user has proper permissions
    chown -R builder:builder /app 2>/dev/null || true
    
    # Set up permissions for mount points
    if [ -d "/app/out" ] && [ "$(stat -c %U /app/out)" != "builder" ]; then
        log "INFO" "Setting ownership of mounted volumes to builder"
        chown -R builder:builder /app/out /app/cache /app/logs 2>/dev/null || true
    fi
    
    # Switch to builder user and execute command
    if [ "$(id -u)" = "0" ]; then
        log "INFO" "Switching to builder user and executing: $*"
        # Check if the command is our Docker build script which needs /tmp/app
        if [[ "$*" == *"/app/scripts/docker-build.sh"* ]]; then
            exec su builder -c "cd /tmp/app && $*"
        else
            exec su builder -c "cd /app && $*"
        fi
    else
        log "INFO" "Executing as current user: $*"
        if [[ "$*" == *"/app/scripts/docker-build.sh"* ]]; then
            cd /tmp/app
        else
            cd /app
        fi
        exec "$@"
    fi
}

# Execute main function with all arguments
main "$@"