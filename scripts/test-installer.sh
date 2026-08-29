#!/usr/bin/env bash
# Prueba basica del instalador/actualizador de better-ai.
# Uso: bash scripts/test-installer.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

DEST="$(mktemp -d '/tmp/better-ai install test-XXXXXX')"
export DEST
trap 'rm -rf "$DEST"' EXIT

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  [OK] $desc"
        PASS=$((PASS + 1))
    else
        echo "  [FALLO] $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "== Test del instalador better-ai =="
echo "Destino temporal: $DEST"

check "instalador crea archivos esenciales" bash scripts/install-better-ai.sh "$DEST"
check "AGENTS.md copiado" test -f "$DEST/AGENTS.md"
check "opencode.json copiado" test -f "$DEST/opencode.json"
check "kilo.json copiado" test -f "$DEST/kilo.json"
check "manifesto creado" test -f "$DEST/.better-ai.manifest"
check "agentes .opencode copiados" test -f "$DEST/.opencode/agents/security-auditor.md"
check "agentes .kilo copiados" test -f "$DEST/.kilo/agents/security-auditor.md"
check "skills .opencode copiados" test -f "$DEST/.opencode/skills/cost-tracker/cost-tracker.py"
check "scripts copiados" test -x "$DEST/scripts/verificar-proyecto.sh"
check "docs/QUICKSTART.md copiado" test -f "$DEST/docs/QUICKSTART.md"
check "scripts/generate-sbom.sh copiado" test -x "$DEST/scripts/generate-sbom.sh"

check "actualizador respalda y actualiza" bash scripts/update-better-ai.sh "$DEST"
check "backup creado" bash -c 'ls -d "$DEST"/.better-ai-backup-* >/dev/null 2>&1'
check "manifesto actualizado" bash -c 'grep -q "^previous_commit:" "$DEST/.better-ai.manifest"'

echo
if [ "$FAIL" -eq 0 ]; then
    echo "$PASS OK, $FAIL FALLOS"
    exit 0
else
    echo "$PASS OK, $FAIL FALLOS"
    exit 1
fi
