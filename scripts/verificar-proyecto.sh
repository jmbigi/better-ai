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
check "12 reglas P0 definidas en AGENTS.md" bash -c "test \$(grep -cE '^### P0' AGENTS.md) -eq 12"
check "12 reglas P1 definidas en AGENTS.md" bash -c "test \$(grep -cE '^### P1' AGENTS.md) -eq 12"
check "IDs identicos en REGLAS-COMPLETAS" bash -c "diff <(grep -oE '^### P[0-2]\\.[0-9]+' AGENTS.md | sort -V) <(grep -oE '^### P[0-2]\\.[0-9]+' docs/REGLAS-COMPLETAS.md | sort -V)"
check "titulos de reglas identicos en REGLAS-COMPLETAS" bash -c "diff <(grep -E '^### P0|^### P1' AGENTS.md) <(grep -E '^### P0|^### P1' docs/REGLAS-COMPLETAS.md)"
check "referencias a rutas docs/ y scripts/ existen" python3 -c "
import re, os
files = ['AGENTS.md', 'README.md', 'CHECKLIST.md', 'docs/REGLAS-COMPLETAS.md', 'docs/PRUEBAS.md']
rutas = set()
for f in files:
    for m in re.findall(r'(?:docs/|scripts/)[A-Za-z0-9_./-]+\.(?:md|sh)', open(f).read()):
        rutas.add(m)
faltan = [r for r in sorted(rutas) if not os.path.exists(r)]
assert not faltan, 'referencias rotas: ' + str(faltan)
"
check "ningun .env versionado en git" bash -c "test -z \"\$(git ls-files | grep -E '\\.env(\$|\\.)' | grep -v '\\.env\\.example')\""
check "26 limitaciones en REGLAS-COMPLETAS" bash -c "test \$(grep -cE '^\\| \\*\\*' docs/REGLAS-COMPLETAS.md) -eq 26"
check "26 errores en README" bash -c "test \$(grep -cE '^[0-9]+\\. \\*\\*' README.md) -eq 26"
check "IDs citados en CHECKLIST existen en AGENTS.md" bash -c "test -z \"\$(comm -23 <(grep -oE 'P[0-2]\\.[0-9]+' CHECKLIST.md | sort -u) <(grep -oE 'P[0-2]\\.[0-9]+' AGENTS.md | sort -u))\""
check "IDs citados en README existen en AGENTS.md" bash -c "test -z \"\$(comm -23 <(grep -oE 'P[0-2]\\.[0-9]+' README.md | sort -u) <(grep -oE 'P[0-2]\\.[0-9]+' AGENTS.md | sort -u))\""
check "numeracion secuencial de pruebas en PRUEBAS" python3 -c "
import re
nums = [int(m) for m in re.findall(r'^\\| (\\d+) \\|', open('docs/PRUEBAS.md').read(), re.M)]
assert nums == list(range(1, len(nums) + 1)), 'pruebas no secuenciales'
"
check "pruebas citadas en LECCIONES existen en PRUEBAS" python3 -c "
import re
citadas = set(int(m) for m in re.findall(r'pruebas? (\\d+)', open('docs/LECCIONES-APRENDIDAS.md').read()))
existentes = set(int(m) for m in re.findall(r'^\\| (\\d+) \\|', open('docs/PRUEBAS.md').read(), re.M))
assert citadas <= existentes, 'lecciones citan pruebas inexistentes: ' + str(citadas - existentes)
"

