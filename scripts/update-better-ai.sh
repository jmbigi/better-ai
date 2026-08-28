#!/usr/bin/env bash
# Actualiza una instalacion existente de better-ai en un proyecto destino.
# Uso: bash scripts/update-better-ai.sh [--dry-run] <destino>
# Requiere que el destino tenga .better-ai.manifest creado por install-better-ai.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DRY_RUN=false
DEST=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -*)
            echo "[FALLO] Opcion desconocida: $arg" >&2
            echo "Uso: $0 [--dry-run] <destino>" >&2
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
    echo "Uso: $0 [--dry-run] <destino>" >&2
    exit 1
fi

DEST="$(cd "$DEST" 2>/dev/null && pwd)" || {
    echo "[FALLO] No se puede acceder al destino: $DEST" >&2
    exit 1
}

if [ "$DEST" = "/" ]; then
    echo "[FALLO] Destino prohibido: /" >&2
    exit 1
fi

MANIFEST="$DEST/.better-ai.manifest"
if [ ! -f "$MANIFEST" ]; then
    echo "[FALLO] No existe $MANIFEST. Instala primero con scripts/install-better-ai.sh" >&2
    exit 1
fi

SOURCE_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")"
PREVIOUS_COMMIT="$(grep '^source_commit:' "$MANIFEST" | cut -d: -f2- | xargs || echo "unknown")"

log() {
    echo "$1"
}

log "=== Actualizando better-ai en $DEST ==="
log "Version anterior: $PREVIOUS_COMMIT"
log "Nueva version: $SOURCE_COMMIT"
log "Modo dry-run: $DRY_RUN"
log ""

# Backup timestamped de los archivos que van a ser sobrescritos.
BACKUP_DIR="$DEST/.better-ai-backup-$(date -u +%Y%m%dT%H%M%SZ)"
if [ "$DRY_RUN" = true ]; then
    log "[DRY-RUN] se crearia backup en $BACKUP_DIR"
else
    mkdir -p "$BACKUP_DIR"
fi

# Recopilar archivos del manifesto.
FILES=()
IN_FILES=false
while IFS= read -r line; do
    if [ "$line" = "files:" ]; then
        IN_FILES=true
        continue
    fi
    if [ "$IN_FILES" = true ]; then
        # Quitar prefijo "  - "
        f="${line#  - }"
        [ -n "$f" ] && FILES+=("$f")
    fi
done < "$MANIFEST"

if [ ${#FILES[@]} -eq 0 ]; then
    echo "[FALLO] No se encontraron archivos en el manifesto" >&2
    exit 1
fi

for rel in "${FILES[@]}"; do
    src="$SOURCE_DIR/$rel"
    dst="$DEST/$rel"
    if [ ! -e "$src" ]; then
        echo "[SKIP] No existe en fuente: $rel" >&2
        continue
    fi
    if [ "$DRY_RUN" = true ]; then
        if [ -e "$dst" ]; then
            log "  [DRY-RUN] sobrescribir $dst (backup en $BACKUP_DIR)"
        else
            log "  [DRY-RUN] copiar $src -> $dst"
        fi
        continue
    fi
    # Backup del archivo destino si existe.
    if [ -e "$dst" ]; then
        backup_path="$BACKUP_DIR/$rel"
        mkdir -p "$(dirname "$backup_path")"
        cp -r "$dst" "$backup_path" 2>/dev/null || cp "$dst" "$backup_path"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
done

# Actualizar manifesto
if [ "$DRY_RUN" = true ]; then
    log "[DRY-RUN] actualizar $MANIFEST"
else
    # Preservar el manifesto anterior como backup
    cp "$MANIFEST" "$BACKUP_DIR/.better-ai.manifest"
    {
        echo "# better-ai manifest"
        echo "source_commit: $SOURCE_COMMIT"
        echo "installed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "previous_commit: $PREVIOUS_COMMIT"
        echo "files:"
        for f in "${FILES[@]}"; do
            echo "  - $f"
        done
    } > "$MANIFEST"
    log "[OK] Manifesto actualizado"
    log "[OK] Backup creado en $BACKUP_DIR"
fi

log ""
log "[OK] Actualizacion completada (${#FILES[@]} archivos)"
