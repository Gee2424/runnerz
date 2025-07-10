#!/bin/bash
set -e

CONFIG_FILE="/etc/gitlab-runner/config.toml"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if runner is already registered
is_runner_registered() {
    if [ -f "$CONFIG_FILE" ] && grep -q "token" "$CONFIG_FILE"; then
        return 0
    else
        return 1
    fi
}

# Function to register the runner
register_runner() {
    log "Registering GitLab Runner..."
    
    # Check if required environment variables are set
    if [ -z "$CI_SERVER_URL" ]; then
        log "ERROR: CI_SERVER_URL environment variable is not set"
        exit 1
    fi
    
    if [ -z "$REGISTRATION_TOKEN" ]; then
        log "ERROR: REGISTRATION_TOKEN environment variable is not set"
        exit 1
    fi
    
    # Register the runner with enhanced configuration
    gitlab-runner register \
        --non-interactive \
        --url "$CI_SERVER_URL" \
        --registration-token "$REGISTRATION_TOKEN" \
        --executor "docker" \
        --docker-image "docker:24.0.5" \
        --docker-privileged \
        --description "Auto-registered Docker-in-Docker runner" \
        --docker-volumes "/certs/client" \
        --docker-volumes "/cache" \
        --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
        --docker-network-mode "gitlab-runner-net" \
        --docker-memory "4g" \
        --docker-memory-swap "4g" \
        --docker-cpus "2" \
        --docker-pull-policy "if-not-present" \
        --docker-wait-for-services-timeout "300"
    
    if [ $? -eq 0 ]; then
        log "Runner registered successfully"
    else
        log "ERROR: Failed to register runner"
        exit 1
    fi
}

# Main execution
log "Starting GitLab Runner setup..."

# Create config directory if it doesn't exist
mkdir -p "$(dirname "$CONFIG_FILE")"

# Register runner if not already registered
if ! is_runner_registered; then
    register_runner
else
    log "Runner already registered, skipping registration"
fi

# Verify runner configuration
log "Verifying runner configuration..."
if gitlab-runner verify; then
    log "Runner verification successful"
else
    log "WARNING: Runner verification failed, but continuing..."
fi

# Start the runner
log "Starting GitLab Runner..."
exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner 