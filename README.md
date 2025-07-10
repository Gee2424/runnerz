# GitLab Runner with Docker-in-Docker (DinD)

This repository contains a Docker Compose setup for running GitLab Runner with Docker-in-Docker (DinD) support, following GitLab's best practices for containerized CI/CD pipelines.

## Features

- **Docker-in-Docker (DinD)**: Full Docker support for building and running containers
- **TLS Configuration**: Configurable TLS support (currently disabled for development)
- **Overlay2 Storage**: Optimized storage driver for better performance
- **Health Checks**: Built-in health monitoring for both services
- **Resource Limits**: Configurable CPU and memory limits
- **Auto-registration**: Automatic runner registration on first startup
- **Persistent Storage**: Docker data persistence across restarts

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   GitLab Runner │    │   Docker-in-Docker │
│                 │    │                 │
│ - Executes jobs │◄──►│ - Builds images │
│ - Manages cache │    │ - Runs containers│
│ - Reports status│    │ - Overlay2 FS   │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────────────────┘
              Shared Network
```

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 1.29+
- GitLab instance (self-hosted or GitLab.com)
- Registration token from your GitLab project/group/instance

## Quick Start

1. **Clone and configure**:
```bash
   git clone <repository-url>
   cd runnerz
   ```

2. **Update configuration**:
   Edit `docker-compose.yml` and update:
   - `CI_SERVER_URL`: Your GitLab instance URL
   - `REGISTRATION_TOKEN`: Your runner registration token

3. **Start the services**:
```bash
docker-compose up -d
```

4. **Check status**:
```bash
   docker-compose ps
   docker-compose logs -f gitlab-runner
   ```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CI_SERVER_URL` | GitLab instance URL | `https://clab.mwihoko.com` |
| `REGISTRATION_TOKEN` | Runner registration token | Required |
| `DOCKER_TLS_CERTDIR` | TLS certificates directory | `""` (disabled) |
| `DOCKER_DRIVER` | Docker storage driver | `overlay2` |

### Resource Limits

The runner is configured with the following resource limits:
- **Memory**: 4GB
- **Memory Swap**: 4GB  
- **Memory Reservation**: 1GB
- **CPU**: 2 cores

Adjust these in `config/config.toml` based on your needs.

## Usage Examples

### Basic Docker Build

```yaml
# .gitlab-ci.yml
default:
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - docker info

variables:
  DOCKER_HOST: tcp://docker:2375
  DOCKER_TLS_CERTDIR: ""

build:
  stage: build
  script:
    - docker build -t my-app .
    - docker run my-app /script/to/run/tests
```

### With Container Registry

```yaml
# .gitlab-ci.yml
default:
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin

variables:
  DOCKER_HOST: tcp://docker:2375
  DOCKER_TLS_CERTDIR: ""

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

### With Docker Layer Caching

```yaml
# .gitlab-ci.yml
default:
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin

variables:
  DOCKER_HOST: tcp://docker:2375
  DOCKER_TLS_CERTDIR: ""

build:
  stage: build
  script:
    - docker pull $CI_REGISTRY_IMAGE:latest || true
    - docker build --cache-from $CI_REGISTRY_IMAGE:latest -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE:latest
```

## TLS Configuration

### Enable TLS (Production)

To enable TLS for secure communication:

1. **Update docker-compose.yml**:
   ```yaml
   gitlab-dind:
     environment:
       - DOCKER_TLS_CERTDIR="/certs"
     command: [
       "--storage-driver=overlay2",
       "--tls=true",
       "--host=tcp://0.0.0.0:2376"
     ]
   
   gitlab-runner:
     environment:
       - DOCKER_HOST=tcp://gitlab-dind:2376
       - DOCKER_TLS_CERTDIR="/certs"
   ```

2. **Update config.toml**:
   ```toml
   [runners.docker]
     tls_verify = true
   ```

3. **Update .gitlab-ci.yml**:
   ```yaml
   variables:
     DOCKER_HOST: tcp://docker:2376
     DOCKER_TLS_CERTDIR: "/certs"
   ```

### Disable TLS (Development)

Current configuration has TLS disabled for development:
- `DOCKER_TLS_CERTDIR=""`
- `--tls=false`
- `DOCKER_HOST=tcp://gitlab-dind:2375`

## Security Considerations

### Privileged Mode
The runner runs in privileged mode to support Docker-in-Docker. This:
- Disables container security mechanisms
- Exposes host to privilege escalation risks
- Should only be used in trusted environments

### Network Security
- Services communicate over a dedicated bridge network
- External access is limited to necessary ports only
- Consider using TLS in production environments

### Resource Limits
- Memory and CPU limits prevent resource exhaustion
- Adjust limits based on your workload requirements
- Monitor resource usage regularly

## Troubleshooting

### Common Issues

1. **Runner not connecting to GitLab**:
   ```bash
   docker-compose logs gitlab-runner
   # Check CI_SERVER_URL and REGISTRATION_TOKEN
   ```

2. **Docker daemon not accessible**:
   ```bash
   docker-compose exec gitlab-runner docker info
   # Check DOCKER_HOST and network connectivity
   ```

3. **Build failures**:
   ```bash
   docker-compose logs gitlab-dind
   # Check Docker daemon logs
   ```

### Health Checks

Monitor service health:
```bash
# Check service status
docker-compose ps

# View health check logs
docker-compose exec gitlab-dind docker info
docker-compose exec gitlab-runner gitlab-runner verify
```

### Logs

View detailed logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f gitlab-runner
docker-compose logs -f gitlab-dind
```

## Maintenance

### Updating Runner Version

1. **Stop services**:
   ```bash
   docker-compose down
   ```

2. **Pull new image**:
   ```bash
   docker-compose pull
   ```

3. **Restart services**:
   ```bash
   docker-compose up -d
   ```

### Backup Configuration

Backup your configuration:
```bash
# Backup config directory
tar -czf gitlab-runner-config-$(date +%Y%m%d).tar.gz config/

# Backup Docker data
docker run --rm -v runnerz_dind-data:/data -v $(pwd):/backup alpine tar -czf /backup/dind-data-$(date +%Y%m%d).tar.gz -C /data .
```

### Cleanup

Remove all data:
```bash
# Stop and remove containers
docker-compose down

# Remove volumes
docker-compose down -v

# Remove images
docker rmi gitlab/gitlab-runner:latest docker:24.0.5-dind
```

## Performance Optimization

### Docker Layer Caching
Enable layer caching for faster builds:
```yaml
variables:
  DOCKER_BUILDKIT: 1
  BUILDKIT_INLINE_CACHE: 1
```

### Registry Mirror
Configure a registry mirror in `docker-compose.yml`:
```yaml
gitlab-dind:
  command: [
    "--storage-driver=overlay2",
    "--tls=false",
    "--registry-mirror=https://registry-mirror.example.com"
  ]
```

### Parallel Jobs
Adjust concurrent jobs in `config/config.toml`:
```toml
concurrent = 4  # Number of parallel jobs
```

## References

- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [Docker-in-Docker Guide](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html)
- [Docker Layer Caching](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#make-docker-in-docker-builds-faster-with-docker-layer-caching)
- [Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
