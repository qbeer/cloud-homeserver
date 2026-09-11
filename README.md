# Cloud Homeserver

A Docker Compose based home server setup for media management and home automation.

## Project Structure

- `docker-compose.yml` / `docker-compose.immich.yml`: Service definitions.
- `scripts/`:
  - `start_stack.sh` -- boot-verified entry point (mount check + compose up + post-check).
  - `create_dirs.py` -- creates all directories referenced by the compose files.
  - `sync.sh` -- rsync backup helper.
- `systemd/`:
  - `cloud-homeserver.service` -- systemd unit that calls `start_stack.sh`.
  - `docker.service.d/wait-for-mount.conf` -- drop-in that forces Docker to wait for the drive mount before starting the daemon.
- `.env` (created from `.env.example`)

## Getting Started

### 1. Configuration

```bash
cp .env.example .env
nano .env   # set PUID, PGID, TZ, ROOT_DIR (where your drive is mounted)
```

### 2. Setup

```bash
python3 scripts/create_dirs.py
docker compose up -d
```

### 3. Automatic Startup (Systemd)

Docker's `restart: unless-stopped` policy causes the daemon to restart every
container the instant it starts. If the drive is not yet mounted, all configs
are silently written to empty directories. Two systemd units fix this:

1. **`wait-for-mount.conf`** (docker drop-in) -- blocks the Docker daemon until
   the drive is mounted.
2. **`cloud-homeserver.service`** -- calls `start_stack.sh`, which double-checks
   the mount is real before running `docker compose up`.

Install both:

```bash
# Drop-in (blocks dockerd until the drive is mounted)
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo cp systemd/docker.service.d/wait-for-mount.conf \
 /etc/systemd/system/docker.service.d/wait-for-mount.conf

# Homeserver service
sudo cp systemd/cloud-homeserver.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable cloud-homeserver.service
sudo systemctl start cloud-homeserver.service
```

**Fstab hardening (recommended):** give a slow drive enough time to spin up
without boot hanging. In `/etc/fstab` update the `/mnt/drive` line:

```
# Before:
/dev/disk/by-uuid/... /mnt/drive auto nosuid,nodev,nofail,x-gvfs-show 0 0

# After:
/dev/disk/by-uuid/... /mnt/drive auto nosuid,nodev,nofail,x-systemd.device-timeout=120 0 0
```

This drops the cosmetic `x-gvfs-show` and adds a 2-minute timeout so systemd
waits for a slow drive. Boot never hangs because `nofail` is kept.

## Troubleshooting

### Apps empty after reboot (fixed since 2026-09-11)

**Root cause:** Docker's restart policy restarted all containers before the
drive was mounted, pointing bind-mounts at empty directories. This is now
prevented by two systemd units (see Automatic Startup above).

If you are still running the old setup without the fix, or if the drive was
physically missing/disconnected at boot:

```bash
# 1. Verify the drive is a real mount (not just an empty directory):
findmnt -rn -o SOURCE /mnt/drive

# 2. If it is, restart the stack:
sudo systemctl restart cloud-homeserver.service

# If the drive was absent, plug it in first, then:
sudo systemctl start mnt-drive.mount
sudo systemctl restart cloud-homeserver.service
```

### "Container name already in use" error

This happens when containers exist from a different compose project or a stale run:

```bash
docker rm -f sonarr radarr transmission jellyfin prowlarr jellyseerr \
            nginx-reverseproxy-manager actual_server watchtower \
            homeassistant yacht
docker compose up -d
```

## Optional Modules

### Immich (Photo Backup)

1. Add the Immich variables to your `.env` (see `.env.example`).
2. Start with the Immich compose file:
   ```bash
   docker compose -f docker-compose.yml -f docker-compose.immich.yml up -d
   ```

## Optional Hardening Notes

- **Watchtower + Yacht** both mount `/var/run/docker.sock`, giving them full
  control over all containers on this host. Consider scoping Watchtower to only
  containers with `com.centurylinklabs.watchtower.enable=true` and removing
  Yacht if you do not actively use its web UI.
- **HomeAssistant** runs in privileged mode with host networking. This is
  intentional for Home Assistant but limits container isolation.
- **Leftover directory:** `/mnt/drive/Mealie` exists on the drive but Mealie
  was removed from the compose file. Safe to delete.


## Docker useful info

```
systemctl status cloud-homeserver.service && findmnt -rn -o SOURCE /mnt/drive
```