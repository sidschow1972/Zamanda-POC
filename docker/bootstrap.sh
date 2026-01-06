#!/usr/bin/env bash
set -euo pipefail

ADMIN_USER="azureuser"
APP_DIR="/home/${ADMIN_USER}/zammad"

echo "[bootstrap] Prepare ${APP_DIR}"
mkdir -p "${APP_DIR}"

echo "[bootstrap] Copy compose files"
cp -f docker-compose.yml "${APP_DIR}/docker-compose.yml"
if [ -f ".env" ]; then
  cp -f .env "${APP_DIR}/.env"
fi

chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_DIR}"

echo "[bootstrap] Bring stack up"
sudo -u "${ADMIN_USER}" bash -lc "
  cd '${APP_DIR}'
  docker compose -f docker-compose.yml up -d
  docker compose -f docker-compose.yml ps
"

echo "[bootstrap] Done"