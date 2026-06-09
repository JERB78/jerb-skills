# safe_cleanup.ps1 — Docker cleanup with confirmations + space estimates (Windows PowerShell)
# Limpieza de Docker con confirmaciones + estimación de espacio (Windows PowerShell)
#
# Usage / Uso:
#   .\safe_cleanup.ps1                    # interactive, default safe (no volumes)
#   .\safe_cleanup.ps1 -IncludeVolumes    # also prune unused volumes (DESTRUCTIVE)
#   .\safe_cleanup.ps1 -DryRun            # show what would be deleted, don't delete
#   .\safe_cleanup.ps1 -All -Force        # nuke everything (with confirmation)

[CmdletBinding()]
param(
    [switch]$IncludeVolumes,
    [switch]$DryRun,
    [switch]$All,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

function Confirm-Action($message) {
    if ($Force) { return $true }
    $response = Read-Host "$message [y/N]"
    return $response -match '^(y|yes|s|si)$'
}

# --- Step 1: Show current disk usage ---
# Mostrar uso actual de disco
Write-Header "Current Docker disk usage / Uso actual de disco"
docker system df

# --- Step 2: Detailed breakdown ---
# Desglose detallado
Write-Header "Detailed breakdown / Desglose detallado"
docker system df -v 2>&1 | Select-Object -First 50

# --- Step 3: Estimate space to be reclaimed by safe pruning ---
# Estimar espacio a recuperar con pruning seguro
Write-Header "Estimating reclaimable space / Estimando espacio recuperable"

Write-Host "Calculating dangling images..." -ForegroundColor Yellow
$danglingImages = docker images -qf "dangling=true"
$danglingCount = if ($danglingImages) { ($danglingImages | Measure-Object).Count } else { 0 }
Write-Host "  Dangling images: $danglingCount"

Write-Host "Calculating stopped containers..." -ForegroundColor Yellow
$stoppedContainers = docker ps -aqf "status=exited"
$stoppedCount = if ($stoppedContainers) { ($stoppedContainers | Measure-Object).Count } else { 0 }
Write-Host "  Stopped containers: $stoppedCount"

Write-Host "Calculating unused networks..." -ForegroundColor Yellow
# All networks minus default ones (bridge, host, none) minus those in use
$unusedNetworks = docker network ls --filter "type=custom" -q
$unusedNetworksCount = if ($unusedNetworks) { ($unusedNetworks | Measure-Object).Count } else { 0 }
Write-Host "  Custom networks (some may be in use): $unusedNetworksCount"

# --- Step 4: Volume warning ---
# Advertencia de volúmenes
if ($IncludeVolumes -or $All) {
    Write-Header "VOLUME WARNING / ADVERTENCIA DE VOLÚMENES"
    Write-Host "Volumes often contain irreplaceable data (databases, uploads, configs)." -ForegroundColor Red
    Write-Host "Los volúmenes suelen contener data irreemplazable (DBs, uploads, configs)." -ForegroundColor Red
    Write-Host ""
    docker volume ls
    Write-Host ""
    if (-not (Confirm-Action "Are you SURE you want to prune unused volumes? / ¿Estás SEGURO de prune unused volumes?")) {
        Write-Host "Skipping volume prune. / Saltando prune de volúmenes." -ForegroundColor Yellow
        $IncludeVolumes = $false
    }
}

# --- Step 5: Dry run mode ---
# Modo dry-run
if ($DryRun) {
    Write-Header "DRY RUN MODE — nothing will be deleted / nada se borrará"
    Write-Host "Would run:"
    Write-Host "  docker container prune -f"
    Write-Host "  docker image prune $(if ($All) {'-a '})-f"
    Write-Host "  docker network prune -f"
    Write-Host "  docker builder prune -f"
    if ($IncludeVolumes) { Write-Host "  docker volume prune -f" }
    Write-Host ""
    Write-Host "Run again without -DryRun to actually delete." -ForegroundColor Yellow
    exit 0
}

# --- Step 6: Confirm before destructive actions ---
# Confirmar antes de acciones destructivas
Write-Header "Ready to clean up / Listo para limpiar"

$actions = @()
$actions += "- Stopped containers ($stoppedCount)"
$actions += "- Dangling images ($danglingCount)"
if ($All) { $actions += "- ALL unused images (not just dangling)" }
$actions += "- Unused networks"
$actions += "- BuildKit cache"
if ($IncludeVolumes) { $actions += "- UNUSED VOLUMES (DATA LOSS RISK)" }

Write-Host "Will delete: / Se borrará:"
$actions | ForEach-Object { Write-Host "  $_" }

if (-not (Confirm-Action "Proceed with cleanup? / ¿Proceder con limpieza?")) {
    Write-Host "Cancelled by user. / Cancelado por el usuario." -ForegroundColor Yellow
    exit 0
}

# --- Step 7: Execute ---
# Ejecutar
Write-Header "Executing cleanup / Ejecutando limpieza"

Write-Host "[1/5] Pruning stopped containers..." -ForegroundColor Green
docker container prune -f

Write-Host ""
Write-Host "[2/5] Pruning images..." -ForegroundColor Green
if ($All) {
    docker image prune -a -f
} else {
    docker image prune -f
}

Write-Host ""
Write-Host "[3/5] Pruning unused networks..." -ForegroundColor Green
docker network prune -f

Write-Host ""
Write-Host "[4/5] Pruning BuildKit cache..." -ForegroundColor Green
docker builder prune -f

if ($IncludeVolumes) {
    Write-Host ""
    Write-Host "[5/5] Pruning unused volumes..." -ForegroundColor Green
    docker volume prune -f
} else {
    Write-Host ""
    Write-Host "[5/5] Skipping volume prune (use -IncludeVolumes to enable)" -ForegroundColor Yellow
}

# --- Step 8: Show new usage ---
# Mostrar uso nuevo
Write-Header "Cleanup complete / Limpieza completa"
Write-Host "New disk usage / Nuevo uso de disco:"
docker system df

# --- Step 9: WSL2 VHDX note (Windows only) ---
# Nota sobre VHDX de WSL2 (solo Windows)
Write-Host ""
Write-Host "NOTE / NOTA:" -ForegroundColor Yellow
Write-Host "On Windows, freed space inside Docker doesn't automatically shrink the WSL2 VHDX file." -ForegroundColor Yellow
Write-Host "En Windows, el espacio liberado dentro de Docker NO encoge automáticamente el archivo VHDX de WSL2." -ForegroundColor Yellow
Write-Host ""
Write-Host "To reclaim Windows disk space, run: / Para recuperar espacio en disco de Windows, correr:"
Write-Host "  wsl --shutdown" -ForegroundColor Cyan
Write-Host "  Optimize-VHD -Path `"$env:LOCALAPPDATA\Docker\wsl\disk\docker_data.vhdx`" -Mode Full" -ForegroundColor Cyan
Write-Host ""
Write-Host "(Requires Hyper-V tools — bundled with Docker Desktop.) / (Requiere herramientas Hyper-V — vienen con Docker Desktop.)"
