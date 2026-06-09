# Production Dockerfile for Ruby apps (Rails, Sinatra, Hanami)
# Dockerfile productivo para apps Ruby (Rails, Sinatra, Hanami)
#
# Stack: Ruby 3.3, slim base, multi-stage with assets precompile

# ============================================================================
# Stage 1: builder
# ============================================================================
FROM ruby:3.3.6-slim-bookworm AS builder

# Install build deps (gcc for native gems, node+yarn for asset compilation)
# Instalar build deps (gcc para native gems, node+yarn para asset compilation)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libyaml-dev \
    git \
    curl \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install gems first for cache
# Instalar gems primero para cache
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.5.23 \
    && bundle config set --local deployment true \
    && bundle config set --local without 'development test' \
    && bundle install --jobs 4 --retry 3

# Install JS deps if Rails with esbuild/rollup/webpacker
# Instalar JS deps si Rails con esbuild/rollup/webpacker
COPY package.json package-lock.json* yarn.lock* ./
RUN [ -f package.json ] && npm ci --omit=dev || true

# Copy app + precompile assets
# Copiar app + precompilar assets
COPY . .

# Rails: precompile assets, skip if not Rails
# Rails: precompilar assets, skip si no es Rails
RUN if [ -f config/application.rb ]; then \
        SECRET_KEY_BASE=dummy bundle exec rails assets:precompile; \
    fi

# ============================================================================
# Stage 2: runtime
# Etapa 2: runtime
# ============================================================================
FROM ruby:3.3.6-slim-bookworm AS runtime

# Runtime deps only (no build tools)
# Solo deps de runtime (sin build tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libyaml-0-2 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root user
# Usuario non-root
RUN groupadd -r app -g 1000 && useradd -r -u 1000 -g app app

WORKDIR /app

# Copy installed gems
# Copiar gems instaladas
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy app code (no .git, no test files thanks to .dockerignore)
# Copiar código (sin .git, sin tests gracias a .dockerignore)
COPY --from=builder --chown=app:app /app .

USER app

ENV RAILS_ENV=production \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT}/up || exit 1
# Rails 7.1+ has /up endpoint built in. For older versions or non-Rails, adjust.

# Rails: bundle exec rails server
# Sinatra/Rack: bundle exec rackup -p 3000 -o 0.0.0.0
# Hanami: bundle exec hanami server
ENTRYPOINT ["bundle", "exec"]
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]

LABEL org.opencontainers.image.title="My Ruby App"
LABEL org.opencontainers.image.licenses="MIT"
