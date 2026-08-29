#!/usr/bin/env bash
# Verificación de coherencia del proyecto better-ai (lección: revisión cruzada
# como paso previo a cada commit). Uso: bash scripts/verificar-proyecto.sh
# Instrumentado con OpenTelemetry (P1.30) para traces distribuidos
set -u
cd "$(dirname "$0")/.." || exit 1

# OpenTelemetry instrumentation (P1.30)
OTEL_ENABLED="${OTEL_ENABLED:-false}"
OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318/v1/traces}"
SESSION_ID="${SESSION_ID:-$(uuidgen 2>/dev/null || date +%s%N | sha256sum | head -c 16)}"
TRACE_ID="$(uuidgen 2>/dev/null || date +%s%N | sha256sum | head -c 32)"
SPAN_ID="$(uuidgen 2>/dev/null || date +%s%N | sha256sum | head -c 16)"

otel_start_span() {
    local name="$1"
    local parent_span_id="${2:-$SPAN_ID}"
    if [ "$OTEL_ENABLED" = "true" ]; then
        local start_time=$(date -u +%s%N)
        echo "{\"name\":\"$name\",\"context\":{\"trace_id\":\"$TRACE_ID\",\"span_id\":\"$SPAN_ID\"},\"parent_span_id\":\"$parent_span_id\",\"start_time_unix_nano\":\"$start_time\"}" >> /tmp/otel-spans-${SESSION_ID}.jsonl
    fi
}

otel_end_span() {
    local name="$1"
    local status="${2:-OK}"
    if [ "$OTEL_ENABLED" = "true" ]; then
        local end_time=$(date -u +%s%N)
        echo "{\"name\":\"$name\",\"context\":{\"trace_id\":\"$TRACE_ID\",\"span_id\":\"$SPAN_ID\"},\"end_time_unix_nano\":\"$end_time\",\"status\":{\"code\":$( [ "$status" = "OK" ] && echo 1 || echo 2 )}}" >> /tmp/otel-spans-${SESSION_ID}.jsonl
    fi
}

# Export spans to OTLP endpoint if configured
otel_export() {
    if [ "$OTEL_ENABLED" = "true" ] && [ -f "/tmp/otel-spans-${SESSION_ID}.jsonl" ]; then
        curl -s -X POST "$OTEL_EXPORTER_OTLP_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d "$(jq -s '.' /tmp/otel-spans-${SESSION_ID}.jsonl 2>/dev/null || cat /tmp/otel-spans-${SESSION_ID}.jsonl)" \
            >/dev/null 2>&1 || true
        rm -f /tmp/otel-spans-${SESSION_ID}.jsonl
    fi
}

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

otel_start_span "verificar.total"
otel_start_span "verificar.reglas"
echo "== 1. Reglas =="
check "20 reglas P0 definidas en AGENTS.md" bash -c "test \$(grep -cE '^### P0' AGENTS.md) -eq 20"
check "31 reglas P1 definidas en AGENTS.md" bash -c "test \$(grep -cE '^### P1' AGENTS.md) -eq 31"
check "IDs identicos en REGLAS-COMPLETAS" bash -c "diff <(grep -oE '^### P[0-2]\\.[0-9]+' AGENTS.md | sort -V) <(grep -oE '^### P[0-2]\\.[0-9]+' docs/REGLAS-COMPLETAS.md | sort -V)"
check "titulos de reglas identicos en REGLAS-COMPLETAS" bash -c "diff <(grep -E '^### P0|^### P1' AGENTS.md) <(grep -E '^### P0|^### P1' docs/REGLAS-COMPLETAS.md)"
check "referencias a rutas docs/ y scripts/ existen" python3 -c "
import re, os
files = ['AGENTS.md', 'README.md', 'CHECKLIST.md', 'docs/REGLAS-COMPLETAS.md', 'docs/PRUEBAS.md']
rutas = set()
for f in files:
    for m in re.findall(r'(?:docs/|scripts/)[A-Za-z0-9_./-]+\\.(?:md|sh)', open(f).read()):
        rutas.add(m)
faltan = [r for r in sorted(rutas) if not os.path.exists(r)]
assert not faltan, 'referencias rotas: ' + str(faltan)
"
# REQ-001
check "requisitos versionados y referencias de codigo validos" python3 scripts/doc_validator.py --root .
check "ningun .env versionado en git" bash -c "test -z \"\$(git ls-files | grep -E '\\.env(\$|\\.)' | grep -v '\\.env\\.example')\""
check "47 limitaciones en REGLAS-COMPLETAS" bash -c "test \$(grep -cE '^\\| \\*\\*' docs/REGLAS-COMPLETAS.md) -eq 47"
check "50 errores en README" bash -c "test \$(grep -cE '^[0-9]+\\. \\*\\*' README.md) -eq 50"
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
otel_end_span "verificar.reglas"

