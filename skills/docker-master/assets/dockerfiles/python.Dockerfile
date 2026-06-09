# Production Dockerfile for Python apps (FastAPI, Django, Flask, generic)
# Dockerfile productivo para apps Python (FastAPI, Django, Flask, genérico)
#
# Stack: Python 3.13, slim base, multi-stage, non-root user
# For ML/data work that needs glibc + native libs, swap -slim for full debian base

# ============================================================================
# Stage 1: builder — install deps with build tools
# Etapa 1: builder — instalar deps con build tools
# ============================================================================
FROM python:3.13.1-slim-bookworm AS builder

WORKDIR /app

# Install build-time system deps (gcc for native extensions)
# Instalar deps de sistema de build (gcc para extensiones nativas)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps into a venv (cleaner copy to runtime stage)
# Instalar deps Python en venv (más limpio al copiar al runtime stage)
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy ONLY requirements first for layer cache
# Copiar SOLO requirements primero para cache de capas
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ============================================================================
# Stage 2: runtime — minimal, no build tools
# Etapa 2: runtime — mínima, sin build tools
# ============================================================================
FROM python:3.13.1-slim-bookworm AS runtime

# Runtime system deps only (curl for healthcheck, ca-certs for TLS)
# Solo deps de sistema de runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
# Crear usuario non-root
RUN groupadd -r app -g 1000 && useradd -r -u 1000 -g app app

WORKDIR /app

# Copy venv from builder
# Copiar venv del builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy app source
# Copiar código de la app
COPY --chown=app:app . .

USER app

# Python runtime env vars
# Variables de entorno de runtime Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Adjust to your app's entrypoint:
# Ajustá al entrypoint de tu app:
#   FastAPI:  CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
#   Django:   CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000"]
#   Flask:    CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000"]
#   Script:   CMD ["python", "main.py"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

LABEL org.opencontainers.image.title="My Python App"
LABEL org.opencontainers.image.licenses="MIT"
