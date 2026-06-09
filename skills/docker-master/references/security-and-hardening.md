# Security and Hardening

> Image scanning, secrets management, image signing, SBOM. Use these for any image
> heading to production or distributed externally.

---

## Scanning vulnerabilities

### Option A — Trivy (OSS, preferred)

```bash
# Install on Windows: winget install AquaSecurity.Trivy
# Or via scoop: scoop install trivy

# Scan a local image
trivy image myapp:v1

# Scan and only show HIGH+CRITICAL
trivy image --severity HIGH,CRITICAL myapp:v1

# Skip unfixed vulnerabilities (no patch available)
trivy image --ignore-unfixed myapp:v1

# Output formats
trivy image --format json --output report.json myapp:v1
trivy image --format sarif --output report.sarif myapp:v1   # for GitHub Code Scanning
trivy image --format template --template "@contrib/html.tpl" -o report.html myapp:v1

# Scan a Dockerfile (config issues, not vulns)
trivy config Dockerfile

# Scan a Kubernetes manifest
trivy config k8s.yaml

# Scan dependencies in a directory (SBOM-style)
trivy fs .  # detects package.json, requirements.txt, go.mod, Cargo.lock, etc.
```

### Option B — Docker Scout (built-in to Docker Desktop)

```bash
# Quick CVE summary
docker scout cves myapp:v1

# Compare image versions
docker scout compare --to myapp:v0 myapp:v1

# Get recommendations
docker scout recommendations myapp:v1

# What policies are violated (org-level)
docker scout policy myapp:v1
```

Docker Scout integrates with Docker Hub + GitHub. Free tier: 3 active repos.

### Option C — Snyk (commercial, free for OSS)

```bash
snyk container test myapp:v1
snyk container test myapp:v1 --severity-threshold=high
snyk container monitor myapp:v1   # continuous monitoring in Snyk UI
```

---

## How to read severity

| Severity | Typical CVSS score | Action |
|---|---|---|
| **CRITICAL** | 9.0-10.0 | Fix immediately. Don't ship. |
| **HIGH** | 7.0-8.9 | Fix before next release. |
| **MEDIUM** | 4.0-6.9 | Track + plan. Fix if exploitable in your context. |
| **LOW** | 0.1-3.9 | Note but don't necessarily block ship. |
| **UNKNOWN** | n/a | Investigate; CVE not yet rated. |

Context matters. A CRITICAL in a library you don't use the vulnerable function of is lower real risk. But you can't know without auditing.

---

## Common remediations (in priority order)

### 1. Upgrade base image

```dockerfile
# Old (has multiple CRITICAL CVEs)
FROM node:18-alpine3.15

# New (fewer CVEs, supported until 2027)
FROM node:22-alpine3.21
```

Most CVEs come from the base image's OS packages. Newest LTS of base = fewest CVEs.

### 2. Use distroless or scratch

```dockerfile
FROM gcr.io/distroless/nodejs22-debian12
# vs
FROM node:22-alpine
```

Distroless: no shell, no apt/apk, no extra binaries. CVE count drops 80-90%.

### 3. Multi-stage to leave build tools out

If your final image has `gcc`, `make`, `git`, `python-dev`, you've leaked build deps. Multi-stage build separates build tools from runtime.

