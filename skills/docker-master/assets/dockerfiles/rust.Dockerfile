# Production Dockerfile for Rust apps
# Dockerfile productivo para apps Rust
#
# Stack: Rust 1.84 builder, debian-slim or distroless runtime, multi-stage
# Strategy: build deps cached separately from app source for fast iteration

# ============================================================================
# Stage 1: chef-style dep caching
# Etapa 1: caché de deps al estilo cargo-chef
# ============================================================================
FROM rust:1.84.0-slim-bookworm AS planner

WORKDIR /app

# Install cargo-chef for granular dep caching
# Instalar cargo-chef para caché granular de deps
RUN cargo install cargo-chef --locked

COPY . .
RUN cargo chef prepare --recipe-path recipe.json

# ============================================================================
# Stage 2: builder — uses dep recipe for cache
# Etapa 2: builder — usa el recipe para caché de deps
# ============================================================================
FROM rust:1.84.0-slim-bookworm AS builder

WORKDIR /app

RUN cargo install cargo-chef --locked

# Build deps (cached unless Cargo.toml/Cargo.lock change)
# Build de deps (cacheado a menos que Cargo.toml/Cargo.lock cambien)
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --recipe-path recipe.json

# Build the actual binary
# Build del binario real
COPY . .
RUN cargo build --release --bin myapp
# Replace `myapp` with your actual binary name from Cargo.toml [[bin]] or [package]
# Reemplazá `myapp` con el nombre real de tu binario

# ============================================================================
# Stage 3: runtime — distroless (smallest, most secure)
# Etapa 3: runtime — distroless (mínima, más segura)
# ============================================================================
FROM gcr.io/distroless/cc-debian12:nonroot AS runtime

# Alternative runtime options:
# - debian:12-slim     (~30 MB, has shell — easier debug)
# - alpine:3.21        (musl, smaller but rust binaries need rebuilds for musl)
# - scratch            (zero base — only works with statically-linked binaries)

WORKDIR /app

# Copy binary from builder
# Copiar binario del builder
COPY --from=builder /app/target/release/myapp /app/myapp

# distroless/cc-debian12:nonroot already runs as user nonroot (uid 65532)
# distroless/cc-debian12:nonroot ya corre como user nonroot (uid 65532)

EXPOSE 8080

# Healthcheck: distroless has no curl/wget, so use the binary itself
# Healthcheck: distroless no tiene curl/wget, usar el binario propio
# Best practice: build a `myapp healthcheck` subcommand into your CLI
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD ["/app/myapp", "healthcheck"]

ENTRYPOINT ["/app/myapp"]

LABEL org.opencontainers.image.title="My Rust App"
LABEL org.opencontainers.image.licenses="MIT"
