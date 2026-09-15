#!/usr/bin/env bash
# Verifica las políticas OPA/Rego de better-ai.
# Si opa no está en PATH, intenta usar una copia local en .tools/opa o descargarla
# a /tmp para la verificación. No modifica el sistema operativo (P0.5).
set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPA_BIN="${OPA_BIN:-}"

if [ -z "$OPA_BIN" ]; then
    if command -v opa >/dev/null 2>&1; then
        OPA_BIN="opa"
    elif [ -x "$PROJECT_ROOT/.tools/opa" ]; then
        OPA_BIN="$PROJECT_ROOT/.tools/opa"
    elif [ -x "/tmp/opa" ]; then
        OPA_BIN="/tmp/opa"
    fi
fi

if [ -z "$OPA_BIN" ]; then
    echo "[SKIP] opa no está disponible. Políticas Rego no verificadas en runtime."
    echo "       Para habilitar: descarga opa desde https://github.com/open-policy-agent/opa/releases"
    echo "       y colócalo en PATH, en .tools/opa o define OPA_BIN."
    exit 0
fi

echo "[INFO] Verificando políticas OPA con: $OPA_BIN"
cd "$PROJECT_ROOT" || exit 1
"$OPA_BIN" test policies/ -v
