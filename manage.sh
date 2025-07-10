#!/bin/bash

# GitLab Runner Docker-in-Docker Management Script
# Usage: ./manage.sh [command]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Function to check if docker-compose is available
check_docker_compose() {
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_error "docker-compose is not installed. Please install it first."
        exit 1
    fi
}

# Function to validate configuration
validate_config() {
    print_header "Validating Configuration"
    
    # Check if required files exist
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found"
        exit 1
    fi
    
    if [ ! -f "entrypoint.sh" ]; then
        print_error "entrypoint.sh not found"
        exit 1
    fi
    
    # Check if config directory exists
    if [ ! -d "config" ]; then
        print_warning "config directory not found, creating..."
        mkdir -p config
    fi
    
    # Check if certs directory exists
    if [ ! -d "certs" ]; then
        print_warning "certs directory not found, creating..."
        mkdir -p certs
    fi
    
    print_status "Configuration validation completed"
}

# Function to start services
start() {
    print_header "Starting GitLab Runner Services"
    check_docker
    check_docker_compose
    validate_config
    
    print_status "Starting services..."
    docker-compose up -d
    
    print_status "Waiting for services to be ready..."
    sleep 10
    
    # Check service status
    if docker-compose ps | grep -q "Up"; then
        print_status "Services started successfully"
        print_status "Runner logs: docker-compose logs -f gitlab-runner"
        print_status "DinD logs: docker-compose logs -f gitlab-dind"
    else
        print_error "Failed to start services"
        docker-compose logs
        exit 1
    fi
}

# Function to stop services
stop() {
    print_header "Stopping GitLab Runner Services"
    check_docker_compose
    
    print_status "Stopping services..."
    docker-compose down
    
    print_status "Services stopped"
}

# Function to restart services
restart() {
    print_header "Restarting GitLab Runner Services"
    stop
    start
}

# Function to show status
status() {
    print_header "GitLab Runner Status"
    check_docker_compose
    
    echo "Service Status:"
    docker-compose ps
    
    echo ""
    echo "Recent Logs:"
    docker-compose logs --tail=20
}

# Function to show logs
logs() {
    print_header "GitLab Runner Logs"
    check_docker_compose
    
    if [ -n "$2" ]; then
        docker-compose logs -f "$2"
    else
        docker-compose logs -f
    fi
}

# Function to update services
update() {
    print_header "Updating GitLab Runner Services"
    check_docker
    check_docker_compose
    
    print_status "Pulling latest images..."
    docker-compose pull
    
    print_status "Restarting services with new images..."
    docker-compose down
    docker-compose up -d
    
    print_status "Update completed"
}

# Function to backup configuration
backup() {
    print_header "Backing Up Configuration"
    
    BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    print_status "Creating backup in $BACKUP_DIR"
    
    # Backup config files
    cp -r config "$BACKUP_DIR/"
    cp docker-compose.yml "$BACKUP_DIR/"
    cp entrypoint.sh "$BACKUP_DIR/"
    cp README.md "$BACKUP_DIR/"
    
    # Backup Docker data if it exists
    if docker volume ls | grep -q "runnerz_dind-data"; then
        print_status "Backing up Docker data..."
        docker run --rm -v runnerz_dind-data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar -czf "/backup/dind-data.tar.gz" -C /data .
    fi
    
    print_status "Backup completed: $BACKUP_DIR"
}

# Function to restore configuration
restore() {
    if [ -z "$1" ]; then
        print_error "Please specify backup directory: ./manage.sh restore <backup-dir>"
        exit 1
    fi
    
    BACKUP_DIR="$1"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_error "Backup directory $BACKUP_DIR not found"
        exit 1
    fi
    
    print_header "Restoring Configuration from $BACKUP_DIR"
    
    # Stop services first
    stop
    
    # Restore config files
    if [ -d "$BACKUP_DIR/config" ]; then
        print_status "Restoring config files..."
        cp -r "$BACKUP_DIR/config" .
    fi
    
    if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
        print_status "Restoring docker-compose.yml..."
        cp "$BACKUP_DIR/docker-compose.yml" .
    fi
    
    if [ -f "$BACKUP_DIR/entrypoint.sh" ]; then
        print_status "Restoring entrypoint.sh..."
        cp "$BACKUP_DIR/entrypoint.sh" .
    fi
    
    # Restore Docker data if backup exists
    if [ -f "$BACKUP_DIR/dind-data.tar.gz" ]; then
        print_status "Restoring Docker data..."
        docker run --rm -v runnerz_dind-data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine sh -c "cd /data && tar -xzf /backup/dind-data.tar.gz"
    fi
    
    print_status "Restore completed"
}

# Function to clean up
cleanup() {
    print_header "Cleaning Up GitLab Runner"
    check_docker_compose
    
    print_warning "This will remove all data and containers. Are you sure? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Stopping and removing services..."
        docker-compose down -v
        
        print_status "Removing images..."
        docker rmi gitlab/gitlab-runner:latest docker:24.0.5-dind || true
        
        print_status "Removing backup directories..."
        rm -rf backup-*
        
        print_status "Cleanup completed"
    else
        print_status "Cleanup cancelled"
    fi
}

# Function to show help
help() {
    echo "GitLab Runner Docker-in-Docker Management Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start     - Start GitLab Runner services"
    echo "  stop      - Stop GitLab Runner services"
    echo "  restart   - Restart GitLab Runner services"
    echo "  status    - Show service status"
    echo "  logs      - Show logs (optionally specify service: gitlab-runner or gitlab-dind)"
    echo "  update    - Update to latest images"
    echo "  backup    - Backup configuration and data"
    echo "  restore   - Restore from backup (specify backup directory)"
    echo "  cleanup   - Remove all data and containers"
    echo "  validate  - Validate configuration"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 logs gitlab-runner"
    echo "  $0 backup"
    echo "  $0 restore backup-20231201-143022"
}

# Main script logic
case "${1:-help}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    logs)
        logs "$@"
        ;;
    update)
        update
        ;;
    backup)
        backup
        ;;
    restore)
        restore "$2"
        ;;
    cleanup)
        cleanup
        ;;
    validate)
        validate_config
        ;;
    help|--help|-h)
        help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        help
        exit 1
        ;;
esac 