### 4. Pin OS packages

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl=7.88.* \
    && rm -rf /var/lib/apt/lists/*
```

Avoids surprise upgrades to vulnerable versions. Update intentionally, not accidentally.

### 5. Patch in-place when no upgrade available

```dockerfile
RUN apt-get update && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
```

This grabs latest security patches for everything in the base layer.

---

## Secrets management

### Don't do this

```dockerfile
# WRONG — secret in image, visible to anyone who pulls
ENV API_KEY=sk-1234567890abcdef

# WRONG — secret in build args, visible in `docker history`
ARG DATABASE_PASSWORD
ENV DB_PASS=${DATABASE_PASSWORD}

# WRONG — copying .env file into image
COPY .env /app/.env
```

### Do this (build-time secrets)

```bash
# Use BuildKit's --secret flag
DOCKER_BUILDKIT=1 docker build \
  --secret id=npm_token,src=$HOME/.npmrc \
  --secret id=ssh_key,src=$HOME/.ssh/id_rsa \
  -t myapp .
```

```dockerfile
# In Dockerfile (only available during this RUN, not in image)
RUN --mount=type=secret,id=npm_token,target=/root/.npmrc \
    npm ci

RUN --mount=type=secret,id=ssh_key \
    --mount=type=ssh \
    git clone git@github.com:org/private-dep.git
```

### Do this (runtime secrets)

```bash
# Via env vars (visible in `docker inspect`, slightly less bad)
docker run -e API_KEY=$API_KEY myapp
docker run --env-file=prod.env myapp

# Via Compose secrets (writes to /run/secrets/<name> in container)
docker compose up   # reads from secrets: section in compose.yml

# Via Docker Swarm secrets (rotatable, encrypted at rest)
echo "supersecret" | docker secret create db_pass -
docker service create --secret db_pass myapp

# Via external secret manager (best for prod)
# - AWS Secrets Manager via task role
# - HashiCorp Vault via sidecar / agent
# - Doppler / 1Password via runtime injection
```

---

## Image signing with cosign

Signing proves an image came from a trusted source and hasn't been tampered with.

```bash
# Install cosign
# winget install Sigstore.Cosign

# Generate keypair (one-time, keep private key safe)
cosign generate-key-pair

# Sign an image
cosign sign --key cosign.key ghcr.io/me/myapp:v1
# Prompts for password, pushes signature to registry

# Verify a signature
cosign verify --key cosign.pub ghcr.io/me/myapp:v1

# Keyless signing (uses OIDC, no key management — needs Fulcio + Rekor)
cosign sign ghcr.io/me/myapp:v1  # opens browser for OAuth
```

For GitHub Actions, cosign integrates with OIDC for keyless signing:
```yaml
- uses: sigstore/cosign-installer@v3
- run: cosign sign --yes ghcr.io/${{ github.repository }}@${{ env.IMAGE_DIGEST }}
```

---

## SBOM (Software Bill of Materials)

Lists every package + version inside an image. Required by many compliance frameworks now.

```bash
# Generate SBOM with syft (companion to Trivy)
syft myapp:v1                              # human-readable
syft myapp:v1 -o spdx-json > sbom.json     # SPDX JSON format
syft myapp:v1 -o cyclonedx-json            # CycloneDX format

# Generate during build (BuildKit feature)
docker buildx build --sbom=true -t myapp:v1 --push .

# Attach SBOM to image as attestation (in registry)
docker buildx build --sbom=true --attest type=sbom -t myapp:v1 --push .

# Read attached SBOM
docker buildx imagetools inspect myapp:v1 --format '{{ json .SBOM }}'
```

---

## Hardening checklist (production image)

- [ ] Base image pinned to specific version (e.g. `node:22.10.0-alpine3.21`, not `:latest`)
- [ ] Base image is `-alpine`, `-slim`, or distroless (not full distro)
- [ ] Multi-stage build separates compile tools from runtime
- [ ] `USER` directive sets non-root (e.g., `USER 1000:1000` or built-in user)
- [ ] `.dockerignore` excludes secrets, `.git`, dev files
- [ ] No `RUN curl <untrusted-url> | sh` patterns (use signed packages)
- [ ] No `ENV API_KEY=...` or other secrets baked in
- [ ] `HEALTHCHECK` defined
- [ ] OS packages patched (`apt-get upgrade -y` in RUN)
- [ ] `LABEL org.opencontainers.image.*` fields populated
- [ ] Image scanned with Trivy/Scout — 0 CRITICAL, 0 HIGH
- [ ] Image signed with cosign (if distributed externally)
- [ ] SBOM attached or stored separately
- [ ] Runtime hardening: `--read-only` filesystem where possible, `--cap-drop=ALL` minimal capabilities

---

## Runtime hardening

```bash
# Read-only filesystem (app can't modify itself)
docker run --read-only \
           --tmpfs /tmp:size=100M \
           --tmpfs /var/run:size=10M \
           myapp

# Drop ALL capabilities, add back only what's needed
docker run --cap-drop=ALL \
           --cap-add=NET_BIND_SERVICE \
           myapp

# No new privileges (prevent suid binaries from escalating)
docker run --security-opt=no-new-privileges:true myapp

# Limit syscalls (seccomp profile)
docker run --security-opt=seccomp=/path/to/profile.json myapp

# AppArmor (Linux only)
docker run --security-opt=apparmor=docker-default myapp

# Full hardening combined
docker run \
  --read-only \
  --tmpfs /tmp:size=100M \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt=no-new-privileges:true \
  -u 1000:1000 \
  --pids-limit=200 \
  --memory=512m --cpus=0.5 \
  myapp
```

---

## Continuous scanning in CI

```yaml
# .github/workflows/security.yml — scan on every PR
- name: Run Trivy scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'    # fail PR on findings

- name: Upload to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```
