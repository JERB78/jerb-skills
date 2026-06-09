# Containers — Operations Cheatsheet

> Reference for `docker run`, `exec`, `logs`, `inspect`, lifecycle, networking, volumes.
> Read this when the user is running, managing, or debugging containers (not building images).

---

## Lifecycle

```bash
# Run (creates + starts) — most common forms
docker run -d --name web -p 8080:80 nginx:1.27-alpine                 # detached, port mapped
docker run --rm -it ubuntu:24.04 bash                                  # interactive, auto-delete on exit
docker run -d --restart=unless-stopped --name api myapp:v1            # auto-restart on failures

# State transitions
docker start <container>        # start stopped container
docker stop <container>         # graceful (SIGTERM, then SIGKILL after 10s)
docker stop -t 30 <container>   # extend grace period
docker restart <container>      # stop + start
docker kill <container>         # SIGKILL immediately (no grace)
docker rm <container>           # delete stopped container
docker rm -f <container>        # force delete (kills if running)
docker rename old new           # rename without restart
docker pause / unpause          # freeze process (cgroups freezer) — rare
```

## Listing + inspection

```bash
# Listing
docker ps                       # running only
docker ps -a                    # all (including stopped)
docker ps --filter "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
docker ps -q                    # IDs only — useful for pipes: docker rm $(docker ps -aq)

# Inspection
docker inspect <container>                                # full JSON
docker inspect <container> --format '{{.State.Status}}'   # extract specific field
docker inspect <container> --format '{{json .Config.Env}}' | jq
docker inspect <container> --format '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} -> {{(index $conf 0).HostPort}}{{"\n"}}{{end}}'

# Stats (live resource usage)
docker stats                              # all running containers, live
docker stats --no-stream                  # snapshot (one read)
docker stats <container> --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Processes inside
docker top <container>                    # ps aux equivalent
```

## Logs

```bash
docker logs <container>                          # all
docker logs --tail 100 <container>                # last 100 lines
docker logs -f <container>                        # follow (live)
docker logs --since 30m <container>               # last 30 min
docker logs --until "2026-01-01T00:00:00" <container>
docker logs -t <container>                        # add timestamps
docker logs <container> 2>&1 | grep ERROR         # filter

# Compose equivalents
docker compose logs                               # all services
docker compose logs -f web                        # follow one service
docker compose logs --since 10m --tail 50 db
```

## Exec (run command inside)

```bash
# Interactive shell — try in this order based on base image
docker exec -it <container> bash       # debian/ubuntu/most full distros
docker exec -it <container> sh         # alpine, distroless, slim
docker exec -it <container> ash        # alpine specifically

# Run a single command
docker exec <container> ls -la /app
docker exec -u root <container> apk add curl     # as root (override USER directive)
docker exec -e DEBUG=1 <container> node script.js  # extra env vars
docker exec -w /app/subdir <container> npm test    # specify workdir
```

## Networking

```bash
# Networks
docker network ls                                # list
docker network create my-net                      # create bridge
docker network create --driver overlay swarm-net  # swarm overlay
docker network inspect bridge                     # detail
docker network connect my-net <container>          # attach
docker network disconnect my-net <container>       # detach
docker network rm my-net                          # delete (must be empty)

# Run on a specific network
docker run --network my-net --name api myapp
# Containers on same network can reach each other by name: http://api:3000

# Port mapping (-p HOST:CONTAINER)
docker run -p 8080:80 nginx                       # 8080 on host → 80 in container
docker run -p 127.0.0.1:8080:80 nginx            # bind to localhost only
docker run -P nginx                               # random host port for each EXPOSE

# DNS troubleshooting inside container
docker exec <container> cat /etc/resolv.conf
docker exec <container> nslookup google.com
docker exec <container> ping -c 1 other-container
```

## Volumes (data persistence)

```bash
# Volumes (managed by docker, in /var/lib/docker/volumes/ or Windows equivalent)
docker volume ls
docker volume create my-data
docker volume inspect my-data
docker volume rm my-data
docker volume prune                # delete all unused volumes — DESTRUCTIVE

# Run with volume
docker run -v my-data:/data myapp                          # named volume
docker run -v /host/path:/container/path myapp             # bind mount
docker run -v /host/path:/container/path:ro myapp          # read-only bind
docker run --mount type=volume,source=my-data,target=/data myapp  # modern syntax
docker run --mount type=bind,source=$(pwd),target=/app myapp      # bind via --mount
docker run --tmpfs /tmp myapp                              # tmpfs (in-memory, fast, ephemeral)

# Inspect volume contents (Linux)
docker run --rm -v my-data:/data busybox ls -la /data
```

## Resource limits

```bash
docker run -m 512m --cpus="1.5" --name limited myapp
# -m / --memory   : memory cap (k/m/g)
# --memory-swap   : memory + swap (set equal to -m to disable swap)
# --cpus          : fractional CPU count (1.5 = 1.5 cores)
# --cpu-shares    : relative weight vs other containers (default 1024)
# --pids-limit    : max processes
# --ulimit nofile=65536:65536  : file descriptor limit
```

## Environment + config

```bash
docker run -e VAR=value myapp
docker run --env-file ./prod.env myapp
docker run -e VAR1=v1 -e VAR2=v2 myapp

# Pass current shell env var without value (uses current value)
docker run -e DATABASE_URL myapp

# Override CMD/ENTRYPOINT
docker run myapp echo "override"                  # overrides CMD
docker run --entrypoint sh myapp -c "echo hello"  # overrides ENTRYPOINT
```

## Health checks

```bash
# Inline at run time
docker run --health-cmd="curl -f http://localhost/health || exit 1" \
           --health-interval=30s \
           --health-timeout=5s \
           --health-retries=3 \
           --health-start-period=30s \
           myapp

# Read healthcheck status
docker inspect --format='{{json .State.Health}}' <container> | jq
docker ps --format "table {{.Names}}\t{{.Status}}"  # shows "(healthy)" / "(unhealthy)"
```

## Copy files in/out

```bash
docker cp ./localfile.txt <container>:/app/file.txt        # host → container
docker cp <container>:/app/output.log ./output.log         # container → host
docker cp -a <container>:/app/. ./output/                  # entire dir, preserve perms
```

## Common one-liners (memorize these)

```bash
# Kill + remove all containers
docker rm -f $(docker ps -aq)

# Stop everything
docker stop $(docker ps -q)

# Logs of last failed container
docker logs $(docker ps -aqf "status=exited" | head -1)

# Shell in newest running container
docker exec -it $(docker ps -q | head -1) sh

# Print all env vars of a container
docker inspect <container> --format='{{range .Config.Env}}{{println .}}{{end}}'

# Find which container owns a port
docker ps --filter "publish=8080"

# Find by image name
docker ps -a --filter "ancestor=nginx"
```
