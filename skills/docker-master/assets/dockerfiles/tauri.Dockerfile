# Dockerfile for Tauri build environment (CI/CD)
# Dockerfile para entorno de build Tauri (CI/CD)
#
# NOTE: Tauri produces native desktop apps (.exe/.dmg/.AppImage), NOT server containers.
# This Dockerfile is for CI/CD that builds those native artifacts inside a container.
# El binario resultante NO se ejecuta dentro del container — se extrae y se distribuye.
#
# For runtime/production: native installers from `tauri build` output, not Docker.
# Para runtime/production: instaladores nativos del output de `tauri build`, NO Docker.

# ============================================================================
# Stage 1: build environment with all toolchains
# Etapa 1: entorno de build con todos los toolchains
# ============================================================================
FROM rust:1.84.0-bookworm AS builder

# System deps required by Tauri 2.x for Linux builds
# Deps de sistema requeridas por Tauri 2.x para builds Linux
RUN apt-get update && apt-get install -y --no-install-recommends \
    libwebkit2gtk-4.1-dev \
    libssl-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    libsoup-3.0-dev \
    libjavascriptcoregtk-4.1-dev \
    build-essential \
    curl \
    wget \
    file \
    libxdo-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22 for the frontend build
# Instalar Node.js 22 para el build del frontend
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g pnpm@10

# Install Tauri CLI
# Instalar Tauri CLI
RUN cargo install tauri-cli --version "^2.0" --locked

WORKDIR /build

# Cache JS deps
# Cache de JS deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Cache Rust deps
# Cache de Rust deps
COPY src-tauri/Cargo.toml src-tauri/Cargo.lock src-tauri/
RUN mkdir -p src-tauri/src \
    && echo 'fn main() {}' > src-tauri/src/main.rs \
    && cd src-tauri && cargo build --release \
    && rm -rf src-tauri/src

# Copy source + build
# Copiar source + build
COPY . .

# Build frontend + tauri bundle
# Build frontend + bundle de tauri
RUN pnpm tauri build

# Artifacts at /build/src-tauri/target/release/bundle/
# Artefactos en /build/src-tauri/target/release/bundle/
# (.deb, .rpm, .AppImage for Linux — macOS/Windows builds require their respective hosts)
# (.deb, .rpm, .AppImage para Linux — builds macOS/Windows requieren sus hosts respectivos)

# ============================================================================
# Stage 2: artifacts-only image (used to extract built bundles in CI)
# Etapa 2: imagen solo-artefactos (usada para extraer bundles en CI)
# ============================================================================
FROM scratch AS artifacts

COPY --from=builder /build/src-tauri/target/release/bundle/ /

# Usage in CI:
# Uso en CI:
#   docker build --target artifacts -t myapp-bundles .
#   docker create --name extract myapp-bundles
#   docker cp extract:/. ./dist/
#   docker rm extract

LABEL org.opencontainers.image.title="Tauri build env"
LABEL org.opencontainers.image.description="CI build environment for Tauri 2.x desktop apps"