echo "== 2. Config =="
check "opencode.json es JSON valido" python3 -c "import json; json.load(open('opencode.json'))"
check "175 patrones de permisos" python3 -c "
import json
b = json.load(open('opencode.json'))['permission']['bash']
assert len(b) == 175, len(b)
assert sum(1 for v in b.values() if v == 'deny') == 89
assert sum(1 for v in b.values() if v == 'ask') == 85
"
check "enabled_providers restringe a opencode y opencode-go" python3 -c "
import json
c = json.load(open('opencode.json'))
assert c.get('enabled_providers') == ['opencode', 'opencode-go'], c.get('enabled_providers')
"
check "edit/read bloquean .env y permiten .env.example" python3 -c "
import json
p = json.load(open('opencode.json'))['permission']
assert p['edit'].get('*.env') == 'deny'
assert p['edit'].get('*.env.*') == 'deny'
assert p['edit'].get('*.env.example') == 'allow'
assert p['read'].get('*.env') == 'deny'
assert p['read'].get('*.env.*') == 'deny'
assert p['read'].get('*.env.example') == 'allow'
"
check "deny despues de ask en familias criticas" python3 -c "
import json
k = list(json.load(open('opencode.json'))['permission']['bash'])
pares = [
    ('rm *', 'rm -rf *'), ('rm *', 'rm -r *'), ('rm *', 'rm -f *'),
    ('git reset *', 'git reset --hard*'),
    ('git push *', 'git push --force*'),
    ('mv *', 'mv --force*'), ('mv *', 'mv -f *'),
    ('rsync *', 'rsync --delete*'),
    ('docker compose down*', 'docker compose down -v*'),
    ('pip install *', 'pip install --user *'),
    ('psql -c *', 'psql * *DROP*'), ('psql -c *', 'psql * *TRUNCATE*'),
    ('psql -c *', 'psql * *DELETE*'), ('psql -c *', 'psql * *ALTER*'),
    ('mysql -e *', 'mysql * *DROP*'), ('mysql -e *', 'mysql * *TRUNCATE*'),
    ('mysql -e *', 'mysql * *DELETE*'), ('mysql -e *', 'mysql * *ALTER*'),
    ('sqlite3 *', 'sqlite3 * *DROP*'), ('sqlite3 *', 'sqlite3 * *TRUNCATE*'),
    ('sqlite3 *', 'sqlite3 * *DELETE*'), ('sqlite3 *', 'sqlite3 * *ALTER*'),
    ('redis-cli *', 'redis-cli FLUSHALL*'),
    ('redis-cli *', 'redis-cli * FLUSHALL*'),
    ('redis-cli *', 'redis-cli * *DEL*'),
]
for ask, deny in pares:
    assert ask in k, 'falta ask: ' + ask
    assert deny in k, 'falta deny: ' + deny
    assert k.index(ask) < k.index(deny), 'deny antes que ask: ' + ask + ' / ' + deny
"

echo "== 3. Seguridad (P0.9/P0.10) =="
check "sin IPs, claves o rutas .ssh en archivos" bash -c "! grep -rnE '(id_rsa|id_ed25519|\\.ssh/|known_hosts|([0-9]{1,3}\\.){3}[0-9]{1,3})' --include='*.md' --include='*.json' --include='*.sh' --include='.gitignore' . | grep -v '\\.git/' | grep -qvE '(deny|patrones|claves SSH|no leas|comitees)'"
check "sin emails personales en archivos" bash -c "! grep -rnE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}' --include='*.md' --include='*.json' --include='*.sh' . | grep -v '\\.git/' | grep -qvE '(youremail@example|creativecommons)'"

echo "== 4. Repositorio =="
check "hook pre-commit instalado identico al script" bash -c "cmp -s scripts/hooks/pre-commit .git/hooks/pre-commit"
check "sin objetos huerfanos en git (fsck)" bash -c "test -z \"\$(git fsck --unreachable 2>&1)\""
if [ "${1:-}" = "--pre-commit" ]; then
    echo "  [SKIP] comprobaciones de repositorio (modo pre-commit: los archivos staged son el cambio)"
else
    check "arbol de trabajo limpio" bash -c "test -z \"\$(git status --porcelain)\""
    check "rama main sincronizada con origin" bash -c "test -z \"\$(git status --porcelain --branch | grep -E 'adelant|ahead|behind|adelanta')\""
    check "HEAD remoto apunta a main" bash -c "git ls-remote origin | awk '/HEAD/{print \$2}' | grep -q '^refs/heads/main\$'"
fi

echo
echo "Resultado: $PASS OK, $FAIL FALLOS"
[ "$FAIL" -eq 0 ] || exit 1
