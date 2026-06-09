# Compose — Multi-Service Patterns

> Reference for Docker Compose v2 (`docker compose ...`, no hyphen). Covers `.env`,
> profiles, depends_on with conditions, secrets, override files, healthchecks.

---

## Basics

```bash
docker compose up                # build (if needed) + start, attached
docker compose up -d             # detached
docker compose up --build        # force rebuild before start
docker compose down              # stop + remove containers + networks (volumes preserved)
docker compose down -v           # also delete volumes (DATA LOSS — confirm with user)
docker compose down --rmi all    # also remove images
docker compose ps                # list services
docker compose logs -f web       # follow logs of one service
docker compose exec web sh       # shell in service "web"
docker compose restart web       # restart one service
docker compose pull              # pull latest images for all services
docker compose config            # validate + render final compose (substitutes vars)
docker compose top               # processes inside all services
```

## File anatomy (minimal example)

```yaml
# docker-compose.yml
services:
  web:
    image: nginx:1.27-alpine     # OR build: ./web
    ports:
      - "8080:80"
    environment:
      - API_URL=http://api:3000
    volumes:
      - ./html:/usr/share/nginx/html:ro
    depends_on:
      - api
    restart: unless-stopped

  api:
    build:
      context: ./api
      dockerfile: Dockerfile
      args:
        NODE_VERSION: 22
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD}@db:5432/myapp
      NODE_ENV: production
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: myapp
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped

volumes:
  postgres-data:                  # named volume, managed by docker
```

## Environment variables (.env)

```yaml
# Compose auto-loads .env from the same dir as compose.yml
services:
  app:
    environment:
      - DB_HOST=${DB_HOST}        # substituted from .env at compose-up
      - DB_PORT=${DB_PORT:-5432}  # default value if not set
```

```bash
# .env
DB_HOST=postgres.example.com
DB_PASSWORD=supersecret
```

```bash
# Use a different env file
docker compose --env-file=./prod.env up -d

# Multiple env files
docker compose --env-file=./base.env --env-file=./prod.env up -d
```

**Gotcha**: `${VAR}` substitution happens at compose-up time (rendering YAML), NOT at container runtime. If you change `.env`, you must `compose down && compose up` for changes to take effect.

## depends_on with conditions (wait for readiness)

```yaml
services:
  api:
    depends_on:
      db:
        condition: service_healthy    # wait for db's healthcheck to pass
      redis:
        condition: service_started     # only wait for redis to start
      migration:
        condition: service_completed_successfully  # wait for one-shot job to exit 0
```

Available conditions:
- `service_started` (default) — container starts, no readiness check
- `service_healthy` — wait for `healthcheck` to pass
- `service_completed_successfully` — for one-shot init jobs (must exit 0)

Without `condition:`, depends_on only ensures start order, NOT readiness. This is the #1 source of "race condition" bugs in compose stacks.

## Profiles (optional services)

```yaml
services:
  app:
    image: myapp
  # Only starts if --profile dev is passed
  mailhog:
    image: mailhog/mailhog
    profiles: ["dev"]
  # Only starts if --profile monitoring is passed
  prometheus:
    image: prom/prometheus
    profiles: ["monitoring"]
```

```bash
docker compose up                                # only `app`
docker compose --profile dev up                  # `app` + `mailhog`
docker compose --profile dev --profile monitoring up   # all three
```

## Override files (dev vs prod)

Compose merges files automatically. Default: `docker-compose.yml` + `docker-compose.override.yml`.

```yaml
# docker-compose.yml (shared)
services:
  app:
    image: myapp
    ports:
      - "3000:3000"

# docker-compose.override.yml (dev defaults, auto-loaded)
services:
  app:
    build: .                       # build from local source in dev
    volumes:
      - ./src:/app/src             # mount source for hot reload
    environment:
      NODE_ENV: development

# docker-compose.prod.yml (explicit, opt-in)
services:
  app:
    image: ghcr.io/me/myapp:v1     # use prebuilt image in prod
    environment:
      NODE_ENV: production
    restart: always
```

```bash
docker compose up                              # uses default + override (dev)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up   # prod
```

## Secrets (Compose v2)

```yaml
services:
  app:
    image: myapp
    secrets:
      - db_password
      - api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt        # from file (gitignored)
  api_key:
    environment: API_KEY                   # from env var (read by compose)
```

Secrets are mounted at `/run/secrets/<name>` inside the container. Read them via:
```javascript
const dbPassword = fs.readFileSync('/run/secrets/db_password', 'utf8').trim();
```

NOT via env vars — that's the whole point (env vars leak in `docker inspect`).

## Healthcheck patterns by stack

```yaml
# Postgres
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB"]
  interval: 10s

# MySQL
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval: 10s

# Redis
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s

# HTTP API (any language)
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
  interval: 30s
  start_period: 30s     # grace period for slow-startup apps

# wget alternative (alpine has no curl by default)
healthcheck:
  test: ["CMD-SHELL", "wget -qO- http://localhost:3000/health > /dev/null || exit 1"]
```

## Network customization

```yaml
services:
  web:
    networks:
      - frontend
  api:
    networks:
      - frontend
      - backend
  db:
    networks:
      - backend         # not reachable from web

networks:
  frontend:
  backend:
    internal: true      # no external internet access (security)
```

## Restart policies

- `no` (default) — never auto-restart
- `on-failure` — restart only if exit code != 0
- `always` — always restart (even after manual stop, on docker daemon start)
- `unless-stopped` — restart unless explicitly stopped (recommended for prod)

```yaml
services:
  api:
    restart: unless-stopped
```

## Resource limits in compose

```yaml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

Note: `deploy.resources` works in Compose v2 standalone mode AND in Swarm.

## Logging

```yaml
services:
  api:
    logging:
      driver: json-file              # default
      options:
        max-size: "10m"
        max-file: "3"                # rotate, max 30MB total per container
```

Other drivers: `journald`, `syslog`, `gelf`, `fluentd`, `awslogs`, `gcplogs`, `splunk`. For prod, ship logs to a log aggregator.

## Common pitfalls

1. **`depends_on` without `condition`** — only waits for container START, not readiness. Use `condition: service_healthy`.
2. **`environment` vs `env_file`** — `environment` is inline, wins on conflict. `env_file` reads from file but doesn't override `environment`.
3. **`${VAR}` substitution timing** — at compose-up, not runtime. Restart compose after .env changes.
4. **Volume name conflicts** — `docker compose down -v` only deletes volumes defined in THIS compose file. Volumes from other projects survive.
5. **Network name conflicts** — compose prefixes networks with project name (default = dir name). `docker compose --project-name myproj up` to override.
6. **`compose ps` vs `docker ps`** — `compose ps` only shows services from this compose file. `docker ps` shows everything.
7. **`build:` cache invalidation** — changes anywhere in build context invalidate. Use `.dockerignore` to limit context.
8. **Privileged ports (<1024)** — `ports: "80:80"` requires root on Linux. Use `8080:80` or run rootless.
9. **`tty: true` for interactive STDIN** — without it, `docker compose exec` may behave weird with shells.
10. **Bind mount overrides image content** — if you mount `./` over `/app` and the image already has `/app/node_modules`, the mount hides it. Use a named volume for `node_modules`.
