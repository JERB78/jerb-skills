# Production Dockerfile for Go apps
# Dockerfile productivo para apps Go
#
# Stack: Go 1.23, scratch/distroless runtime, statically linked binary

# ============================================================================
# Stage 1: builder
# ============================================================================
FROM golang:1.23.4-alpine3.21 AS builder

WORKDIR /src

# Install build deps if needed (git for go mod proxy, ca-certs for HTTPS modules)
# Instalar deps de build si hace falta
RUN apk add --no-cache git ca-certificates

# Download deps first (cache layer)
# Descargar deps primero (cache layer)
COPY go.mod go.sum ./
RUN go mod download

# Build statically linked binary (CGO_ENABLED=0 = no glibc dependency)
# Build binario static (CGO_ENABLED=0 = sin dependencia de glibc)
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s -X main.version=$(git describe --tags --always)" \
    -trimpath \
    -o /app/myapp \
    ./cmd/myapp
# Adjust ./cmd/myapp to your main package path
# Ajustá ./cmd/myapp al path de tu main package

# ============================================================================
# Stage 2: runtime — scratch (smallest possible)
# Etapa 2: runtime — scratch (lo más pequeño posible)
# ============================================================================
FROM scratch AS runtime

# Copy CA certs (needed for HTTPS calls from app)
# Copiar CA certs (necesario para llamadas HTTPS desde la app)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy timezone data if app needs local time
# Copiar timezone data si la app necesita hora local
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy binary
# Copiar binario
COPY --from=builder /app/myapp /myapp

# scratch has no user system — run as numeric UID
# scratch no tiene user system — correr como UID numérico
USER 1000:1000

EXPOSE 8080

# scratch has no shell, so healthcheck must use the binary itself
# scratch no tiene shell, healthcheck debe usar el binario
# Build a `myapp -health` flag into your app for this purpose
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/myapp", "-health"]

ENTRYPOINT ["/myapp"]

LABEL org.opencontainers.image.title="My Go App"
LABEL org.opencontainers.image.licenses="MIT"
