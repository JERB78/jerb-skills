---
name: docker-master
description: Complete Docker workflow skill — create, modify, manage, analyze, debug, and repair Docker containers, images, networks, volumes, and Compose stacks. Use this skill whenever the user mentions Docker, containers, Dockerfile, docker-compose, container debugging, image building, pulling/pushing from Docker Hub or GitHub Container Registry (GHCR), volume mounting issues, network connectivity inside containers, OOM kills, container won't start, dangling images, disk cleanup, security scanning (Trivy/Scout), multi-stage builds, healthchecks, or any container orchestration task. Strongly prefer this skill over giving generic Docker advice — it has decision trees, Dockerfile templates for 9+ stacks, Windows-specific gotchas, safety rails for destructive ops, and battle-tested debugging workflows. Triggers on Spanish too: "armar imagen", "contenedor no arranca", "dockerizar", "compose con db", "limpiar docker", etc.
version: 1.0.0
---

# Docker Master

> Comprehensive Docker workflow skill. Covers the full lifecycle: author Dockerfiles per stack, build from any source (Hub / GitHub / local), run + debug containers, orchestrate with Compose, audit security, clean up safely. Windows-aware. Bilingual EN/ES comments in generated code.

## Why this skill exists

Docker has a huge surface area and the answers vary by:
- **What you're trying to do** (build, run, debug, clean, audit, orchestrate)
- **Where the image comes from** (Hub, GitHub repo, local context, GHCR, ECR)
- **What stack you're containerizing** (Node, Python, Rust, Go, .NET, etc — each has different best practices)
- **What OS you're on** (Windows has unique gotchas — case sensitivity, path translation, WSL2 backend)
- **Whether it's dev or prod** (compose patterns, security defaults, secrets handling)

This skill encodes decision trees for all these axes, plus templates for the most common scenarios. Use it whenever Docker is involved — don't improvise.

---

## When to trigger this skill

Trigger on any of these (English + Spanish):

- "dockerize / dockerizar [stack]"
- "build image / armar imagen"
- "container won't start / el contenedor no arranca"
- "out of memory / OOM / contenedor se cae"
- "compose / docker-compose / orquestar X servicios"
- "pull from Docker Hub / GitHub / GHCR"
- "Dockerfile para [Node/Python/Rust/Go/etc]"
- "clean up docker / limpiar docker / disk full"
- "security scan / vulnerabilidades en imagen"
- "multi-stage build / build con etapas"
- "healthcheck / health check"
- "volume mount / mount no funciona"
- "container can't reach network / DNS no resuelve dentro del container"
- "build from git URL / build desde repo"
- "image too big / optimizar tamaño imagen"
- "no space left on device" (often docker disk issue)

Do NOT trigger for:
- Kubernetes (use a k8s-specific skill if exists)
- Pure cloud provider container services (ECS, Cloud Run) — use cloud-specific skills
- Non-container deployment (use stack-specific skills)

---

## The workflow

When invoked, follow this routing:

### Step 1 — Classify the request

| User says... | Route to... |
|---|---|
| "dockerize / write Dockerfile for X" | **Author flow** (Step 2 + dockerfile templates) |
| "run / start / exec container" | **Container ops flow** (Step 3 + references/containers.md) |
| "build / pull / push image" | **Image flow** (Step 4 + references/images.md + references/source-routing.md) |
| "compose / multi-service" | **Compose flow** (Step 5 + references/compose.md + compose templates) |
| "won't start / error / debug / why is X failing" | **Debug flow** (Step 6 + references/debug-decision-trees.md) |
| "clean / prune / disk full" | **Cleanup flow** (Step 7 + scripts/safe_cleanup.*) |
| "security / audit / vulnerabilities" | **Security flow** (Step 8 + references/security-and-hardening.md) |

Multiple flows can be active in one turn (e.g., "dockerize my Node app and add a Postgres in compose" → Author flow + Compose flow).

### Step 2 — Author flow (Dockerfile generation)

1. Ask: **what stack?** (Node, Python, Rust, Go, .NET, PHP, Ruby, Java, Tauri desktop, other)
2. Ask: **dev or prod target?** (different optimizations apply)
3. Ask: **what does the app need at runtime?** (DB connection? external APIs? specific port?)
4. Pull the matching template from `assets/dockerfiles/<stack>.Dockerfile`
5. Adapt placeholders (port, command, deps file)
6. Generate `.dockerignore` matching the stack
7. Present + offer to also generate compose if it has external deps (DB, etc)

Always use multi-stage builds for compiled languages (Rust, Go, .NET, Java). Always use non-root user. See `references/dockerfile-best-practices.md` for full rules.

### Step 3 — Container ops flow

Common operations and their idiomatic invocations are in `references/containers.md`. For interactive sessions:

- `docker exec -it <container> <shell>` (bash, sh, or ash depending on base image)
- `docker logs -f --tail 100 <container>` (live logs)
- `docker inspect <container>` (full state — pipe to `jq` for navigation)
- `docker stats` (real-time CPU/RAM/network)
- `docker top <container>` (running processes inside)

### Step 4 — Image flow

For pulling: route by source per `references/source-routing.md`.

For building from a GitHub repo (one of user's requirements):
```bash
# Direct build from public repo URL
docker build -t myapp https://github.com/user/repo.git

# Specific branch + subdir
docker build -t myapp https://github.com/user/repo.git#main:path/to/dockerfile-dir

# Private repo: clone first then build
git clone git@github.com:user/repo.git && cd repo && docker build -t myapp .
```

For pushing to registries: see `references/images.md`. Multi-platform builds use BuildKit's `docker buildx`.

### Step 5 — Compose flow

For multi-service: use templates in `assets/compose-templates/`. The 3 templates cover:
- `dev-postgres-redis.yml` — local dev stack with hot reload
- `prod-app-db.yml` — production app + db with healthchecks + restart policies
- `full-stack-nginx.yml` — frontend + backend + db + nginx reverse proxy

See `references/compose.md` for patterns: `.env` files, profiles, depends_on with conditions, secrets, override files.

### Step 6 — Debug flow (the most common reason this skill triggers)

**Always run this routine first when user says "container won't start" or "X isn't working":**

```bash
# 1. What's the current state?
docker ps -a --filter "name=<container>" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. What did it print before dying?
docker logs --tail 100 <container>

# 3. Why did it die? (exit code + reason)
docker inspect <container> --format '{{.State.Status}}: exit {{.State.ExitCode}} ({{.State.Error}}) — OOMKilled={{.State.OOMKilled}}'

# 4. What was the last health check result? (if applicable)
docker inspect <container> --format '{{json .State.Health}}' | jq

# 5. System-level events around the failure?
docker events --since 1h --filter "container=<container>"
```

Then route through `references/debug-decision-trees.md` based on what you see:
- Exit code 0 → app finished normally (maybe expected)
- Exit code 1 → app crashed (logs have details)
- Exit code 125 → docker daemon error (often config issue)
- Exit code 126/127 → command/permission issue
- Exit code 137 → SIGKILL (often OOM)
- Exit code 139 → segfault (rare, often C-extension)
- Exit code 143 → SIGTERM (graceful shutdown)
- OOMKilled=true → out of memory (see memory limits + container size)

For Windows-specific issues (volume permissions, path translation, WSL2 backend) see `references/windows-gotchas.md`.

### Step 7 — Cleanup flow

⚠ Cleanup is destructive. ALWAYS:
1. Show what will be deleted with estimated reclaimed space
2. Wait for user confirmation
3. Then execute

Use `scripts/safe_cleanup.ps1` (Windows) or `scripts/safe_cleanup.sh` (bash). The scripts:
- Run `docker system df` first to show current usage
- Estimate space reclaimed by each prune step
- Prompt before each destructive command
- Skip volumes by default (data loss risk)

NEVER run `docker system prune -a --volumes -f` without explicit user request. Volumes can contain irreplaceable data.

### Step 8 — Security flow

For image scanning use Trivy (preferred, OSS) or Docker Scout (built-in to Docker Desktop). See `references/security-and-hardening.md` for:
- Scan command syntax
- How to read severity (CRITICAL vs HIGH vs MEDIUM)
- Common remediations (upgrade base image, change distroless, pin versions)
- Secrets handling (NEVER bake secrets into images — use BuildKit `--secret` or runtime env)
- Image signing with cosign
- SBOM generation

Use `scripts/audit_security.ps1` for batch scanning all local images.

---

## Hard rules (non-negotiable)

1. **Always use multi-stage builds** for compiled languages (Rust, Go, .NET, Java). Single-stage = bloat.
2. **Always use non-root user** in production Dockerfiles. `USER 1000:1000` minimum.
3. **Always pin base image versions** (`node:22.10.0-alpine` not `node:latest`). `latest` breaks reproducibility.
4. **Always include `.dockerignore`** matching the stack. Without it, secrets and node_modules leak into images.
5. **Always include healthchecks** in production compose files. Without them, `depends_on` can't gate properly.
6. **Never bake secrets into images.** Use BuildKit `--secret` for build-time, env vars for runtime.
7. **Never run `prune -a --volumes -f`** without explicit user confirmation per volume.
8. **Always state OS context** when giving commands (Windows PowerShell vs Bash vs WSL2 vs Linux).
9. **For Windows users (this owner): WSL2 backend, paths translated via Docker Desktop.** Bind mounts use Linux-style paths (`/c/Users/...` not `C:\Users\...`) when invoked from bash. From PowerShell, Windows paths work but case-sensitivity surprises happen.
10. **Verify after destructive operations** — `docker system df` after cleanup, `docker ps` after restart, etc.

---

## Files in this skill

- `SKILL.md` — this file (entry point, routing logic)
- `references/containers.md` — container ops cheatsheet (run/exec/logs/inspect/health)
- `references/images.md` — image ops + registry cheatsheet (pull/build/push/tag/multi-platform)
- `references/compose.md` — compose patterns (.env, profiles, depends_on, secrets, override files)
- `references/debug-decision-trees.md` — troubleshooting routes by symptom (won't start / OOM / network / volume / build fail)
- `references/dockerfile-best-practices.md` — multi-stage, .dockerignore, layer caching, non-root, distroless
- `references/windows-gotchas.md` — Win-specific (case sensitivity, paths, WSL2, Docker Desktop, line endings)
- `references/security-and-hardening.md` — Trivy/Scout/cosign, secrets, image signing, SBOM
- `references/source-routing.md` — decide Hub vs GitHub vs Local vs private registry (GHCR/ECR/etc)
- `scripts/safe_cleanup.ps1` / `safe_cleanup.sh` — prune with confirmations + space estimates
- `scripts/inspect_failed.ps1` — diagnostic helper for failed containers (logs + events + inspect + df)
- `scripts/build_from_github.sh` — build directly from GitHub URLs with options
- `scripts/audit_security.ps1` — batch Trivy/Scout scan across all local images
- `assets/dockerfiles/` — production-grade templates for 9 stacks (node, python, rust, go, dotnet, php, ruby, java, tauri)
- `assets/compose-templates/` — 3 production patterns (dev-postgres-redis, prod-app-db, full-stack-nginx)
- `evals/evals.json` — test cases for skill-creator's eval loop

---

## Common pitfalls

1. **Docker Desktop on Windows uses WSL2 backend by default** — volume performance from Windows filesystem is slow. For dev, mount your code from inside WSL (`\\wsl$\Ubuntu\home\user\project`), NOT from `C:\Users\...`.
2. **`docker pull X` on Windows can fail with TLS errors** — usually a corporate proxy or Cloudflare 1.1.1.1 DNS issue. Try `nslookup registry-1.docker.io` first.
3. **Line endings in scripts copied from Windows to a Linux container** — Dockerfile `COPY script.sh /usr/local/bin/` then `RUN script.sh` fails with cryptic "command not found". Add `RUN sed -i 's/\r$//' script.sh` or use `.gitattributes` with `* text=auto eol=lf`.
4. **`depends_on` doesn't wait for service readiness** by default — only for container start. Use `condition: service_healthy` with a healthcheck on the dependency.
5. **`docker logs` on a stopped container still works** — useful for postmortem. Don't `docker rm` before reading logs.
6. **Build cache invalidation cascades from any changed instruction down** — order Dockerfile instructions from least-frequently-changing (FROM, deps install) to most-frequently-changing (COPY app code, build). Reorder if rebuilds are slow.
7. **Multi-platform builds with `buildx`** require QEMU emulator on Linux/Mac, Docker Desktop has it built-in on Windows.
8. **Image size — `node:22-alpine` is ~150 MB, `node:22` is ~900 MB.** Always prefer `-alpine` or `-slim` unless your app needs glibc.
9. **`COPY --chown=user:user` instead of `COPY` + `RUN chown`** saves a layer and time.
10. **Healthcheck interval too short (e.g., `--interval=5s`) can mask real issues** — use 30s+ for prod, 10s for fast-failing dev containers.
11. **`.env` files in compose** — `${VAR}` substitution happens at compose-up time, not at container run time. If you change `.env`, you must `compose down && compose up`.
12. **Bind mounts override the image's content at the mount point** — useful for dev (hot reload), but if you mount `./` over `/app` and `/app/node_modules` was built in the image, it gets shadowed. Use named volume for `node_modules`.

---

## Reading order for new agents using this skill

When a new agent invocation happens:
1. Skim SKILL.md (this file) — understand the routing
2. Identify which flow (1-8) applies to the user's request
3. Read the relevant `references/<topic>.md` for the flow
4. If generating Dockerfile, pull from `assets/dockerfiles/<stack>.Dockerfile`
5. If generating compose, pull from `assets/compose-templates/`
6. If destructive op, use `scripts/safe_cleanup.*` — never wing it
7. Always verify after acting (`docker ps`, `docker system df`, `docker compose ps`, etc.)
