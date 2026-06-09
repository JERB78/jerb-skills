# Debug Decision Trees

> Symptom → root cause → fix. Use these when the user reports something broken.
> Always run the universal diagnostic first (see SKILL.md Step 6) before routing.

---

## Tree 1: "Container won't start" / "Container keeps crashing"

```
docker ps -a   →  see Status column
│
├─ Status: "Exited (0)"
│  └─ App finished normally. Often intentional (one-shot job).
│     Check: was this supposed to be long-running? If yes, app's main process exited.
│     Common causes:
│       - CMD/ENTRYPOINT runs a non-daemon command that returns immediately
│       - Script doesn't have a foreground process (use `tail -f /dev/null` for testing)
│       - PID 1 forked + exited (run with `--init` flag or use tini)
│
├─ Status: "Exited (1)"
│  └─ App crashed. Read logs:
│     docker logs --tail 200 <container>
│     Common causes:
│       - Missing env var (app expects DATABASE_URL etc)
│       - Failed to bind to port (something else on that port)
│       - DB connection refused (db not ready yet — use depends_on healthcheck)
│       - File not found (volume mount path wrong)
│       - Syntax error in code
│       - Permission denied (often non-root user can't write to /app/data)
│
├─ Status: "Exited (125)"
│  └─ Docker daemon error. Misconfiguration before container started.
│     Examples: invalid --network name, invalid volume syntax, image arch mismatch.
│     Re-read the docker run command carefully.
│
├─ Status: "Exited (126)"
│  └─ Container command found but not executable.
│     Common: COPY script.sh + missing chmod +x. Fix in Dockerfile:
│     RUN chmod +x /usr/local/bin/script.sh
│
├─ Status: "Exited (127)"
│  └─ Container command not found at all.
│     Common: wrong PATH, binary doesn't exist at specified location, typo in CMD.
│     Test: docker run --rm -it <image> sh → then manually try the command.
│
├─ Status: "Exited (137)"
│  └─ SIGKILL — usually OOM (Out Of Memory).
│     Confirm: docker inspect <container> --format='{{.State.OOMKilled}}'
│     If true: container hit memory limit. Either:
│       - Increase limit: docker run -m 1g ...
│       - Reduce app memory usage (heap size, caching, etc)
│       - Add swap (--memory-swap)
│     If false: something else killed it (host shutdown, manual kill).
│
├─ Status: "Exited (139)"
│  └─ Segfault (SIGSEGV). Rare. Usually:
│     - C extension bug (Node native modules, Python C extensions)
│     - Wrong CPU architecture (running x86 image on ARM, or vice versa)
│     Check: docker run --platform linux/amd64 ... (if on Apple Silicon)
│
├─ Status: "Exited (143)"
│  └─ SIGTERM — graceful shutdown. Expected if you did `docker stop`.
│
├─ Status: "Restarting"
│  └─ Crash loop. Check logs of last N attempts:
│     docker logs --tail 200 <container>
│     Same diagnostics as Exited (1).
│     If restart spam is filling logs: `docker update --restart=no <container>` to stop.
│
└─ Status: "Created" (never started)
   └─ Container created but `docker start` not called or failed.
      Try: docker start <container> → if it errors, the message will explain.
```

---

## Tree 2: "App inside container can't reach external network"

```
docker exec <container> ping -c 1 google.com
│
├─ "ping: bad address 'google.com'"  → DNS issue
│  └─ docker exec <container> cat /etc/resolv.conf
│     - If empty or 127.0.0.x → docker DNS misconfigured
│     - Fix at run: docker run --dns=8.8.8.8 ...
│     - Fix at daemon level: edit /etc/docker/daemon.json with "dns": ["8.8.8.8", "1.1.1.1"]
│     - On Windows: edit via Docker Desktop settings → Docker Engine
│
├─ "Network is unreachable"  → routing issue
│  └─ docker exec <container> ip route
│     Container has no default route. Check:
│     - Custom network created without internet gateway
│     - --network=none flag was used
│     - Corporate firewall blocking docker bridge
│
├─ "Connection refused" (target host found, port closed)  → target service down
│  └─ Not a Docker issue. The remote service isn't listening.
│
├─ Ping succeeds  → DNS + routing OK
│  └─ App-specific issue (proxy needed, SSL cert validation, etc.).
│     Check app logs for actual error.
```

