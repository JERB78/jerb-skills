# Production Dockerfile for Node.js apps
# Dockerfile productivo para apps Node.js
#
# Stack: Node 22 LTS, Alpine base, multi-stage, non-root user, healthcheck
# Compatible with: Express, Fastify, Hono, Next.js (standalone), Nest.js, etc.

# ============================================================================
# Stage 1: dependencies
# Etapa 1: dependencias
# ============================================================================
FROM node:22.10.0-alpine3.21 AS deps

WORKDIR /app

# Copy ONLY manifest first — leverage Docker layer cache
# Copiar SOLO el manifest primero — aprovechar cache de capas Docker
COPY package.json package-lock.json* ./

# `npm ci` is faster + deterministic vs `npm install`
# `npm ci` es más rápido + determinístico vs `npm install`
RUN npm ci --omit=dev --no-audit --no-fund

# ============================================================================
# Stage 2: builder (if you have TypeScript or build step)
# Etapa 2: builder (si tenés TypeScript o paso de build)
# ============================================================================
FROM node:22.10.0-alpine3.21 AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund

COPY . .

# Adjust to your build command (tsc, next build, vite build, etc.)
# Ajustá a tu comando de build
RUN npm run build

# ============================================================================
# Stage 3: runtime — final, minimal image
# Etapa 3: runtime — imagen final, mínima
# ============================================================================
FROM node:22.10.0-alpine3.21 AS runtime

# Install only essential runtime deps
# Instalar solo deps esenciales de runtime
RUN apk add --no-cache \
    tini \
    curl \
    && rm -rf /var/cache/apk/*

WORKDIR /app

# Copy production deps from deps stage (no devDependencies)
# Copiar deps de prod desde deps stage (sin devDependencies)
COPY --from=deps --chown=node:node /app/node_modules ./node_modules

# Copy built artifacts from builder stage
# Copiar artefactos del builder stage
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/package.json ./

# Use built-in non-root `node` user
# Usar el usuario `node` non-root que viene en la imagen
USER node

# Environment defaults
# Defaults de entorno
ENV NODE_ENV=production \
    NPM_CONFIG_LOGLEVEL=warn \
    PORT=3000

EXPOSE 3000

# Healthcheck — adjust path to your health endpoint
# Healthcheck — ajustar path a tu endpoint de salud
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# tini handles PID 1 + signal forwarding properly
# tini maneja PID 1 + signal forwarding correctamente
ENTRYPOINT ["/sbin/tini", "--"]

# Adjust to your start command
# Ajustá a tu comando de start
CMD ["node", "dist/server.js"]

# Labels for traceability
# Labels para trazabilidad
LABEL org.opencontainers.image.title="My Node App"
LABEL org.opencontainers.image.description="Node.js application"
LABEL org.opencontainers.image.source="https://github.com/<user>/<repo>"
LABEL org.opencontainers.image.licenses="MIT"
