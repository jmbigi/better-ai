#Requires -Version 5.1
<#
.SYNOPSIS
    Instala better-ai en un proyecto destino.
.DESCRIPTION
    Equivalente en PowerShell de scripts/install-better-ai.sh.
    El usuario debe clonar el repo better-ai y ejecutar este script localmente;
    no se soporta ni se promociona curl | bash (P0.8).
.PARAMETER Destino
    Directorio del proyecto donde instalar better-ai.
.PARAMETER DryRun
    Muestra que copiaria sin tocar disco.
.PARAMETER CoreOnly
    Instala solo AGENTS.md, CHECKLIST.md, opencode.json, kilo.json y agentes.
.PARAMETER WithHooks
    Instala hooks git pre-commit si el destino es un repo git.
.EXAMPLE
    .\scripts\install-better-ai.ps1 -Destino C:\mis-proyectos\mi-app
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Destino,

    [switch]$DryRun,
    [switch]$CoreOnly,
    [switch]$WithHooks
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

if ($Destino -eq $SourceDir) {
    Write-Error "El destino no puede ser el propio repositorio better-ai"
}

try {
    $SourceCommit = (git -C $SourceDir rev-parse HEAD 2>$null).Trim()
} catch {
    $SourceCommit = "unknown"
}

$CoreFiles = @(
    "AGENTS.md",
    "CHECKLIST.md",
    "opencode.json",
    "kilo.json"
)

$AgentDirs = @(
    ".opencode/agents",
    ".kilo/agents"
)

$ScriptFiles = @(
    "scripts/analyze_shell.py",
    "scripts/check-config-parity.py",
    "scripts/check-shell-pipes.py",
    "scripts/check-symlinks.sh",
    "scripts/detect-drift.sh",
    "scripts/doc_validator.py",
    "scripts/install-better-ai.ps1",
    "scripts/install-better-ai.sh",
    "scripts/install-hooks.sh",
    "scripts/opencode-sandbox.sh",
    "scripts/probar-denies.sh",
    "scripts/rotate-secret.sh",
    "scripts/sync-agents.sh",
    "scripts/update-better-ai.ps1",
    "scripts/update-better-ai.sh",
    "scripts/verificar-proyecto.sh",
    "scripts/verificar-requisitos.cmd",
    "scripts/verificar-requisitos.ps1"
)

$BuildFiles = @(
    "Containerfile",
    "Makefile",
    "lefthook.yml"
)

$DocFiles = @(
    "docs/ARQUITECTURA-DETERMINISMO.md",
    "docs/INTEGRACION-ASISTENTES.md",
    "docs/LECCIONES-APRENDIDAS.md",
    "docs/PRUEBAS.md",
    "docs/REGLAS-COMPLETAS.md"
)

if ($CoreOnly) {
    $FilesToInstall = $CoreFiles
} else {
    $FilesToInstall = $CoreFiles + $ScriptFiles + $BuildFiles + $DocFiles
}

function Copy-FileSafe {
    param([string]$Src, [string]$Dst)
    $DstDir = Split-Path -Parent $Dst
    if ($DryRun) {
        Write-Host "  [DRY-RUN] copiar $Src -> $Dst"
        return
    }
    if (-not (Test-Path -LiteralPath $DstDir)) {
        New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $Src -Destination $Dst -Force
}

function Copy-DirSafe {
    param([string]$Src, [string]$Dst)
    if ($DryRun) {
        Write-Host "  [DRY-RUN] copiar directorio $Src -> $Dst"
        return
    }
    if (-not (Test-Path -LiteralPath $Dst)) {
        New-Item -ItemType Directory -Path $Dst -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $Src -File -Recurse | ForEach-Object {
        $Relative = $_.FullName.Substring($SourceDir.Length + 1)
        $Target = Join-Path $Destino $Relative
        $TargetDir = Split-Path -Parent $Target
        if (-not (Test-Path -LiteralPath $TargetDir)) {
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $Target -Force
    }
}

Write-Host "=== Instalando better-ai en $Destino ==="
Write-Host "Fuente: $SourceDir ($SourceCommit)"
Write-Host "Modo dry-run: $DryRun"
Write-Host "Core-only: $CoreOnly"
Write-Host ""

$InstalledFiles = [System.Collections.Generic.List[string]]::new()

foreach ($rel in $FilesToInstall) {
    $src = Join-Path $SourceDir $rel
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "No existe en fuente: $rel"
        continue
    }
    $dst = Join-Path $Destino $rel
    Copy-FileSafe -Src $src -Dst $dst
    $InstalledFiles.Add($rel)
}

foreach ($rel in $AgentDirs) {
    $src = Join-Path $SourceDir $rel
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "No existe directorio en fuente: $rel"
        continue
    }
    $dst = Join-Path $Destino $rel
    Copy-DirSafe -Src $src -Dst $dst
    Get-ChildItem -LiteralPath $src -File -Recurse | ForEach-Object {
        $InstalledFiles.Add($_.FullName.Substring($SourceDir.Length + 1).Replace("\", "/"))
    }
}

if ($WithHooks) {
    $GitDir = Join-Path $Destino ".git"
    if (Test-Path -LiteralPath $GitDir -PathType Container) {
        if ($DryRun) {
            Write-Host "  [DRY-RUN] instalar hooks git"
        } else {
            & "$SourceDir/scripts/install-hooks.sh" "$Destino"
        }
    } else {
        Write-Host "  [INFO] No hay repo git en destino; se omite instalacion de hooks"
    }
}

$Manifest = Join-Path $Destino ".better-ai.manifest"
if ($DryRun) {
    Write-Host "  [DRY-RUN] crear $Manifest"
} else {
    $Lines = @(
        "# better-ai manifest",
        "source_commit: $SourceCommit",
        "installed_at: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))",
        "core_only: $CoreOnly",
        "files:"
    )
    foreach ($f in $InstalledFiles) {
        $Lines += "  - $f"
    }
    $Lines | Set-Content -LiteralPath $Manifest -Encoding UTF8
    Write-Host "[OK] Manifesto creado: $Manifest"
}

Write-Host ""
Write-Host "[OK] Instalacion completada ($($InstalledFiles.Count) archivos)"
