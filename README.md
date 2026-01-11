# Cloud Homeserver

A Docker Compose based home server setup for media management and home automation.

## Project Structure

- `docker-compose.yml`: Main service definition.
- `scripts/`: Helper scripts for setup and maintenance.
- `systemd/`: Systemd service files for automatic startup.
- `.env`: (Created from `.env.example`) Configuration variables.

## Getting Started

### 1. Configuration

1.  Copy the example environment file:
    ```bash
    cp .env.example .env
    ```
2.  Edit `.env` and set your configuration variables, especially `ROOT_DIR` (where your media drive is mounted).
    ```bash
    nano .env
    ```

### 2. Setup

1.  Create necessary directories:
    ```bash
    python3 scripts/create_dirs.py
    ```
2.  Start the containers:
    ```bash
    docker compose up -d
    ```

### 3. Automatic Startup (Systemd)

To ensure the server starts automatically on boot (and waits for your drive to mount):

1.  Edit `systemd/cloud-homeserver.service` and ensure the paths are correct for your system.
2.  Install the service:
    ```bash
    sudo cp systemd/cloud-homeserver.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable cloud-homeserver.service
    sudo systemctl start cloud-homeserver.service
    ```

- **Sync/Backup**: `scripts/sync.sh` uses rsync to backup your data (excluding large media files) to a backup location.

## Optional Modules

### Immich (Photo Backup)
Immich is included but disabled by default. To enable it:

1.  Add the Immich variables to your `.env` file (see `.env.example`).
2.  Start the stack with the localized compose file:
    ```bash
    docker compose -f docker-compose.yml -f docker-compose.immich.yml up -d
    ```
    *Note: You may need to create the directories defined in your `.env` manually, as the auto-script currently only scans the main compose file.*

## Troubleshooting

### Configs not loading on reboot
If you restart your computer and find that containers are empty or missing configurations, it is likely because Docker started *before* your external drive was mounted.
**Solution:** Use the included systemd service (see "Automatic Startup" above). It is configured to wait for the mount point before starting Docker containers.

### "Container name already in use" error
If you see errors like `Conflict. The container name "/sonarr" is already in use`, it usually means you have containers running from a previous setup (or different directory).
**Solution:**
1. Stop and remove the old containers:
   ```bash
   docker rm -f sonarr radarr transmission jellyfin prowlarr jellyseerr nginx-reverseproxy-manager actual_server watchtower homeassistant yacht
   ```
2. Start the stack again:
   ```bash
   docker compose up -d
   ```