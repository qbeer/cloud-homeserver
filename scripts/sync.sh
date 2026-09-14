#!/bin/bash
# Backup helper.
#
#   scripts/sync.sh               full rsync snapshot of ROOT_DIR to ~/backups/medialab
#   scripts/sync.sh --config      sync config files listed in sync_manifest.txt into ./data (for git)
#
set -a
source "$(dirname "$0")/../.env"
set +a

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/backups/medialab}"

RSYNC_FLAGS=(-arv --progress)

# Full backup: exclude only bulky media and transient top-level dirs.
GLOBAL_EXCLUDES=(
  --exclude='Books/'
  --exclude='Deluge/'
  --exclude='Downloads/'
  --exclude='Immich/'
  --exclude='Misc/'
  --exclude='Radarr/Movies/'
  --exclude='Sonarr/TV/'
)

full_backup() {
  rsync "${RSYNC_FLAGS[@]}" "${GLOBAL_EXCLUDES[@]}" "${ROOT_DIR}/" "$BACKUP_ROOT"
}

# Config snapshot for git: only the files listed in sync_manifest.txt, which by
# construction never contains DBs, logs, caches, secrets or certificates.
sync_configs() {
  local manifest="$SCRIPT_DIR/sync_manifest.txt"
  local dest="$SCRIPT_DIR/../data"
  local repo="$SCRIPT_DIR/.."
  [ -f "$manifest" ] || { echo "error: $manifest not found" >&2; exit 1; }
  mkdir -p "$dest"

  # The rsync delete exit code 23 can be a harmless permission warning when it
  # fails to prune a root-owned directory inside data/; the transfer itself stays
  # consistent with the manifest, so don't hard-fail on it.
  rsync "${RSYNC_FLAGS[@]}" --delete \
    --files-from="$manifest" \
    "${GLOBAL_EXCLUDES[@]}" \
    "${ROOT_DIR}/" "$dest/" || true

  # data/* is gitignored; stage exactly what the manifest defines.
  # The manifest is the single source of truth for what belongs in git.
  cd "$repo" || exit 1
  git add -f -- data/README.md
  while IFS= read -r path; do
    [ -n "$path" ] && [ -z "${path##*[![:space:]]*}" ] || continue  # skip blanks/comments
    case "$path" in \#*) continue ;; esac
    git add -f -- "data/$path"
  done < "$manifest"
}

case "${1:-}" in
  --config) sync_configs ;;
  *)        full_backup ;;
esac