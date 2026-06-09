# Production Dockerfile for .NET apps (ASP.NET Core, gRPC services, console)
# Dockerfile productivo para apps .NET (ASP.NET Core, gRPC services, consola)
#
# Stack: .NET 10 SDK builder, ASP.NET runtime, non-root

# ============================================================================
# Stage 1: builder
# ============================================================================
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS builder

WORKDIR /src

# Copy csproj only first for dep cache
# Copiar csproj primero para cache de deps
COPY ["MyApp.csproj", "./"]
# For solutions / Para soluciones:
# COPY ["MySolution.sln", "./"]
# COPY ["src/MyApp/MyApp.csproj", "src/MyApp/"]
# COPY ["src/MyApp.Tests/MyApp.Tests.csproj", "src/MyApp.Tests/"]

RUN dotnet restore "MyApp.csproj"

# Copy source + build + publish
# Copiar source + build + publish
COPY . .
RUN dotnet publish "MyApp.csproj" \
    --configuration Release \
    --no-restore \
    --output /app/publish \
    /p:UseAppHost=false \
    /p:DebugType=None \
    /p:DebugSymbols=false

# ============================================================================
# Stage 2: runtime — ASP.NET runtime only (no SDK)
# Etapa 2: runtime — solo runtime ASP.NET (sin SDK)
# ============================================================================
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runtime

# Install curl for healthcheck
# Instalar curl para healthcheck
RUN apk add --no-cache curl icu-libs \
    && rm -rf /var/cache/apk/*

# Non-root user
# Usuario non-root
RUN addgroup -g 1000 -S app && adduser -u 1000 -S app -G app

WORKDIR /app

COPY --from=builder --chown=app:app /app/publish .

USER app

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_RUNNING_IN_CONTAINER=true \
    DOTNET_USE_POLLING_FILE_WATCHER=false

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "MyApp.dll"]

LABEL org.opencontainers.image.title="My .NET App"
LABEL org.opencontainers.image.licenses="MIT"
