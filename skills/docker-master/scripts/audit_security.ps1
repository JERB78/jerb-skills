# audit_security.ps1 — Batch security scan of all local Docker images (Windows)
# Escaneo de seguridad en lote de todas las imágenes locales (Windows)
#
# Auto-detects available scanner (Trivy preferred, falls back to Docker Scout).
# Saves a summary report + per-image details.
#
# Usage / Uso:
#   .\audit_security.ps1                                # all local images
#   .\audit_security.ps1 -Image myapp:v1                # single image
#   .\audit_security.ps1 -SeverityThreshold HIGH        # default; only HIGH+CRITICAL
#   .\audit_security.ps1 -OutputDir .\security-report   # custom output folder

[CmdletBinding()]
param(
    [string]$Image = "",
    [ValidateSet("CRITICAL", "HIGH", "MEDIUM", "LOW")]
    [string]$SeverityThreshold = "HIGH",
    [string]$OutputDir = ".\security-report",
    [switch]$NoFail
)

$ErrorActionPreference = "Stop"

# --- Detect scanner ---
function Get-Scanner {
    if (Get-Command trivy -ErrorAction SilentlyContinue) {
        return "trivy"
    } elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
        $scoutAvailable = docker scout 2>&1 | Select-String "Docker Scout"
        if ($scoutAvailable) {
            return "scout"
        }
    }
    return $null
}

$Scanner = Get-Scanner
if (-not $Scanner) {
    Write-Host "ERROR: No security scanner found." -ForegroundColor Red
    Write-Host "Install one of:" -ForegroundColor Yellow
    Write-Host "  Trivy:  winget install AquaSecurity.Trivy"
    Write-Host "  Scout:  comes with Docker Desktop 4.17+"
    exit 1
}

Write-Host "Using scanner: $Scanner" -ForegroundColor Cyan
Write-Host "Severity threshold: $SeverityThreshold (and higher)" -ForegroundColor Cyan

# --- Create output dir ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# --- List images to scan ---
if ($Image) {
    $images = @($Image)
} else {
    $images = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -notmatch ':<none>' }
}

Write-Host ""
Write-Host "Images to scan: $($images.Count)" -ForegroundColor Cyan
$images | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

# --- Severity score for sorting ---
$severityRank = @{ "CRITICAL"=4; "HIGH"=3; "MEDIUM"=2; "LOW"=1; "UNKNOWN"=0 }

# --- Build severity filter for trivy ---
$severitiesToScan = @()
foreach ($s in @("CRITICAL", "HIGH", "MEDIUM", "LOW")) {
    if ($severityRank[$s] -ge $severityRank[$SeverityThreshold]) {
        $severitiesToScan += $s
    }
}
$severityFilter = $severitiesToScan -join ","

# --- Summary collector ---
$summary = @()

# --- Scan loop ---
foreach ($img in $images) {
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  Scanning: $img" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Yellow

    $sanitizedName = $img -replace '[:/\\]', '-'
    $reportPath = Join-Path $OutputDir "$sanitizedName.json"

    if ($Scanner -eq "trivy") {
        # Trivy: JSON output + console summary
        try {
            trivy image --severity $severityFilter --format json --output $reportPath $img 2>&1 | Out-Null
            trivy image --severity $severityFilter $img

            # Parse counts from JSON for summary
            $report = Get-Content $reportPath -Raw | ConvertFrom-Json
            $counts = @{ CRITICAL=0; HIGH=0; MEDIUM=0; LOW=0; UNKNOWN=0 }
            if ($report.Results) {
                foreach ($result in $report.Results) {
                    if ($result.Vulnerabilities) {
                        foreach ($vuln in $result.Vulnerabilities) {
                            $sev = $vuln.Severity
                            if ($counts.ContainsKey($sev)) {
                                $counts[$sev]++
                            }
                        }
                    }
                }
            }

            $summary += [PSCustomObject]@{
                Image = $img
                Critical = $counts.CRITICAL
                High = $counts.HIGH
                Medium = $counts.MEDIUM
                Low = $counts.LOW
                Total = $counts.CRITICAL + $counts.HIGH + $counts.MEDIUM + $counts.LOW
                ReportFile = $reportPath
            }
        } catch {
            Write-Host "Failed to scan $img : $_" -ForegroundColor Red
            $summary += [PSCustomObject]@{
                Image = $img
                Critical = "ERROR"; High = "ERROR"; Medium = "ERROR"; Low = "ERROR"
                Total = "ERROR"; ReportFile = ""
            }
        }
    } elseif ($Scanner -eq "scout") {
        # Docker Scout: CVE output (text only — no JSON in free tier)
        try {
            docker scout cves --only-severity ($severitiesToScan -join ",").ToLower() $img 2>&1 | Tee-Object -FilePath $reportPath

            $summary += [PSCustomObject]@{
                Image = $img
                Critical = "see report"; High = "see report"; Medium = "see report"; Low = "see report"
                Total = "see report"; ReportFile = $reportPath
            }
        } catch {
            Write-Host "Failed to scan $img : $_" -ForegroundColor Red
        }
    }
}

# --- Final summary ---
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SECURITY AUDIT SUMMARY / RESUMEN DE AUDITORÍA" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
$summary | Format-Table -AutoSize

# Save summary as CSV
$summaryCsv = Join-Path $OutputDir "_summary.csv"
$summary | Export-Csv -Path $summaryCsv -NoTypeInformation
Write-Host ""
Write-Host "Summary saved: $summaryCsv" -ForegroundColor Green
Write-Host "Per-image reports in: $OutputDir" -ForegroundColor Green

# --- Exit code ---
$totalCritical = ($summary | Where-Object { $_.Critical -is [int] } | Measure-Object -Property Critical -Sum).Sum
$totalHigh = ($summary | Where-Object { $_.High -is [int] } | Measure-Object -Property High -Sum).Sum

if ($totalCritical -gt 0 -or $totalHigh -gt 0) {
    Write-Host ""
    Write-Host "FINDINGS: $totalCritical CRITICAL, $totalHigh HIGH across all images." -ForegroundColor Red

    if (-not $NoFail) {
        Write-Host "Exiting with code 1 (use -NoFail to suppress)." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Audit complete. / Auditoría completa." -ForegroundColor Green
