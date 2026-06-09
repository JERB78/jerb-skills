# Production Dockerfile for Java apps (Spring Boot, Quarkus, plain JAR)
# Dockerfile productivo para apps Java (Spring Boot, Quarkus, JAR puro)
#
# Stack: Eclipse Temurin 21 LTS, JLink for slim runtime, layered jar

# ============================================================================
# Stage 1: builder (with Maven or Gradle)
# Etapa 1: builder (con Maven o Gradle)
# ============================================================================
# For Maven: use eclipse-temurin:21-jdk-alpine + COPY pom + mvn dependency:go-offline
# For Gradle: use eclipse-temurin:21-jdk-alpine + COPY build.gradle + gradle build --refresh-dependencies
# Para Maven: usar eclipse-temurin:21-jdk-alpine + COPY pom + mvn dependency:go-offline
# Para Gradle: usar eclipse-temurin:21-jdk-alpine + COPY build.gradle + gradle build --refresh-dependencies

FROM maven:3.9.9-eclipse-temurin-21-alpine AS builder

WORKDIR /build

# Maven: dep cache layer
# Maven: capa de cache de deps
COPY pom.xml ./
RUN mvn dependency:go-offline -B

# Copy source + build
# Copiar source + buildear
COPY src ./src
RUN mvn package -DskipTests -B

# Extract layered jar (Spring Boot 2.3+, Quarkus, etc.)
# Esto permite layer caching más eficiente — deps no cambian → cached separate de tu code
RUN mkdir -p /build/extracted \
    && cd /build/extracted \
    && java -Djarmode=layertools -jar /build/target/*.jar extract

# ============================================================================
# Stage 2: runtime — JRE only (no JDK)
# Etapa 2: runtime — solo JRE (sin JDK)
# ============================================================================
FROM eclipse-temurin:21-jre-alpine AS runtime

# curl for healthcheck
# curl para healthcheck
RUN apk add --no-cache curl \
    && rm -rf /var/cache/apk/*

# Non-root user
# Usuario non-root
RUN addgroup -g 1000 -S app && adduser -u 1000 -S app -G app

WORKDIR /app

# Copy layered jar in order of change frequency:
# Copiar layered jar en orden de frecuencia de cambio:
COPY --from=builder --chown=app:app /build/extracted/dependencies/ ./
COPY --from=builder --chown=app:app /build/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=app:app /build/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=app:app /build/extracted/application/ ./

USER app

# JVM container-aware tuning
# JVM tuning consciente del contenedor
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1
# Adjust path: Spring Boot Actuator = /actuator/health, Quarkus = /q/health
# Ajustar path: Spring Boot Actuator = /actuator/health, Quarkus = /q/health

ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
# For Quarkus: ENTRYPOINT ["java", "-jar", "quarkus-run.jar"]
# For plain JAR: ENTRYPOINT ["java", "-jar", "/app/app.jar"]

LABEL org.opencontainers.image.title="My Java App"
LABEL org.opencontainers.image.licenses="MIT"
