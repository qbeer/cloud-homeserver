#!/usr/bin/env bash
#
# Safely bring up the cloud homeserver Docker stack on boot.
#
# The whole stack lives on /mnt/drive. If Docker starts before that drive is
# mounted, every container (restart: unless-stopped) is re-created against an
# empty directory and the apps come up with empty configs.
#
# This script:
#   1.  Verifies /mnt/drive is REALLY mounted (not just an empty directory).
#   2.  Retries the mount once, then FAILS LOUDLY so systemd can surface the
#       problem instead of silently writing empty configs.
#   3.  Starts the stack with `docker compose up`.
#   4.  Warns if any app config directory ended up empty.

set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
ENV_FILE="${REPO_DIR}/.env"

log()   { echo "[cloud-homeserver] $*"; }
fatal() { echo "[cloud-homeserver] FATAL: $*" >&2; }

# Load ROOT_DIR from .env (tolerate optional surrounding quotes)
if [[ -f "${ENV_FILE}" ]]; then
  ROOT_DIR="$(grep -E '^ROOT_DIR=' "${ENV_FILE}" | head -n1 | cut -d= -f2-)"
  ROOT_DIR="${ROOT_DIR%\"}"
  ROOT_DIR="${ROOT_DIR#\"}"
fi
ROOT_DIR="${ROOT_DIR:-}"
if [[ -z "${ROOT_DIR}" ]]; then
  fatal "ROOT_DIR not set in ${ENV_FILE}"
  exit 1
fi

is_mounted() { findmnt -rn -o SOURCE "$1" >/dev/null 2>&1; }

# --- 1. Verify the drive is really mounted
if ! is_mounted "${ROOT_DIR}"; then
  log "${ROOT_DIR} is not mounted, requesting mnt-drive.mount..."
  systemctl start mnt-drive.mount 2>/dev/null || true
  # Give a slow drive up to ~30s to appear before giving up.
  for _ in $(seq 1 10); do
    is_mounted "${ROOT_DIR}" && break
    sleep 3
  done
fi

if ! is_mounted "${ROOT_DIR}"; then
  fatal "${ROOT_DIR} is not mounted. Refusing to start the stack to avoid"
  fatal "empty/partial application configs."
  fatal ""
  fatal "Recovery (once the drive is present):"
  fatal "  sudo systemctl start mnt-drive.mount"
  fatal "  sudo systemctl restart cloud-homeserver.service"
  exit 1
fi
log "${ROOT_DIR} is mounted ($(findmnt -rn -o SOURCE "${ROOT_DIR}"))"

# --- 2. Check directories the services bind-mount exist
for d in Sonarr Radarr Transmission Jellyfin Prowlarr Jellyseerr Nginx Actual HomeAssistant Yacht Downloads; do
  [[ -d "${ROOT_DIR}/${d}" ]] || log "WARNING: expected directory missing: ${ROOT_DIR}/${d}"
done

# --- 3. Start the stack
cd "${REPO_DIR}"
log "running: docker compose up -d --remove-orphans"
docker compose up -d --remove-orphans
COMPOSE_RC=$?
if [[ ${COMPOSE_RC} -ne 0 ]]; then
  fatal "docker compose up failed (exit ${COMPOSE_RC})"
  exit 1
fi

# --- 4. Post-check: flag config dirs that came up empty
for d in Sonarr Radarr Transmission Jellyfin Prowlarr Jellyseerr Actual HomeAssistant Yacht; do
  cfg="${ROOT_DIR}/${d}/config"
  if [[ -d "${cfg}" ]] && [[ -z "$(ls -A "${cfg}" 2>/dev/null)" ]]; then
    log "WARNING: ${cfg} is empty - the app may need reconfiguration"
  fi
done

log "stack is up"
exit 0