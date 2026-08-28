#!/usr/bin/env bash
# Instala el hook git pre-commit con backup del existente.
# Uso: bash scripts/install-hooks.sh
set -u
cd "$(dirname "$0")/.." || exit 1

SRC="scripts/hooks/pre-commit"
DEST=".git/hooks/pre-commit"

if [ ! -f "$SRC" ]; then
    echo "[FALLO] No existe $SRC"
    exit 1
fi

if [ ! -d ".git" ]; then
    echo "[FALLO] No se encontro el directorio .git"
    exit 1
fi

if [ -f "$DEST" ]; then
    BACKUP="$DEST.bak.$(date +%Y%m%d%H%M%S)"
    cp "$DEST" "$BACKUP"
    echo "[INFO] Hook existente respaldado en $BACKUP"
fi

cp "$SRC" "$DEST"
chmod +x "$DEST"

echo "[OK] Hook pre-commit instalado en $DEST"
