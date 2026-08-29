#!/usr/bin/env bash
# Genera SBOM SPDX del proyecto con syft (P0.18).
# Uso: bash scripts/generate-sbom.sh [dir] [salida]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${1:-${PROJECT_ROOT}}"
OUT_FILE="${2:-${PROJECT_ROOT}/docs/SBOM-$(date -u +%Y%m%d).spdx.json}"

if ! command -v syft >/dev/null 2>&1; then
    echo "[FALLO] syft no esta instalado. Instalalo desde https://github.com/anchore/syft" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"
syft "$TARGET_DIR" -o spdx-json="$OUT_FILE"
echo "[OK] SBOM generado: $OUT_FILE"
