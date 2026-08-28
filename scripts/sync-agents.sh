#!/usr/bin/env bash
# Sincroniza .kilo/agents con .opencode/agents de forma multiplataforma.
# Elimina el symlink legacy si existe y lo reemplaza por una copia.
# Uso: bash scripts/sync-agents.sh
set -u
cd "$(dirname "$0")/.." || exit 1

ORIGEN=".opencode/agents"
DESTINO=".kilo/agents"

if [ ! -d "$ORIGEN" ]; then
    echo "[FALLO] No existe $ORIGEN"
    exit 1
fi

# Si el destino es un symlink, lo eliminamos (legacy)
if [ -L "$DESTINO" ]; then
    rm "$DESTINO"
    echo "[INFO] Symlink legacy $DESTINO eliminado"
fi

# Seguridad: nunca operar sobre rutas vacias o absolutas inesperadas
if [ -z "$DESTINO" ] || [ "${DESTINO#/}" != "$DESTINO" ]; then
    echo "[FALLO] DESTINO invalido: $DESTINO"
    exit 1
fi

# Si es un directorio, vaciamos su contenido en lugar de eliminar el directorio
if [ -d "$DESTINO" ]; then
    rm -rf "${DESTINO:?}"/*
fi

mkdir -p "$DESTINO"
cp -r "$ORIGEN"/* "$DESTINO"/

echo "[OK] $DESTINO sincronizado desde $ORIGEN"
