#!/bin/bash
set -e

CONFIG_FILE="/etc/gitlab-runner/config.toml"

if [ ! -f "$CONFIG_FILE" ]; then
  gitlab-runner register \
    --non-interactive \
    --url "$CI_SERVER_URL" \
    --registration-token "$REGISTRATION_TOKEN" \
    --executor "docker" \
    --docker-image "docker:24.0.5" \
    --docker-privileged \
    --description "Auto-registered runner" \
    --docker-volumes /certs/client \
    --docker-volumes /cache
fi

exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner 