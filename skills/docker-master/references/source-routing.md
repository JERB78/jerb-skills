# Source Routing — Where Should This Image Come From?

> Decision tree for: "I need image X — pull from Hub? Build from GitHub? Build local?"

---

## The 4 sources

| Source | Use when | How |
|---|---|---|
| **Docker Hub** | Official images of well-known software (Postgres, Redis, nginx, language base) | `docker pull <image>` |
| **GHCR (GitHub Container Registry)** | Images published by GitHub projects, your own org's CI builds | `docker pull ghcr.io/owner/repo:tag` |
| **GitHub repo build** | Open-source app you want to build from source (no published image, or you want HEAD) | `docker build https://github.com/user/repo.git` |
| **Local build** | Your own apps in development; modifications you don't want to push yet | `docker build -t name .` |
| **Private registry** | Internal company images (ECR, GCR, Harbor, self-hosted Registry) | Same as Hub but with prefix |

---

## Decision tree

```
You need an image of X
│
├─ Is X "Postgres", "Redis", "nginx", or another popular service?
│  └─ YES → Docker Hub. Always. (Official image.)
│           docker pull postgres:17-alpine
│
├─ Is X your own application?
│  ├─ In active development on this machine?
│  │  └─ Local build. docker build -t myapp .
│  │
│  └─ Already deployed to a registry by CI?
│     └─ Pull from registry. docker pull ghcr.io/me/myapp:v1
│
├─ Is X an open-source project you want to run?
│  ├─ Has an official image? (check Docker Hub or project README)
│  │  └─ YES → Pull it. docker pull <image>
│  │
│  └─ No official image, only source code on GitHub?
│     ├─ Has a Dockerfile in the repo?
│     │  └─ Build from URL. docker build https://github.com/owner/repo.git
│     │
│     └─ No Dockerfile?
│        └─ You'll need to write one. See dockerfile-best-practices.md
│
└─ Is X an internal company artifact?
   └─ Pull from your private registry.
      docker pull registry.mycompany.com/team/x:v1
      (Login first if not already: docker login registry.mycompany.com)
```

---

## Detailed: build from GitHub URL (skill requirement)

### Public repo

```bash
# Basic — main branch, Dockerfile in root
docker build -t myapp https://github.com/owner/repo.git

# Specific branch
docker build -t myapp https://github.com/owner/repo.git#main
docker build -t myapp https://github.com/owner/repo.git#develop

# Specific tag
docker build -t myapp https://github.com/owner/repo.git#v1.0.0

# Specific commit SHA (best for reproducibility)
docker build -t myapp https://github.com/owner/repo.git#abc123def456

# Dockerfile in a subdirectory
docker build -t myapp https://github.com/owner/repo.git#main:packages/server

# Default branch + subdirectory
docker build -t myapp https://github.com/owner/repo.git#:packages/server

# Different Dockerfile name (still requires URL trick)
docker build -t myapp -f Dockerfile.prod https://github.com/owner/repo.git
# Note: -f is relative to the context, so it picks Dockerfile.prod inside the cloned repo
```

### Private repo

Docker `build <url>` doesn't support SSH or HTTPS auth directly. You have to clone first:

```bash
# Via SSH (key must be on machine + GitHub)
git clone git@github.com:owner/private-repo.git temp-clone
cd temp-clone
docker build -t myapp .
cd ..
rm -rf temp-clone

# Via HTTPS + token
git clone https://${GH_TOKEN}@github.com/owner/private-repo.git temp-clone
cd temp-clone
docker build -t myapp .
cd ..
rm -rf temp-clone

# Or use the helper script: scripts/build_from_github.sh
./scripts/build_from_github.sh owner/private-repo v1.0.0 myapp:v1
```

### Build args + secrets while building from URL

```bash
# Pass build args (becomes ARG inside Dockerfile)
docker build -t myapp \
  --build-arg NODE_VERSION=22 \
  --build-arg COMMIT_SHA=$(git ls-remote https://github.com/owner/repo HEAD | cut -f1) \
  https://github.com/owner/repo.git

# Pass secrets (requires BuildKit)
DOCKER_BUILDKIT=1 docker build -t myapp \
  --secret id=npm_token,src=$HOME/.npmrc \
  https://github.com/owner/repo.git
```

