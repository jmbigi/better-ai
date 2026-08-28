#!/usr/bin/env bash
# Verifica que no haya symlinks rotos en el repositorio.
# Uso: bash scripts/check-symlinks.sh
set -u
cd "$(dirname "$0")/.." || exit 1

ROTO=false
while IFS= read -r link; do
    echo "[FALLO] Symlink roto: $link"
    ROTO=true
done < <(find . -xtype l -not -path './.git/*' 2>/dev/null)

if [ "$ROTO" = true ]; then
    exit 1
fi

echo "[OK] No hay symlinks rotos"
