# Images — Operations + Registries Cheatsheet

> Reference for `docker pull`, `build`, `push`, `tag`, registries, multi-platform.
> Read this when working with images (not running containers).

---

## Pull (download from registry)

```bash
# From Docker Hub (default registry, no prefix needed)
docker pull nginx:1.27-alpine
docker pull library/postgres:17.2-alpine        # explicit library/ prefix
docker pull user/myimage:v1.2                    # community image

# From GitHub Container Registry (GHCR)
docker pull ghcr.io/owner/repo:tag
# Auth first: echo $GH_TOKEN | docker login ghcr.io -u <username> --password-stdin

# From AWS ECR
docker pull <aws-account>.dkr.ecr.<region>.amazonaws.com/myimage:tag
# Auth: aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com

# From Google Container Registry / Artifact Registry
docker pull gcr.io/project/image:tag
# or: docker pull <region>-docker.pkg.dev/project/repo/image:tag
# Auth: gcloud auth configure-docker

# From self-hosted registry
docker pull registry.mycompany.com/team/image:tag
# Auth: docker login registry.mycompany.com -u <user>

# By digest (immutable, recommended for production)
docker pull nginx@sha256:abc123def456...
```

## Build (create image from Dockerfile)

```bash
# Local directory build
docker build -t myapp:v1 .
docker build -t myapp:v1 -f Dockerfile.prod .                 # specific Dockerfile
docker build -t myapp:v1 --no-cache .                          # skip layer cache
docker build -t myapp:v1 --pull .                              # pull fresh base image
docker build -t myapp:v1 --build-arg NODE_VERSION=22 .         # pass ARG values
docker build -t myapp:v1 --target builder .                    # stop at specific stage

# From a GitHub repo URL (one of skill's required features)
docker build -t myapp https://github.com/user/repo.git
docker build -t myapp https://github.com/user/repo.git#main           # specific branch
docker build -t myapp https://github.com/user/repo.git#v1.0           # specific tag
docker build -t myapp https://github.com/user/repo.git#main:subdir    # subdir as context
docker build -t myapp https://github.com/user/repo.git#:subdir        # default branch + subdir
docker build -t myapp git@github.com:user/repo.git                    # private via SSH (key must be set up)

# From a tarball URL
docker build -t myapp http://example.com/context.tar.gz

# From stdin (rare but possible)
echo -e "FROM alpine\nRUN echo hello" | docker build -t mytest -

# With BuildKit secrets (avoid baking secrets into image)
DOCKER_BUILDKIT=1 docker build --secret id=npmtoken,src=$HOME/.npmrc -t myapp .
# In Dockerfile: RUN --mount=type=secret,id=npmtoken,target=/root/.npmrc npm install

# With SSH agent (for private git deps in build)
docker build --ssh default -t myapp .
# In Dockerfile: RUN --mount=type=ssh git clone git@github.com:user/private.git

# Multi-platform (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:v1 --push .
docker buildx ls                              # list builders
docker buildx create --use --name multi      # create + use multi-arch builder
```

## Tag (alias an image)

```bash
docker tag myapp:v1 myapp:latest
docker tag myapp:v1 ghcr.io/myuser/myapp:v1
docker tag <image-id> myapp:v1                # tag by ID instead of existing tag
```

## Push (upload to registry)

```bash
# After login + tag with registry prefix
docker push ghcr.io/myuser/myapp:v1
docker push ghcr.io/myuser/myapp:latest

# Push all tags of an image
docker push --all-tags ghcr.io/myuser/myapp
```

## Listing + inspection

```bash
docker images                                          # list all local
docker images --filter "dangling=true"                  # untagged (deletable usually)
docker images --filter "reference=nginx:*"              # by name pattern
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Inspect (full metadata)
docker inspect <image>
docker inspect <image> --format '{{.Config.Cmd}}'
docker inspect <image> --format '{{.RootFS.Layers}}'  # layer hashes

# History (layer-by-layer breakdown)
docker history <image>
docker history --no-trunc <image>                       # full commands

# Manifest (multi-platform support info)
docker manifest inspect nginx:1.27-alpine
```

## Save / load (image as file)

```bash
# Export image to tar (for air-gapped transfer)
docker save myapp:v1 -o myapp-v1.tar
docker save myapp:v1 | gzip > myapp-v1.tar.gz

# Import on the other side
docker load -i myapp-v1.tar
gunzip -c myapp-v1.tar.gz | docker load
```

## Delete (remove local images)

```bash
docker rmi <image>                              # remove by name:tag or ID
docker rmi -f <image>                            # force (used by stopped containers)
docker image prune                               # remove dangling (untagged)
docker image prune -a                            # remove all unused (BIG cleanup)
docker image prune -a --filter "until=24h"      # only images > 24h old
docker rmi $(docker images -qf "dangling=true") # delete dangling via subshell
```

## Layer analysis (find what's bloating an image)

```bash
# `dive` is the gold standard for this — install separately
dive myapp:v1

# Built-in option
docker history --human=true --format "table {{.Size}}\t{{.CreatedBy}}" myapp:v1 | sort -rh
```

## Registry auth

```bash
# Login (credentials stored in ~/.docker/config.json or Windows credential manager)
docker login                                    # Docker Hub (interactive)
docker login ghcr.io                            # GitHub Container Registry
docker login registry.mycompany.com -u <user>

# Token-based (recommended for CI / non-interactive)
echo $TOKEN | docker login ghcr.io -u <user> --password-stdin

# Logout
docker logout
docker logout ghcr.io

# View configured registries
cat ~/.docker/config.json | jq '.auths'
```

## Common patterns

```bash
# Pull, retag, push to private registry
docker pull nginx:1.27-alpine
docker tag nginx:1.27-alpine registry.mycompany.com/nginx:1.27-alpine
docker push registry.mycompany.com/nginx:1.27-alpine

# Build + push in one
docker buildx build --push -t ghcr.io/me/app:v1 .

# Get image SHA digest (for immutable pinning)
docker inspect --format='{{index .RepoDigests 0}}' nginx:1.27-alpine

# Compare two images for diffs
docker image diff <container>                   # changes vs parent image

# Find which container uses an image
docker ps -a --filter "ancestor=<image>"
```

## Best practices for production image building

1. **Pin base image versions exactly** — `node:22.10.0-alpine` not `node:22-alpine` or `node:latest`
2. **Use `-alpine` or distroless** unless you need glibc
3. **Multi-stage builds** for compiled languages (build deps + tools in stage 1, runtime-only in final)
4. **Layer ordering** — put rarely-changing instructions first to maximize cache hits
5. **`.dockerignore`** — exclude `.git`, `node_modules`, `target`, `dist`, secrets, tests
6. **Squash with care** — `--squash` reduces layers but breaks layer caching. Usually NOT worth it.
7. **Label images** — `LABEL org.opencontainers.image.source=https://github.com/me/repo` for traceability
8. **Sign images** with cosign (see security-and-hardening.md)
