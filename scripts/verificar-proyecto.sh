#!/usr/bin/env bash
# Verificación de coherencia del proyecto better-ai (lección: revisión cruzada
# como paso previo a cada commit). Uso: bash scripts/verificar-proyecto.sh
set -u
cd "$(dirname "$0")/.." || exit 1

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

echo "== 1. Reglas =="
check "23 reglas definidas en AGENTS.md" bash -c "test \$(grep -cE '^### P' AGENTS.md) -eq 23"
check "IDs identicos en REGLAS-COMPLETAS" bash -c "diff <(grep -oE '^### P[0-2]\\.[0-9]+' AGENTS.md | sort -V) <(grep -oE '^### P[0-2]\\.[0-9]+' docs/REGLAS-COMPLETAS.md | sort -V)"
check "25 limitaciones en REGLAS-COMPLETAS" bash -c "test \$(grep -cE '^\\| \\*\\*' docs/REGLAS-COMPLETAS.md) -eq 25"
check "25 errores en README" bash -c "test \$(grep -cE '^[0-9]+\\. \\*\\*' README.md) -eq 25"

echo "== 2. Config =="
check "opencode.json es JSON valido" python3 -c "import json; json.load(open('opencode.json'))"
check "162 patrones de permisos" python3 -c "
import json
b = json.load(open('opencode.json'))['permission']['bash']
assert len(b) == 162, len(b)
assert sum(1 for v in b.values() if v == 'deny') == 76
assert sum(1 for v in b.values() if v == 'ask') == 85
"
check "edit/read bloquean .env" python3 -c "
import json
p = json.load(open('opencode.json'))['permission']
assert p['edit'].get('*.env') == 'deny'
assert p['read'].get('*.env') == 'deny'
"

echo "== 3. Seguridad (P0.9/P0.10) =="
check "sin IPs, claves o rutas .ssh en archivos" bash -c "! grep -rnE '(id_rsa|id_ed25519|\\.ssh/|known_hosts|([0-9]{1,3}\\.){3}[0-9]{1,3})' --include='*.md' --include='*.json' --include='*.sh' --include='.gitignore' . | grep -v '\\.git/' | grep -qvE '(deny|patrones|claves SSH|no leas|comitees)'"
check "sin emails personales en archivos" bash -c "! grep -rnE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}' --include='*.md' --include='*.json' --include='*.sh' . | grep -v '\\.git/' | grep -qvE '(youremail@example|creativecommons)'"

echo "== 4. Repositorio =="
if [ "${1:-}" = "--pre-commit" ]; then
    echo "  [SKIP] comprobaciones de repositorio (modo pre-commit: los archivos staged son el cambio)"
else
    check "arbol de trabajo limpio" bash -c "test -z \"\$(git status --porcelain)\""
    check "rama main sincronizada con origin" bash -c "test -z \"\$(git status --porcelain --branch | grep -E 'adelant|ahead|behind|adelanta')\""
fi

echo
echo "Resultado: $PASS OK, $FAIL FALLOS"
[ "$FAIL" -eq 0 ] || exit 1
