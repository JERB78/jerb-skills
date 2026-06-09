# inspect_failed.ps1 — Comprehensive diagnostic for a failed/crashed container (Windows)
# Diagnóstico comprensivo para un contenedor fallado/crasheado (Windows)
#
# Usage / Uso:
#   .\inspect_failed.ps1 <container-name-or-id>
#   .\inspect_failed.ps1 my-api
#   .\inspect_failed.ps1 abc123     # use ID prefix
#
# Auto-runs: status, logs, inspect state, recent events, system df, network/volume info

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Container
)

$ErrorActionPreference = "Continue"  # don't fail on missing fields

function Write-Section($title) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
}

# Verify container exists
$exists = docker ps -a --filter "name=$Container" --filter "id=$Container" -q
if (-not $exists) {
    Write-Host "ERROR: No container matching '$Container' found." -ForegroundColor Red
    Write-Host "Try: docker ps -a   to see all containers" -ForegroundColor Yellow
    exit 1
}

# Resolve to full container ID for consistent referencing
$ContainerId = docker ps -a --filter "name=$Container" --filter "id=$Container" -q | Select-Object -First 1

# --- 1. Current status ---
Write-Section "1. Current status / Estado actual"
docker ps -a --filter "id=$ContainerId" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}`t{{.Image}}"

# --- 2. State details (exit code, error, OOM) ---
Write-Section "2. State details / Detalles de estado"
$state = docker inspect $ContainerId --format '{{json .State}}' | ConvertFrom-Json
Write-Host "Status:      $($state.Status)"
Write-Host "Running:     $($state.Running)"
Write-Host "Exit code:   $($state.ExitCode)"
Write-Host "Error:       $($state.Error)"
Write-Host "OOMKilled:   $($state.OOMKilled)"
Write-Host "Started at:  $($state.StartedAt)"
Write-Host "Finished at: $($state.FinishedAt)"
Write-Host "Restarting:  $($state.Restarting)"
Write-Host "Restart Count: $($state.RestartCount)"

# Interpret exit code
$exitCodeInterpretation = switch ($state.ExitCode) {
    0   { "Success / clean exit — app finished normally" }
    1   { "Generic error — read logs below" }
    125 { "Docker daemon error — check docker run/compose syntax" }
    126 { "Cannot execute — chmod +x missing? wrong path?" }
    127 { "Command not found — typo in CMD? binary missing?" }
    137 { "SIGKILL — likely OOM (check OOMKilled field above)" }
    139 { "SIGSEGV — segfault, possibly C extension or arch mismatch" }
    143 { "SIGTERM — graceful shutdown (expected if you did docker stop)" }
    default { "See SKILL.md debug-decision-trees.md for less common codes" }
}
Write-Host ""
Write-Host "Exit code interpretation: $exitCodeInterpretation" -ForegroundColor Yellow

# --- 3. Recent logs ---
Write-Section "3. Last 100 log lines / Últimas 100 líneas de log"
docker logs --tail 100 --timestamps $ContainerId 2>&1

# --- 4. Healthcheck history ---
Write-Section "4. Healthcheck status / Estado de healthcheck"
$health = docker inspect $ContainerId --format '{{json .State.Health}}' 2>$null
if ($health -and $health -ne "null") {
    $health | ConvertFrom-Json | ConvertTo-Json -Depth 5
} else {
    Write-Host "No healthcheck configured for this container."
}

# --- 5. Recent docker events around the container ---
Write-Section "5. Recent events (last 1h) / Eventos recientes (última hora)"
docker events --since 1h --until 0s --filter "container=$ContainerId" 2>&1 | Select-Object -First 30

# --- 6. Resource usage (if running) ---
if ($state.Running) {
    Write-Section "6. Current resource usage (live) / Uso de recursos actual"
    docker stats --no-stream $ContainerId
}

# --- 7. Configuration summary ---
Write-Section "7. Configuration / Configuración"
$config = docker inspect $ContainerId --format '{{json .Config}}' | ConvertFrom-Json
$hostConfig = docker inspect $ContainerId --format '{{json .HostConfig}}' | ConvertFrom-Json

Write-Host "Image:       $($config.Image)"
Write-Host "Entrypoint:  $($config.Entrypoint -join ' ')"
Write-Host "Cmd:         $($config.Cmd -join ' ')"
Write-Host "Working dir: $($config.WorkingDir)"
Write-Host "User:        $($config.User)"
Write-Host ""
Write-Host "Memory limit:  $($hostConfig.Memory) bytes ($([math]::Round($hostConfig.Memory / 1MB, 2)) MB)"
Write-Host "CPU limit:     $($hostConfig.NanoCpus) nano-CPUs ($([math]::Round($hostConfig.NanoCpus / 1e9, 2)) cores)"
Write-Host "Restart policy: $($hostConfig.RestartPolicy.Name)"
Write-Host ""
Write-Host "Env vars (count): $($config.Env.Count)"
$config.Env | ForEach-Object { Write-Host "  $_" }

# --- 8. Mounts ---
Write-Section "8. Mounts (volumes + binds) / Mounts (volúmenes + binds)"
$mounts = docker inspect $ContainerId --format '{{json .Mounts}}' | ConvertFrom-Json
if ($mounts) {
    $mounts | ForEach-Object {
        Write-Host "Type:        $($_.Type)"
        Write-Host "  Source:      $($_.Source)"
        Write-Host "  Destination: $($_.Destination)"
        Write-Host "  Mode:        $($_.Mode)"
        Write-Host "  RW:          $($_.RW)"
        Write-Host ""
    }
} else {
    Write-Host "No mounts."
}

# --- 9. Networks ---
Write-Section "9. Network attachments / Redes conectadas"
$networks = docker inspect $ContainerId --format '{{json .NetworkSettings.Networks}}' | ConvertFrom-Json
foreach ($netName in $networks.PSObject.Properties.Name) {
    $net = $networks.$netName
    Write-Host "Network:  $netName"
    Write-Host "  IP:         $($net.IPAddress)"
    Write-Host "  Gateway:    $($net.Gateway)"
    Write-Host "  Aliases:    $($net.Aliases -join ', ')"
    Write-Host ""
}

# --- 10. Suggestions ---
Write-Section "10. Suggested next steps / Próximos pasos sugeridos"

if ($state.ExitCode -eq 137 -and $state.OOMKilled) {
    Write-Host "→ Out of memory. Either:" -ForegroundColor Yellow
    Write-Host "  - Increase limit: docker run -m 1g ..."
    Write-Host "  - Reduce app memory usage"
    Write-Host "  - Check for memory leaks"
} elseif ($state.ExitCode -eq 1) {
    Write-Host "→ App crashed. Re-read logs above for the actual error." -ForegroundColor Yellow
    Write-Host "  Common: missing env vars, port conflict, DB connection failed."
} elseif ($state.ExitCode -eq 125) {
    Write-Host "→ Docker daemon error. Check the original 'docker run' or compose file." -ForegroundColor Yellow
} elseif ($state.ExitCode -eq 126 -or $state.ExitCode -eq 127) {
    Write-Host "→ Entrypoint/CMD problem. Try:" -ForegroundColor Yellow
    Write-Host "  docker run --rm -it --entrypoint sh $($config.Image)"
    Write-Host "  Then manually check the binary path / permissions."
} elseif ($state.Restarting) {
    Write-Host "→ Crash loop. Disable auto-restart while debugging:" -ForegroundColor Yellow
    Write-Host "  docker update --restart=no $ContainerId"
}

Write-Host ""
Write-Host "Full inspect output: docker inspect $ContainerId" -ForegroundColor DarkGray
Write-Host "Follow logs:         docker logs -f $ContainerId" -ForegroundColor DarkGray
Write-Host "Exec into container: docker exec -it $ContainerId sh" -ForegroundColor DarkGray
