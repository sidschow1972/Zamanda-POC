#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/home/azureuser/zammad"

mkdir -p "$APP_DIR"
cp docker-compose.yaml "$APP_DIR/docker-compose.yaml"

chown -R azureuser:azureuser "$APP_DIR"

sudo -u azureuser bash -lc "
  cd $APP_DIR
  docker compose pull
  docker compose up -d
"