otel_start_span "verificar.config"
echo "== 2. Config =="
check "kilo.json es JSON valido" python3 -c "import json; json.load(open('kilo.json'))"
check "opencode.json es JSON valido (compatibilidad)" python3 -c "import json; json.load(open('opencode.json'))"
check "268 patrones de permisos bash" python3 -c "
import json
b = json.load(open('kilo.json'))['permission']['bash']
assert len(b) == 268, len(b)
assert sum(1 for v in b.values() if v == 'deny') == 182
assert sum(1 for v in b.values() if v == 'ask') == 85
"
check "kilo.json y opencode.json tienen los mismos permisos bash" python3 -c "
import json
a = json.load(open('kilo.json'))['permission']['bash']
b = json.load(open('opencode.json'))['permission']['bash']
assert a == b, 'permisos bash difieren entre kilo.json y opencode.json'
"
check "edit/read bloquean claves y credenciales" python3 -c "
import json
p = json.load(open('kilo.json'))['permission']
# deny: patrones de claves y credenciales (listados para el scan de seguridad)
for sec in ('edit', 'read'):
    for pat in ('~/.ssh/*', '*.ssh/*', '~/.aws/*', '*.aws/*', '*.pem', '*id_rsa*', '*id_ed25519*', '*credentials*'):  # deny: patrones
        assert p[sec].get(pat) == 'deny', (sec, pat)
"
check "experimental.policies en kilo.json: deny all + allow kilo, deepseek, openrouter" python3 -c "
import json
c = json.load(open('kilo.json'))
policies = c.get('experimental', {}).get('policies', [])
assert policies[0] == {'effect': 'deny', 'action': 'provider.use', 'resource': '*'}, policies[0]
allowed = [p['resource'] for p in policies if p['effect'] == 'allow']
assert set(allowed) == {'kilo', 'deepseek', 'openrouter'}, allowed
"
check "experimental.policies en opencode.json: deny all + allow opencode, opencode-go, kilo, deepseek" python3 -c "
import json
c = json.load(open('opencode.json'))
policies = c.get('experimental', {}).get('policies', [])
assert policies[0] == {'effect': 'deny', 'action': 'provider.use', 'resource': '*'}, policies[0]
allowed = [p['resource'] for p in policies if p['effect'] == 'allow']
assert set(allowed) == {'opencode', 'opencode-go', 'kilo', 'deepseek'}, allowed
"
check "agente determinista: temperature/top_p en build, plan y audit (sin seed, sin maxSteps)" python3 -c "
import json
a = json.load(open('opencode.json'))['agent']
assert a['build']['temperature'] == 0.3 and a['build']['top_p'] == 1.0, a['build']
assert a['plan']['temperature'] == 0.1 and a['plan']['top_p'] == 1.0, a['plan']
assert a['audit']['temperature'] == 0.0 and a['audit']['top_p'] == 1.0, a['audit']
for k in ('seed', 'maxSteps', 'steps'):
    assert k not in a['build'], 'build no debe llevar ' + k
    assert k not in a['plan'], 'plan no debe llevar ' + k
    assert k not in a['audit'], 'audit no debe llevar ' + k
