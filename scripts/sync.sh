#!/bin/bash
set -a
source "$(dirname "$0")/../.env"
set +a

rsync -arv --progress --exclude='Books/' --exclude='Deluge/' --exclude='Downloads/' --exclude='Immich/' --exclude='Misc/' --exclude='Radarr/Movies/' --exclude='Sonarr/TV/' "${ROOT_DIR}/" /home/olaralex/backups/medialab