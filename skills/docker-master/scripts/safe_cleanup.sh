#!/usr/bin/env bash
# safe_cleanup.sh — Docker cleanup with confirmations + space estimates (bash version)
# Limpieza de Docker con confirmaciones + estimación de espacio (versión bash)
#
# Usage / Uso:
#   ./safe_cleanup.sh                       # interactive, default safe (no volumes)
#   ./safe_cleanup.sh --include-volumes     # also prune unused volumes (DESTRUCTIVE)
#   ./safe_cleanup.sh --dry-run             # show what would be deleted, don't delete
#   ./safe_cleanup.sh --all --force         # nuke everything (with confirmation)

set -e

INCLUDE_VOLUMES=false
DRY_RUN=false
ALL=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --include-volumes) INCLUDE_VOLUMES=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --all) ALL=true; shift ;;
        --force) FORCE=true; shift ;;
        -h|--help)
            head -10 "$0" | tail -8
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- ANSI colors ---
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

write_header() {
    echo ""
    echo -e "${CYAN}======================================================================${RESET}"
    echo -e "${CYAN}  $1${RESET}"
    echo -e "${CYAN}======================================================================${RESET}"
}

confirm_action() {
    if $FORCE; then return 0; fi
    local msg="$1"
    read -r -p "$msg [y/N] " response
    [[ "$response" =~ ^(y|yes|s|si)$ ]]
}

# --- Step 1: Show current disk usage ---
write_header "Current Docker disk usage / Uso actual de disco"
docker system df

# --- Step 2: Detailed breakdown ---
write_header "Detailed breakdown / Desglose detallado"
docker system df -v 2>&1 | head -50

# --- Step 3: Estimate space ---
write_header "Estimating reclaimable space / Estimando espacio recuperable"

echo -e "${YELLOW}Calculating dangling images...${RESET}"
DANGLING_COUNT=$(docker images -qf "dangling=true" | wc -l)
echo "  Dangling images: $DANGLING_COUNT"

echo -e "${YELLOW}Calculating stopped containers...${RESET}"
STOPPED_COUNT=$(docker ps -aqf "status=exited" | wc -l)
echo "  Stopped containers: $STOPPED_COUNT"

echo -e "${YELLOW}Calculating custom networks...${RESET}"
NETWORKS_COUNT=$(docker network ls --filter "type=custom" -q | wc -l)
echo "  Custom networks (some may be in use): $NETWORKS_COUNT"

# --- Step 4: Volume warning ---
if $INCLUDE_VOLUMES || $ALL; then
    write_header "VOLUME WARNING / ADVERTENCIA DE VOLÚMENES"
    echo -e "${RED}Volumes often contain irreplaceable data (databases, uploads, configs).${RESET}"
    echo -e "${RED}Los volúmenes suelen contener data irreemplazable (DBs, uploads, configs).${RESET}"
    echo ""
    docker volume ls
    echo ""
    if ! confirm_action "Are you SURE you want to prune unused volumes? / ¿Estás SEGURO?"; then
        echo -e "${YELLOW}Skipping volume prune. / Saltando prune de volúmenes.${RESET}"
        INCLUDE_VOLUMES=false
    fi
fi

# --- Step 5: Dry run mode ---
if $DRY_RUN; then
    write_header "DRY RUN MODE — nothing will be deleted / nada se borrará"
    echo "Would run:"
    echo "  docker container prune -f"
    if $ALL; then
        echo "  docker image prune -a -f"
    else
        echo "  docker image prune -f"
    fi
    echo "  docker network prune -f"
    echo "  docker builder prune -f"
    $INCLUDE_VOLUMES && echo "  docker volume prune -f"
    echo ""
    echo -e "${YELLOW}Run again without --dry-run to actually delete.${RESET}"
    exit 0
fi

# --- Step 6: Confirm ---
write_header "Ready to clean up / Listo para limpiar"

echo "Will delete: / Se borrará:"
echo "  - Stopped containers ($STOPPED_COUNT)"
echo "  - Dangling images ($DANGLING_COUNT)"
$ALL && echo "  - ALL unused images (not just dangling)"
echo "  - Unused networks"
echo "  - BuildKit cache"
$INCLUDE_VOLUMES && echo -e "  ${RED}- UNUSED VOLUMES (DATA LOSS RISK)${RESET}"

if ! confirm_action "Proceed with cleanup? / ¿Proceder con limpieza?"; then
    echo -e "${YELLOW}Cancelled by user. / Cancelado por el usuario.${RESET}"
    exit 0
fi

# --- Step 7: Execute ---
write_header "Executing cleanup / Ejecutando limpieza"

echo -e "${GREEN}[1/5] Pruning stopped containers...${RESET}"
docker container prune -f

echo ""
echo -e "${GREEN}[2/5] Pruning images...${RESET}"
if $ALL; then
    docker image prune -a -f
else
    docker image prune -f
fi

echo ""
echo -e "${GREEN}[3/5] Pruning unused networks...${RESET}"
docker network prune -f

echo ""
echo -e "${GREEN}[4/5] Pruning BuildKit cache...${RESET}"
docker builder prune -f

if $INCLUDE_VOLUMES; then
    echo ""
    echo -e "${GREEN}[5/5] Pruning unused volumes...${RESET}"
    docker volume prune -f
else
    echo ""
    echo -e "${YELLOW}[5/5] Skipping volume prune (use --include-volumes to enable)${RESET}"
fi

# --- Step 8: Show new usage ---
write_header "Cleanup complete / Limpieza completa"
echo "New disk usage / Nuevo uso de disco:"
docker system df