### Caching considerations

`docker build <url>` re-clones every time. To leverage cache:

```bash
# Pre-clone, then build locally (cache hits on package files)
git clone https://github.com/owner/repo.git ~/cache/repo
cd ~/cache/repo && git pull
docker build -t myapp .
```

For CI, use buildx with registry-based cache:
```bash
docker buildx build \
  --cache-from type=registry,ref=ghcr.io/me/myapp-cache \
  --cache-to type=registry,ref=ghcr.io/me/myapp-cache,mode=max \
  -t ghcr.io/me/myapp:latest --push \
  https://github.com/owner/repo.git
```

---

## Local build patterns

### Dev iteration

```bash
# Tag with `:dev` to differentiate from registry pulls
docker build -t myapp:dev .

# Build + run in one shell command (BuildKit)
docker build -t myapp:dev . && docker run --rm -p 3000:3000 myapp:dev

# Watch mode (rebuilds on file change — requires nodemon or similar in container, OR external tool like docker-compose-watch)
docker compose watch    # in compose v2.22+, syncs files on host change
```

### Tagging strategy for local dev

```bash
# By git commit (immutable snapshot)
docker build -t myapp:$(git rev-parse --short HEAD) .

# By branch + commit
docker build -t myapp:$(git branch --show-current)-$(git rev-parse --short HEAD) .

# By semver + commit (for releases)
docker build -t myapp:1.2.3 -t myapp:1.2 -t myapp:1 -t myapp:latest .
```

---

## Private registries (besides Docker Hub)

### GitHub Container Registry (GHCR)

```bash
# Auth — use a Personal Access Token with `read:packages` (and `write:packages` for push)
echo $GH_TOKEN | docker login ghcr.io -u <username> --password-stdin

# Push
docker tag myapp:v1 ghcr.io/myuser/myapp:v1
docker push ghcr.io/myuser/myapp:v1

# Make public/private via GitHub UI (Packages tab)
```

### AWS ECR

```bash
# Auth (use the AWS CLI to generate temporary creds)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

# Create repository (if doesn't exist)
aws ecr create-repository --repository-name myapp

# Push
docker tag myapp:v1 <account>.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/myapp:v1
```

### Google Container Registry / Artifact Registry

```bash
# Auth (uses gcloud SDK)
gcloud auth configure-docker us-central1-docker.pkg.dev

# Push (Artifact Registry format)
docker tag myapp:v1 us-central1-docker.pkg.dev/PROJECT/REPO/myapp:v1
docker push us-central1-docker.pkg.dev/PROJECT/REPO/myapp:v1

# Old GCR format (deprecated but still works)
docker tag myapp:v1 gcr.io/PROJECT/myapp:v1
docker push gcr.io/PROJECT/myapp:v1
```

### Self-hosted Registry (Harbor, Distribution registry, Nexus)

```bash
# Auth
docker login registry.mycompany.com -u <user>

# Push
docker tag myapp:v1 registry.mycompany.com/team/myapp:v1
docker push registry.mycompany.com/team/myapp:v1

# Pull
docker pull registry.mycompany.com/team/myapp:v1
```

---

## When to use which (cheatsheet)

| Scenario | Recommended source |
|---|---|
| "I need Postgres for dev" | Docker Hub: `postgres:17-alpine` |
| "I need Redis for dev" | Docker Hub: `redis:7-alpine` |
| "I'm building my Node app" | Local: `docker build -t mynode .` |
| "I need an OSS tool, no official image, source on GitHub" | Build from GitHub URL |
| "Team published image to GHCR" | `docker pull ghcr.io/team/image:v1` |
| "Internal company app" | Private registry pull |
| "Try out a quick OSS demo" | Docker Hub or GHCR (faster than build) |
| "Reproducible build for CI" | Build from GitHub URL pinned to commit SHA |
| "Multi-platform release" | `docker buildx build --platform linux/amd64,linux/arm64 --push` |
| "Air-gapped environment" | `docker save` from internet-connected, transfer + `docker load` on target |
