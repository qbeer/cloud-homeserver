#!/usr/bin/env bash
#
# Deploy the Home Assistant YAML from this repo into the running container.
#
# Usage:
#   scripts/deploy_homeassistant.sh            # copy, validate, restart
#   scripts/deploy_homeassistant.sh --no-restart
#   scripts/deploy_homeassistant.sh --yes      # skip the confirmation prompt
#
# Environment overrides:
#   HA_CONTAINER=homeassistant
#   HA_CONFIG_DIR=/config
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/data/HomeAssistant/config"
CONTAINER="${HA_CONTAINER:-homeassistant}"
CONFIG_DIR="${HA_CONFIG_DIR:-/config}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_DIR:-/tmp/ha-backup-$STAMP}"
ASSUME_YES=0
DO_RESTART=1

for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
    --no-restart) DO_RESTART=0 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  echo "Container '$CONTAINER' is not running." >&2
  exit 1
fi

echo "==> Backing up current YAML to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
docker exec "$CONTAINER" sh -c \
  "cd '$CONFIG_DIR' || exit 1
   set -- configuration.yaml automations.yaml scripts.yaml scenes.yaml \
          templates.yaml utility_meters.yaml dashboards
   files=''
   for f in \"\$@\"; do [ -e \"\$f\" ] && files=\"\$files \$f\"; done
   [ -n \"\$files\" ] || { echo 'no config files found to back up' >&2; exit 1; }
   tar czf /tmp/ha-yaml-backup.tgz \$files"
docker cp "$CONTAINER:/tmp/ha-yaml-backup.tgz" "$BACKUP_DIR/ha-yaml-backup.tgz" >/dev/null
echo "    backup: $BACKUP_DIR/ha-yaml-backup.tgz"

copy_file() {
  local rel="$1"
  local src="$SRC/$rel"
  local dst="$CONFIG_DIR/$rel"
  if [[ ! -f "$src" ]]; then
    echo "    skip missing: $rel"
    return 0
  fi
  docker exec "$CONTAINER" mkdir -p "$(dirname "$dst")"
  docker cp "$src" "$CONTAINER:$dst.tmp" >/dev/null
  docker exec "$CONTAINER" mv "$dst.tmp" "$dst"
  echo "    copied: $rel"
}

echo "==> Copying YAML into $CONTAINER:$CONFIG_DIR"
copy_file configuration.yaml
copy_file automations.yaml
copy_file scripts.yaml
copy_file templates.yaml
copy_file utility_meters.yaml
docker exec "$CONTAINER" mkdir -p "$CONFIG_DIR/dashboards"
docker cp "$SRC/dashboards/." "$CONTAINER:$CONFIG_DIR/dashboards/" >/dev/null
echo "    copied: dashboards/"

echo "==> Validating configuration"
if ! docker exec "$CONTAINER" hass --script check_config -c "$CONFIG_DIR"; then
  echo
  echo "Configuration check FAILED. Restoring the previous YAML." >&2
  docker cp "$BACKUP_DIR/ha-yaml-backup.tgz" "$CONTAINER:/tmp/ha-yaml-backup.tgz" >/dev/null
  docker exec "$CONTAINER" sh -c "cd '$CONFIG_DIR' && tar xzf /tmp/ha-yaml-backup.tgz"
  echo "Restored from $BACKUP_DIR/ha-yaml-backup.tgz" >&2
  exit 1
fi

if [[ "$DO_RESTART" -eq 0 ]]; then
  echo "==> Validation OK. Restart skipped (--no-restart)."
  exit 0
fi

if [[ "$ASSUME_YES" -eq 0 ]]; then
  read -r -p "Restart Home Assistant now to apply? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Restart skipped. Run 'docker restart $CONTAINER' when ready."; exit 0 ;;
  esac
fi

echo "==> Restarting $CONTAINER"
docker restart "$CONTAINER" >/dev/null
echo "==> Done."
echo
echo "Next steps:"
echo "  1. Open Home Assistant -> Profile -> Dashboard and select 'Home' as default."
echo "  2. Settings -> Dashboards -> Energy -> add both plug energy sensors."
echo "  3. Review the heating temperatures in scripts.yaml before enabling the schedule."
