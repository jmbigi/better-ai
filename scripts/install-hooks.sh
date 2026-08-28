#!/usr/bin/env bash
# Instala el hook git pre-commit con backup del existente.
# Si Lefthook esta disponible, lo usa como gestor de hooks preferido.
# Uso: bash scripts/install-hooks.sh
set -u
cd "$(dirname "$0")/.." || exit 1

if command -v lefthook >/dev/null 2>&1; then
    echo "[INFO] Lefthook detectado; instalando hooks via lefthook install"
    lefthook install
    echo "[OK] Hooks de Lefthook instalados"
    exit 0
fi

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
echo "[INFO] Instala Lefthook (https://lefthook.dev/installation) para gestion multiplataforma de hooks"
