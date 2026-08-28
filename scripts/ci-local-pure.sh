#!/usr/bin/env bash
# CI local pura: ejecuta el pipeline de verificacion sin Docker, act ni Dagger.
# Uso: bash scripts/ci-local-pure.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    echo "== $desc =="
    if "$@"; then
        echo "[OK] $desc"
        PASS=$((PASS + 1))
    else
        echo "[FALLO] $desc"
        FAIL=$((FAIL + 1))
    fi
}

# Lint: shellcheck es opcional; si no esta instalado, se reporta como warning.
if command -v shellcheck >/dev/null 2>&1; then
    check "shellcheck scripts/*.sh" shellcheck --severity=error scripts/*.sh
else
    echo "[WARNING] shellcheck no instalado; se omite (instalar para lint completo)"
fi

check "validacion JSON de configs" bash -c "python3 -m json.tool opencode.json >/dev/null && python3 -m json.tool kilo.json >/dev/null"
check "suite de tests" make test
check "verificacion de proyecto (pre-commit)" bash scripts/verificar-proyecto.sh --pre-commit

echo
echo "Resultado CI local: $PASS OK, $FAIL FALLOS"
[ "$FAIL" -eq 0 ] || exit 1