---

## Tree 3: "Container A can't reach container B" (intra-Docker)

```
1. Are both containers on the SAME network?
   docker inspect <A> --format='{{json .NetworkSettings.Networks}}'
   docker inspect <B> --format='{{json .NetworkSettings.Networks}}'
   │
   ├─ Different networks → connect one to the other's network:
   │  docker network connect <network-name> <container-A>
   │
   └─ Same network → continue to step 2

2. Try ping by container NAME (not IP — IPs change):
   docker exec <A> ping -c 1 <B>
   │
   ├─ "bad address" → DNS issue WITHIN docker
   │  - Default `bridge` network doesn't have service discovery!
   │  - Either create a user-defined network (docker network create) and put both there
   │  - Or use container's IP (docker inspect <B> --format='{{.NetworkSettings.IPAddress}}')
   │
   └─ Ping works → DNS OK, continue to step 3

3. Try connecting to the service port:
   docker exec <A> wget -O- http://<B>:3000/health  (or curl, or nc)
   │
   ├─ "Connection refused" → B's service isn't listening
   │  - Check B's logs: is the app actually running?
   │  - Check B's port: is it listening on 0.0.0.0 not just 127.0.0.1?
   │    (e.g., Node default `http.listen(3000)` binds to all interfaces, but some apps default to localhost only)
   │
   ├─ "Connection timeout" → firewall or network policy
   │  - Check `internal: true` on network in compose (blocks external + outbound)
   │
   └─ Works but wrong response → app-level routing issue, not Docker
```

---

## Tree 4: "Volume mount isn't working" / "Files don't show up in container"

```
1. What kind of mount?
   docker inspect <container> --format='{{json .Mounts}}'

2. Common issues:

   ├─ Bind mount: host path doesn't exist
   │  - Docker creates it as empty dir (silent failure!)
   │  - Verify host path: ls -la /host/path
   │
   ├─ Bind mount: wrong permissions
   │  - Container's USER can't read/write the mounted dir
   │  - Fix on host: chmod -R 777 /host/path  (lazy fix)
   │  - Better: chown -R <containerUID>:<containerGID> /host/path
   │  - Find container UID: docker exec <container> id
   │
   ├─ Bind mount: Windows-specific issues
   │  - See windows-gotchas.md — case sensitivity, path translation, sharing not enabled
   │
   ├─ Bind mount shadows image content
   │  - Image had /app/node_modules from build, you mounted ./ over /app → node_modules gone
   │  - Solution: also mount a named volume for /app/node_modules:
   │      volumes:
   │        - ./:/app
   │        - node_modules:/app/node_modules   # protect this from bind mount
   │
   ├─ Named volume: data persists from old container
   │  - Volume contains old/wrong data
   │  - docker volume rm <volume-name> to wipe (CONFIRM — destructive)
   │
   └─ tmpfs mount: data lost on stop (expected behavior)
      - Use volume or bind for persistence
```

---

## Tree 5: "Build is failing or slow"

```
1. Read the error message carefully — Dockerfile builds usually fail loudly.

2. Common build errors:

   ├─ "no space left on device"
   │  - Docker is full. See cleanup flow in SKILL.md Step 7.
   │  - docker system df → see what's eating space
   │
   ├─ "failed to compute cache key" / "executor failed"
   │  - BuildKit version mismatch. Try: DOCKER_BUILDKIT=0 docker build ... (disable buildkit)
   │  - Or: docker buildx prune (clean buildkit cache)
   │
   ├─ "manifest unknown" / "image not found"
   │  - Base image tag doesn't exist. Check: docker pull <base-image> manually.
   │  - Tag may have been deprecated (e.g., node:14-stretch removed)
   │
   ├─ "permission denied" during RUN
   │  - USER directive is set to non-root, but RUN command needs root
   │  - Either: USER root before that RUN, then USER back to non-root after
   │  - Or: chown things in same RUN as creation
   │
   ├─ "could not connect to npm/pip/cargo registry"
   │  - Network access during build is required by package installers
   │  - Corporate proxy: pass HTTPS_PROXY as ARG, set via ENV in Dockerfile
   │  - Try docker build --network=host (uses host network for build only)
   │
   ├─ "killed" with no stack trace
   │  - Likely OOM during build (compilation hit memory limit)
   │  - Add --memory option to BuildKit: docker build --memory=4g ...
   │  - Or split heavy compilation into smaller stages
   │
   └─ Build is slow (not failing)
      - Layer cache misses — check Dockerfile ordering (least-changing first)
      - Use --pull only when intentional (otherwise reuses cached base)
      - Use BuildKit (DOCKER_BUILDKIT=1) — much faster than legacy builder
      - Multi-stage with --target debugging-stage
```

