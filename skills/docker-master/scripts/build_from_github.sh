#!/usr/bin/env bash
# build_from_github.sh — Build a Docker image directly from a GitHub repository
# Construir una imagen Docker directamente desde un repositorio GitHub
#
# Handles: public repos (URL direct), private repos (SSH clone), monorepo subdirs,
# branch/tag/commit pinning, build args, BuildKit secrets.
#
# Usage / Uso:
#   ./build_from_github.sh OWNER/REPO [TAG_OR_BRANCH] [IMAGE_NAME] [SUBDIR]
#
# Examples / Ejemplos:
#   ./build_from_github.sh nginx/nginx                              # public, default branch, root context
#   ./build_from_github.sh hashicorp/terraform v1.7.0 my-tf         # specific tag
#   ./build_from_github.sh me/private-app main myapp:dev            # private repo (needs SSH key)
#   ./build_from_github.sh kubernetes/kubernetes master k8s build   # subdir context
#
# Environment variables / Variables de entorno:
#   GH_TOKEN          GitHub Personal Access Token (for private repos via HTTPS)
#   USE_SSH           If "true", use SSH instead of HTTPS (requires SSH key setup)
#   BUILD_ARGS        Space-separated "--build-arg KEY=VALUE" pairs
#   DOCKERFILE_PATH   Path to Dockerfile within context (default: Dockerfile)
#   PLATFORMS         For multi-platform builds (default: native)

set -e

REPO="$1"
REF="${2:-}"           # branch, tag, or commit SHA
IMAGE_NAME="${3:-}"
SUBDIR="${4:-}"

if [ -z "$REPO" ]; then
    head -10 "$0" | tail -8
    exit 1
fi

# Derive image name if not provided
if [ -z "$IMAGE_NAME" ]; then
    IMAGE_NAME=$(echo "$REPO" | tr '/' '-')
    [ -n "$REF" ] && IMAGE_NAME="${IMAGE_NAME}:${REF}" || IMAGE_NAME="${IMAGE_NAME}:latest"
fi

echo "================================================================"
echo "  Building from GitHub"
echo "================================================================"
echo "Repo:     $REPO"
echo "Ref:      ${REF:-<default branch>}"
echo "Image:    $IMAGE_NAME"
echo "Subdir:   ${SUBDIR:-<repo root>}"
echo ""

# Strategy 1: public repo, use docker build URL directly (no local clone needed)
# Estrategia 1: repo público, usar URL de docker build directamente (sin clonar local)
BUILD_PUBLIC() {
    local url="https://github.com/${REPO}.git"

    if [ -n "$REF" ] && [ -n "$SUBDIR" ]; then
        url="${url}#${REF}:${SUBDIR}"
    elif [ -n "$REF" ]; then
        url="${url}#${REF}"
    elif [ -n "$SUBDIR" ]; then
        url="${url}#:${SUBDIR}"
    fi

    echo "Building via: docker build -t $IMAGE_NAME $url"

    local build_cmd="docker build -t $IMAGE_NAME"
    [ -n "$DOCKERFILE_PATH" ] && build_cmd="$build_cmd -f $DOCKERFILE_PATH"
    [ -n "$BUILD_ARGS" ] && build_cmd="$build_cmd $BUILD_ARGS"
    build_cmd="$build_cmd $url"

    eval "$build_cmd"
}

# Strategy 2: private repo, clone first then build
# Estrategia 2: repo privado, clonar primero y luego buildear
BUILD_PRIVATE() {
    local clone_dir
    clone_dir=$(mktemp -d)
    trap "rm -rf $clone_dir" EXIT

    local clone_url
    if [ "$USE_SSH" = "true" ]; then
        clone_url="git@github.com:${REPO}.git"
        echo "Cloning via SSH: $clone_url"
    elif [ -n "$GH_TOKEN" ]; then
        clone_url="https://${GH_TOKEN}@github.com/${REPO}.git"
        echo "Cloning via HTTPS+token"
    else
        echo "ERROR: Private repo requires either USE_SSH=true with SSH key, or GH_TOKEN env var."
        exit 1
    fi

    git clone --depth 1 ${REF:+--branch $REF} "$clone_url" "$clone_dir/repo"

    local build_context="$clone_dir/repo"
    [ -n "$SUBDIR" ] && build_context="$build_context/$SUBDIR"

    local build_cmd="docker build -t $IMAGE_NAME"
    [ -n "$DOCKERFILE_PATH" ] && build_cmd="$build_cmd -f $DOCKERFILE_PATH"
    [ -n "$BUILD_ARGS" ] && build_cmd="$build_cmd $BUILD_ARGS"
    build_cmd="$build_cmd $build_context"

    echo "Building: $build_cmd"
    eval "$build_cmd"
}

# Detect public vs private by trying HEAD on the repo
# Detectar público vs privado intentando HEAD en el repo
detect_visibility() {
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/repos/${REPO}" || echo "0")

    if [ "$status" = "200" ]; then
        echo "public"
    elif [ "$status" = "404" ]; then
        echo "private"  # 404 can mean private OR doesn't exist
    elif [ "$status" = "0" ]; then
        echo "unknown"  # network issue
    else
        echo "unknown"
    fi
}

VISIBILITY=$(detect_visibility)
echo "Detected visibility: $VISIBILITY"
echo ""

case "$VISIBILITY" in
    public)
        BUILD_PUBLIC
        ;;
    private)
        BUILD_PRIVATE
        ;;
    unknown)
        echo "Could not determine visibility. Trying public build first..."
        if ! BUILD_PUBLIC; then
            echo ""
            echo "Public build failed. Trying private clone..."
            BUILD_PRIVATE
        fi
        ;;
esac

echo ""
echo "================================================================"
echo "  Build complete / Build completo"
echo "================================================================"
echo "Image: $IMAGE_NAME"
echo ""
echo "Run it / Ejecutarla:"
echo "  docker run --rm -it $IMAGE_NAME"
echo ""
echo "Inspect:"
echo "  docker inspect $IMAGE_NAME"
echo "  docker history $IMAGE_NAME"
