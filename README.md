# GitLab Runner Docker-in-Docker (DinD) Setup

This project provides a ready-to-use setup for running GitLab CI/CD jobs that build, test, and push Docker images using Docker-in-Docker (DinD) with best practices for security, performance, and compatibility.

## Features
- **Docker-in-Docker with TLS enabled** for secure Docker builds in CI/CD jobs.
- **Version-pinned Docker images** for both the runner and DinD service.
- **Privileged mode** enabled for the runner, as required by DinD.
- **Overlay2 storage driver** for optimal Docker layer caching.
- **Volumes for Docker cache and TLS certificates**.
- **Compatible with GitLab.com, GitLab Self-Managed, and GitLab Dedicated.**

## Prerequisites
- Docker and Docker Compose installed on your host.
- A GitLab project and a valid runner registration token.
- Kernel support for overlay2 (Linux kernel >= 4.2 recommended).

## Usage

### 1. Clone this repository
```bash
git clone <your-repo-url>
cd <your-repo>
```

### 2. Create the required directories
```bash
mkdir -p config certs
```

### 3. Configure the runner
Edit `config/config.toml` and set your GitLab runner token and URL.

### 4. Start the services
```bash
docker-compose up -d
```
This will start both the DinD service and the GitLab Runner, with the correct volumes and network.

### 5. Register the runner (if not already registered)
You can register the runner interactively:
```bash
docker-compose exec gitlab-runner gitlab-runner register
```
- Use `docker` as the executor.
- Use `docker:24.0.5` as the default image.
- Set privileged mode to `true` when prompted.
- Set the Docker volumes to `/certs/client` and `/cache`.

### 6. Example `.gitlab-ci.yml`
```yaml
default:
  image: docker:24.0.5
  services:
    - docker:24.0.5-dind
  before_script:
    - docker info

variables:
  DOCKER_TLS_CERTDIR: "/certs"

build:
  stage: build
  script:
    - docker build -t my-docker-image .
    - docker run my-docker-image /script/to/run/tests
```

## Best Practices
- **Always pin Docker image versions** (e.g., `docker:24.0.5`) to avoid breaking changes.
- **Privileged mode is required** for DinD. This is a security risk; only use trusted code and restrict runner access.
- **Use the overlay2 storage driver** for best performance.
- **Do not use both DinD and Docker socket binding at the same time.**
- **For advanced caching or registry mirror setup,** see the official GitLab documentation.

## Alternatives
If you do not want to use privileged mode, consider using [BuildKit](https://docs.gitlab.com/ee/ci/docker/using_docker_buildkit.html) or [Buildah](https://docs.gitlab.com/ee/ci/docker/using_buildah.html) as alternatives for building images.

## References
- [GitLab CI/CD: Use Docker to build Docker images](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html)
- [GitLab Runner Docker Executor](https://docs.gitlab.com/runner/executors/docker.html)
- [Docker-in-Docker Best Practices](https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#use-docker-in-docker-workflow-with-docker-executor)
