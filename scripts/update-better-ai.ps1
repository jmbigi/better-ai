#Requires -Version 5.1
<#
.SYNOPSIS
    Actualiza una instalacion existente de better-ai en un proyecto destino.
.DESCRIPTION
    Equivalente en PowerShell de scripts/update-better-ai.sh.
    Requiere que el destino tenga .better-ai.manifest creado por install-better-ai.ps1.
.PARAMETER Destino
    Directorio del proyecto donde actualizar better-ai.
.PARAMETER DryRun
    Muestra que cambiaria sin tocar disco.
.EXAMPLE
    .\scripts\update-better-ai.ps1 -Destino C:\mis-proyectos\mi-app
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Destino,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$SourceDir = Split-Path -Parent $PSScriptRoot
$SourceDir = (Resolve-Path -LiteralPath $SourceDir).Path

try {
    $Destino = (Resolve-Path -LiteralPath $Destino).Path
} catch {
    Write-Error "No se puede acceder al destino: $Destino"
}

if ($Destino -eq "/" -or $Destino -eq "\\" -or $Destino -match "^[A-Z]:\\\?$") {
    Write-Error "Destino prohibido: $Destino"
}

$Manifest = Join-Path $Destino ".better-ai.manifest"
if (-not (Test-Path -LiteralPath $Manifest)) {
    Write-Error "No existe $Manifest. Instala primero con scripts/install-better-ai.ps1"
}

try {
    $SourceCommit = (git -C $SourceDir rev-parse HEAD 2>$null).Trim()
} catch {
    $SourceCommit = "unknown"
}

$PreviousCommit = "unknown"
Get-Content -LiteralPath $Manifest | ForEach-Object {
    if ($_ -match '^source_commit:\s*(.+)$') {
        $PreviousCommit = $Matches[1].Trim()
    }
}

Write-Host "=== Actualizando better-ai en $Destino ==="
Write-Host "Version anterior: $PreviousCommit"
Write-Host "Nueva version: $SourceCommit"
Write-Host "Modo dry-run: $DryRun"
Write-Host ""

$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$BackupDir = Join-Path $Destino ".better-ai-backup-$Timestamp"
if ($DryRun) {
    Write-Host "[DRY-RUN] se crearia backup en $BackupDir"
} else {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Leer archivos del manifesto
$Files = @()
$InFiles = $false
Get-Content -LiteralPath $Manifest | ForEach-Object {
    if ($_ -eq "files:") {
        $InFiles = $true
    } elseif ($InFiles -and $_ -match '^\s+-\s+(.+)$') {
        $Files += $Matches[1].Trim()
    }
}

if ($Files.Count -eq 0) {
    Write-Error "No se encontraron archivos en el manifesto"
}

foreach ($rel in $Files) {
    $src = Join-Path $SourceDir $rel
    $dst = Join-Path $Destino $rel
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "No existe en fuente: $rel"
        continue
    }
    if ($DryRun) {
        if (Test-Path -LiteralPath $dst) {
            Write-Host "  [DRY-RUN] sobrescribir $dst (backup en $BackupDir)"
        } else {
            Write-Host "  [DRY-RUN] copiar $src -> $dst"
        }
        continue
    }
    # Backup del archivo destino si existe
    if (Test-Path -LiteralPath $dst) {
        $backupPath = Join-Path $BackupDir $rel
        $backupDir = Split-Path -Parent $backupPath
        if (-not (Test-Path -LiteralPath $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $dst -Destination $backupPath -Recurse -Force
    }
    $dstDir = Split-Path -Parent $dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force
}

if ($DryRun) {
    Write-Host "[DRY-RUN] actualizar $Manifest"
} else {
    Copy-Item -LiteralPath $Manifest -Destination (Join-Path $BackupDir ".better-ai.manifest") -Force
    $Lines = @(
        "# better-ai manifest",
        "source_commit: $SourceCommit",
        "installed_at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
        "previous_commit: $PreviousCommit",
        "files:"
    )
    foreach ($f in $Files) {
        $Lines += "  - $f"
    }
    $Lines | Set-Content -LiteralPath $Manifest -Encoding UTF8
    Write-Host "[OK] Manifesto actualizado"
    Write-Host "[OK] Backup creado en $BackupDir"
}

Write-Host ""
Write-Host "[OK] Actualizacion completada ($($Files.Count) archivos)"