---

## Tree 6: "Docker disk is full" / "No space left on device"

```
1. Check what's using space:
   docker system df
   docker system df -v   (verbose, per-item)

2. Three usual suspects:

   ├─ Images (often 50-90% of usage on dev machines)
   │  - docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | sort -k2 -h
   │  - Delete unused: docker image prune -a   (REMOVES IMAGES NOT IN USE)
   │
   ├─ Volumes (can be huge if long-running DB containers)
   │  - docker volume ls
   │  - docker volume inspect <name>   (path on disk)
   │  - DANGER: volumes are usually irreplaceable data. Only prune with explicit user OK.
   │
   └─ Build cache (BuildKit)
      - docker buildx prune   (clean buildkit cache)
      - docker builder prune  (legacy builder cache)

3. On Windows, the actual disk usage is inside the WSL2 VM disk image:
   - File: %LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx
   - To reclaim Windows disk space after pruning inside docker:
     wsl --shutdown
     Optimize-VHD -Path "$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx" -Mode Full
     (requires Hyper-V tools)
```

---

## Tree 7: "Image is too big"

```
1. See per-layer breakdown:
   docker history --human=true --format "table {{.Size}}\t{{.CreatedBy}}" <image> | sort -rh

2. Common bloat causes (in order of frequency):

   ├─ Using full base image instead of -alpine/-slim
   │  - node:22 → 900 MB.  node:22-alpine → 150 MB. Almost always switch.
   │
   ├─ Not multi-stage building
   │  - Build deps (gcc, make, dev tools) stay in image
   │  - Multi-stage: FROM ... AS builder + FROM smaller-runtime + COPY --from=builder
   │
   ├─ apt-get install without --no-install-recommends + cleanup
   │  - GOOD: RUN apt-get update && apt-get install -y --no-install-recommends curl \
   │            && rm -rf /var/lib/apt/lists/*
   │
   ├─ pip/npm cache not cleaned
   │  - pip: --no-cache-dir flag
   │  - npm: --cache /tmp/.npm-cache + clean it (but better: npm ci doesn't cache)
   │  - cargo: separate stage for cargo fetch, then copy final binary
   │
   ├─ COPY of unnecessary files (no .dockerignore)
   │  - .git folder (often 100+ MB)
   │  - node_modules from host (rebuild inside container instead)
   │  - tests, docs, IDE files
   │
   └─ Large model files / assets that should be in volumes
      - Don't bake 5GB ML model into image. Mount it as volume.
```

---

## Tree 8: "Compose stack: X service is unhealthy or not ready"

```
1. docker compose ps   → see status column

2. If "(unhealthy)":
   docker inspect $(docker compose ps -q <service>) --format='{{json .State.Health}}' | jq
   - Look at the most recent health check log entry
   - Common: healthcheck command itself is wrong (typo, missing binary in image)
   - Test the healthcheck manually: docker compose exec <service> sh -c "<healthcheck-cmd>"

3. If dependencies are racing:
   - Verify depends_on uses condition: service_healthy
   - Without condition, compose only waits for container START not for app readiness
   - Add or fix healthcheck on the dependency

4. If service starts but immediately crashes:
   - Same as Tree 1 (container won't start)
   - docker compose logs <service> → read the error
```

---

## Quick-reference: docker exit codes

| Code | Meaning | Common cause |
|------|---------|--------------|
| 0    | Success / clean exit | App finished, expected if one-shot |
| 1    | Generic error | Read logs |
| 2    | Misuse of shell built-in | Bad shell syntax |
| 125  | Docker daemon error | Misconfig of docker run |
| 126  | Cannot execute | Not executable (chmod missing) |
| 127  | Command not found | Bad path, typo |
| 137  | SIGKILL | Usually OOM |
| 139  | SIGSEGV (segfault) | C extension bug, arch mismatch |
| 143  | SIGTERM | Graceful shutdown |