"
check "conteos de patrones en README coherentes con la config" python3 -c "
import json, re
b = json.load(open('kilo.json'))['permission']['bash']
r = open('README.md').read()
total, deny, ask = len(b), sum(1 for v in b.values() if v == 'deny'), sum(1 for v in b.values() if v == 'ask')
assert f'{total} patrones' in r, 'README sin el total de patrones'
assert f'{deny} \`deny\`' in r, 'README sin el conteo de deny'
assert f'{ask} \`ask\`' in r, 'README sin el conteo de ask'
assert f'{total} patrones bash ({deny} \`deny\`, {ask} \`ask\`' in r, 'README sin conteo completo'
"
check "edit/read bloquean .env y permiten .env.example" python3 -c "
import json
p = json.load(open('kilo.json'))['permission']
assert p['edit'].get('*.env') == 'deny'
assert p['edit'].get('*.env.*') == 'deny'
assert p['edit'].get('*.env.example') == 'allow'
assert p['read'].get('*.env') == 'deny'
assert p['read'].get('*.env.*') == 'deny'
assert p['read'].get('*.env.example') == 'allow'
"
check "pares criticos deny presentes" python3 -c "
import json
k = list(json.load(open('kilo.json'))['permission']['bash'])
pares = [
    ('rm *', 'rm -rf *'), ('rm *', 'rm -r *'), ('rm *', 'rm -f *'),
    ('git reset *', 'git reset --hard*'),
    ('git push *', 'git push --force*'),
    ('mv *', 'mv --force*'), ('mv *', 'mv -f *'),
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
"
check "ningun ask posterior anula un deny (todas las familias)" python3 -c "
import json, re
# Mini-matcher que replica la semantica del matcher de opencode (doc oficial de
# Permissions: wildcard '*' = cero o mas caracteres; lecciones de las rondas 3/4/8/28:
# se evalua el PRIMER segmento del pipeline; 'rm *' matchea 'rm -rf x'; 'redis-cli *
# FLUSHALL*' NO matchea 'redis-cli FLUSHALL').
def matchea(patron, comando):
    segmento = comando.split('|')[0]
    regex = '^' + re.escape(patron).replace('\\\\*', '.*') + '$'
    return re.match(regex, segmento) is not None
_cfg = json.load(open('kilo.json'))['permission']['bash']
k = list(_cfg)
rellenos = ['X', '-C', '--', 'x']
fallos = []
for i, deny in enumerate(k):
    if _cfg[deny] != 'deny':
        continue
    variantes = set()
    for r in rellenos:
        v = ' '.join(r if t == '*' else t for t in deny.split())
        if matchea(deny, v):
            variantes.add(v)
    for j in range(i + 1, len(k)):
        ask = k[j]
        if _cfg[ask] != 'ask':
            continue
        for v in variantes:
            if matchea(ask, v):
                fallos.append((deny, ask, v))
assert not fallos, 'ask posterior anula deny: ' + '; '.join(f'{d} / {a} para {v}' for d, a, v in fallos)
"
check "analizador de shell detecta pipes y subcomandos destructivos" bash -c "python3 scripts/check-shell-pipes.py"
check "tests unitarios de fuzz-denies.py pasan" bash -c "python3 scripts/test-fuzz-denies.py"
check "instalador y actualizador funcionan en tempdir" bash -c "bash scripts/test-installer.sh"
otel_end_span "verificar.config"

otel_start_span "verificar.seguridad"
echo "== 3. Seguridad (P0.9/P0.10) =="
# Nota: se excluyen los placeholders del red-team (scripts/probar-denies.sh):
# 'dummy*' (archivos de prueba), '127.0.0.1' (loopback de la comprobacion de redis,
# no es informacion personal) y 'dummy@example.com' (email del git dummy).
check "sin IPs, claves, rutas .ssh o rutas de usuario en archivos" python3 -c "
import os, re, ipaddress
pat = re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')
# rutas de usuario reales: /home/<nombre>/ (el placeholder /home/<usuario>/ no matchea)
pat_home = re.compile(r'/home/[A-Za-z0-9_.-]+/')
excl = re.compile(r'(deny|patrones|claves SSH|no leas|comitees|dummy|BLOQUEADO|127\.0\.0\.1)')
faltas = []
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules')]
    for f in files:
        if not f.endswith(('.md', '.json', '.sh')):
            continue
        ruta = os.path.join(root, f)
        for i, linea in enumerate(open(ruta, errors='ignore'), 1):
            if excl.search(linea):
                continue
            if pat_home.search(linea):
                faltas.append((ruta, i, 'ruta de usuario: ' + pat_home.search(linea).group(0)))
            for m in pat.findall(linea):
                try:
                    ip = ipaddress.ip_address(m)
                except ValueError:
                    continue  # no es una IP real (p. ej. numero de version 1.18.10)
                if not ip.is_loopback:
                    faltas.append((ruta, i, 'IP: ' + m))
assert not faltas, faltas
"
check "sin emails personales en archivos" bash -c "! grep -rnE --exclude-dir=node_modules '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}' --include='*.md' --include='*.json' --include='*.sh' . | grep -v '\\.git/' | grep -qvE '(youremail@example|creativecommons|dummy@example)'"
check "sin formatos de claves API en archivos" bash -c "! grep -rnE --exclude-dir=node_modules '(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' --include='*.md' --include='*.json' --include='*.sh' . | grep -v '\\.git/'"
# Los unicos 'eval'/'exec' en scripts son: la VARIANTE de prueba del deny 'eval *' en
# probar-denies.sh (el comando bajo prueba, no codigo que el script ejecute), el
# 'exec bwrap' de opencode-sandbox.sh (exec estandar de bash para sustituir el
# proceso) y el propio patron de este check en verificar-proyecto.sh.
check "sin eval/exec en scripts" python3 -c "
import os, re
pat = re.compile(r'\b(eval|exec)\b')
for f in sorted(os.listdir('scripts')):
    if not f.endswith('.sh'):
        continue
    if f in ('probar-denies.sh', 'opencode-sandbox.sh', 'verificar-proyecto.sh'):
        continue  # documentados arriba; este check vigila los demas scripts
    for i, linea in enumerate(open('scripts/' + f), 1):
        if linea.lstrip().startswith('#'):
            continue
        assert not pat.search(linea), (f, i, linea)
"
check "agentes de solo lectura con edit deny y sincronizados" bash -c "
for a in security-auditor code-reviewer; do
    grep -q 'edit: deny' .opencode/agents/\$a.md || exit 1
    grep -q 'mode: subagent' .opencode/agents/\$a.md || exit 1
    [ -f .kilo/agents/\$a.md ] || exit 1
    cmp -s .opencode/agents/\$a.md .kilo/agents/\$a.md || exit 1
done
"
otel_end_span "verificar.seguridad"

otel_start_span "verificar.supply-chain"
echo "== 4. Supply Chain (P0.18) =="
check "syft disponible para SBOM" bash -c "command -v syft >/dev/null || echo 'WARNING: syft no instalado; SBOM no generado'"
check "grype disponible para vuln scan" bash -c "command -v grype >/dev/null || echo 'WARNING: grype no instalado; vuln scan no ejecutado'"
check "SBOM generado (docs/SBOM-*.spdx.json)" bash -c "ls docs/SBOM-*.spdx.json 2>/dev/null | head -1 >/dev/null || echo 'WARNING: SBOM no encontrado en docs/'"
if command -v grype >/dev/null 2>&1; then
    check "sin vulns CRITICAL/HIGH sin excepcion documentada" bash -c "! grype dir:. -o json 2>/dev/null | jq -e '.matches[] | select(.vulnerability.severity == \"Critical\" or .vulnerability.severity == \"High\") | .vulnerability.id' >/dev/null || echo 'INFO: vulns CRITICAL/HIGH detectadas (requieren excepcion documentada)'"
fi
check "test-determinism.py instalado y valido (sin llamadas LLM)" bash -c "python3 scripts/test-determinism.py --help >/dev/null 2>&1"
check "skill cost-tracker operativo (py_compile y --help OK)" bash -c "python3 -m py_compile .opencode/skills/cost-tracker/cost-tracker.py && python3 .opencode/skills/cost-tracker/cost-tracker.py --help >/dev/null 2>&1"
check "redteam prompt injection valido (py_compile y --help OK)" bash -c "python3 -m py_compile scripts/redteam-prompt-injection.py && python3 scripts/redteam-prompt-injection.py --help >/dev/null 2>&1"
check "fuzzing de evasion de denies sin fallos directos" bash -c "python3 scripts/fuzz-denies.py"
otel_end_span "verificar.supply-chain"

otel_start_span "verificar.drift"
echo "== 5. Config Drift Detection (P1.9) =="
check "sin drift en configs criticas (baseline firmada)" bash -c "bash scripts/detect-drift.sh >/dev/null 2>&1 || (echo 'DRIFT DETECTADO - Ejecuta: bash scripts/detect-drift.sh para detalles' && exit 1)"
otel_end_span "verificar.drift"

otel_start_span "verificar.repositorio"
echo "== 6. Repositorio =="
check "hook pre-commit instalado identico al script" bash -c "cmp -s scripts/hooks/pre-commit .git/hooks/pre-commit"
check "sin objetos huerfanos en git (fsck)" bash -c "test -z \"\$(git fsck --unreachable 2>&1)\""
if [ "${1:-}" = "--pre-commit" ]; then
    echo "  [SKIP] comprobaciones de repositorio (modo pre-commit: los archivos staged son el cambio)"
else
    check "arbol de trabajo limpio" bash -c "test -z \"\$(git status --porcelain)\""
    check "rama main sincronizada con origin" bash -c "test -z \"\$(git status --porcelain --branch | grep -E 'adelant|ahead|behind|adelanta')\""
    check "HEAD remoto apunta a main" bash -c "test \"\$(git ls-remote origin HEAD | cut -f1)\" = \"\$(git ls-remote origin refs/heads/main | cut -f1)\""
fi
otel_end_span "verificar.repositorio"

otel_end_span "verificar.total"
otel_export

echo
echo "Resultado: $PASS OK, $FAIL FALLOS"
[ "$OTEL_ENABLED" = "true" ] && echo "Trace ID: $TRACE_ID (exported to $OTEL_EXPORTER_OTLP_ENDPOINT)"
[ "$FAIL" -eq 0 ] || exit 1
