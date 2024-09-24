### Generating a hash for a user password
```bash
docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'YOUR PASSWORD HERE'
```

## Notes

1) Mounted my hard drive to `/mnt/media` and created the folders `Movies`, `TV`, `Downloads` so that the mounted volumes are `/mnt/media/Movies`, `/mnt/media/TV`, `/mnt/media/Downloads`.

2) docker compose up -d --build # To build the images and start the containers.

3) docker logs -f traefik

