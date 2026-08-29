#!/usr/bin/env bash
# Instala better-ai en un proyecto destino.
# Uso: bash scripts/install-better-ai.sh [--dry-run] [--with-hooks] [--core-only] <destino>
# El usuario debe clonar el repo better-ai y ejecutar este script localmente;
# no se soporta ni se promociona curl | bash (P0.8).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DRY_RUN=false
WITH_HOOKS=false
CORE_ONLY=false
DEST=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --with-hooks) WITH_HOOKS=true ;;
        --core-only) CORE_ONLY=true ;;
        -*)
            echo "[FALLO] Opcion desconocida: $arg" >&2
            echo "Uso: $0 [--dry-run] [--with-hooks] [--core-only] <destino>" >&2
            exit 1
            ;;
        *)
            if [ -n "$DEST" ]; then
                echo "[FALLO] Solo se permite un destino" >&2
                exit 1
            fi
            DEST="$arg"
            ;;
    esac
done

if [ -z "$DEST" ]; then
    echo "[FALLO] Falta el directorio destino" >&2
    echo "Uso: $0 [--dry-run] [--with-hooks] [--core-only] <destino>" >&2
    exit 1
fi

# Resolver destino a ruta absoluta y validar que no sea peligrosa
DEST="$(cd "$DEST" 2>/dev/null && pwd)" || {
    echo "[FALLO] No se puede acceder al destino: $DEST" >&2
    exit 1
}

if [ "$DEST" = "/" ]; then
    echo "[FALLO] Destino prohibido: /" >&2
    exit 1
fi

if [ "$DEST" = "$SOURCE_DIR" ]; then
    echo "[FALLO] El destino no puede ser el propio repositorio better-ai" >&2
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo "[FALLO] El destino no existe o no es un directorio: $DEST" >&2
    exit 1
fi

SOURCE_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"

CORE_FILES=(
    AGENTS.md
    CHECKLIST.md
    opencode.json
    kilo.json
)

AGENT_DIRS=(
    .opencode/agents
    .kilo/agents
)

SCRIPT_FILES=(
    scripts/analyze_shell.py
    scripts/check-config-parity.py
    scripts/check-shell-pipes.py
    scripts/check-symlinks.sh
    scripts/detect-drift.sh
    scripts/doc_validator.py
    scripts/generate-sbom.sh
    scripts/install-better-ai.ps1
    scripts/install-better-ai.sh
    scripts/install-hooks.sh
    scripts/opencode-sandbox.sh
    scripts/probar-denies.sh
    scripts/rotate-secret.sh
    scripts/sync-agents.sh
    scripts/update-better-ai.ps1
    scripts/update-better-ai.sh
    scripts/verificar-proyecto.sh
    scripts/verificar-requisitos.cmd
    scripts/verificar-requisitos.ps1
)

BUILD_FILES=(
    Containerfile
    Makefile
    lefthook.yml
)

DOC_FILES=(
    docs/ARQUITECTURA-DETERMINISMO.md
    docs/INTEGRACION-ASISTENTES.md
    docs/LECCIONES-APRENDIDAS.md
    docs/PRUEBAS.md
    docs/QUICKSTART.md
    docs/REGLAS-COMPLETAS.md
)

SKILL_DIRS=(
    .opencode/skills
)

if [ "$CORE_ONLY" = true ]; then
    FILES_TO_INSTALL=("${CORE_FILES[@]}")
else
    FILES_TO_INSTALL=("${CORE_FILES[@]}" "${SCRIPT_FILES[@]}" "${BUILD_FILES[@]}" "${DOC_FILES[@]}")
fi

DIRS_TO_INSTALL=("${AGENT_DIRS[@]}" "${SKILL_DIRS[@]}")

log() {
    echo "$1"
}

copy_file() {
    local src="$1"
    local dst="$2"
    local dst_dir
    dst_dir="$(dirname "$dst")"
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY-RUN] copiar $src -> $dst"
        return 0
    fi
    mkdir -p "$dst_dir"
    cp "$src" "$dst"
}

copy_dir() {
    local src="$1"
    local dst="$2"
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY-RUN] copiar directorio $src/ -> $dst/"
        return 0
    fi
    mkdir -p "$dst"
    # Copiar contenido, no el directorio en si, para no anidar.
    if [ -n "$(find "$src" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        cp -r "$src"/. "$dst"/
    fi
}

log "=== Instalando better-ai en $DEST ==="
log "Fuente: $SOURCE_DIR ($SOURCE_COMMIT)"
log "Modo dry-run: $DRY_RUN"
log "Core-only: $CORE_ONLY"
log ""

INSTALLED_FILES=()

for rel in "${FILES_TO_INSTALL[@]}"; do
    src="$SOURCE_DIR/$rel"
    if [ ! -e "$src" ]; then
        echo "[SKIP] No existe en fuente: $rel" >&2
        continue
    fi
    copy_file "$src" "$DEST/$rel"
    INSTALLED_FILES+=("$rel")
done

for rel in "${DIRS_TO_INSTALL[@]}"; do
    src="$SOURCE_DIR/$rel"
    if [ ! -d "$src" ]; then
        echo "[SKIP] No existe directorio en fuente: $rel" >&2
        continue
    fi
    copy_dir "$src" "$DEST/$rel"
    # Registrar todos los archivos del directorio en el manifesto.
    while IFS= read -r -d '' f; do
        rel_file="${f#$SOURCE_DIR/}"
        INSTALLED_FILES+=("$rel_file")
    done < <(find "$src" -type f -print0)
done

if [ "$WITH_HOOKS" = true ]; then
    if [ "$DRY_RUN" = true ]; then
        log "  [DRY-RUN] instalar hooks git"
    else
        if [ -d "$DEST/.git" ]; then
            bash "$SOURCE_DIR/scripts/install-hooks.sh" "$DEST"
        else
            log "  [INFO] No hay repo git en destino; se omite instalacion de hooks"
        fi
    fi
fi

# Generar manifesto
if [ "$DRY_RUN" = true ]; then
    log "  [DRY-RUN] crear $DEST/.better-ai.manifest"
else
    MANIFEST="$DEST/.better-ai.manifest"
    {
        echo "# better-ai manifest"
        echo "source_commit: $SOURCE_COMMIT"
        echo "installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "core_only: $CORE_ONLY"
        echo "files:"
        for f in "${INSTALLED_FILES[@]}"; do
            echo "  - $f"
        done
    } > "$MANIFEST"
    log "[OK] Manifesto creado: $MANIFEST"
fi

log ""
log "[OK] Instalacion completada (${#INSTALLED_FILES[@]} archivos)"
