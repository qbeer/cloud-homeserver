## Notes

1) Mounted my hard drive to `/mnt/drive` and created the folders `Movies`, `TV`, `Downloads` so that the mounted volumes are `/mnt/drive/Movies`, `/mnt/drive/TV`, `/mnt/drive/Downloads`.

2) docker compose up -d --build # To build the images and start the containers.

3) docker logs -f jellyfin

## restart - remove - rebuild

```bash
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)
docker compose up -d --build --remove-orphans
```