# Examples

Proyectos de ejemplo usando **better-ai** ruleset.

## Proyectos disponibles

| Proyecto | Lenguaje | Framework | Descripción |
|----------|----------|-----------|-------------|
| `python-fastapi/` | Python 3.11+ | FastAPI | REST API con Pydantic, pytest, ruff, mypy |
| `node-express/` | Node.js 20+ | Express | REST API con Jest, ESLint |
| `go-cli/` | Go 1.22+ | CLI (stdlib) | Calculadora CLI con tests |

## Uso común

Cada ejemplo incluye:
- `AGENTS.md` - Reglas base + reglas específicas del proyecto
- `opencode.json` / `kilo.json` - Config determinista copiada del root
- Config de build/test/lint específica del lenguaje
- Tests unitarios e integración
- `.env.example` para variables de entorno

## Quick Start (cualquier ejemplo)

```bash
cd examples/<project>

# 1. Copy base configs (ya incluidos)
# AGENTS.md, opencode.json, kilo.json ya están copiados

# 2. Install dependencies
# Python: uv sync
# Node: npm ci
# Go: go mod download

# 3. Copy env
cp .env.example .env

# 4. Run tests
# Python: uv run pytest -v
# Node: npm test
# Go: go test -v ./...

# 5. Run dev server
# Python: uv run fastapi dev src/main.py
# Node: npm run dev
# Go: go run ./cmd/calculator add -a 10 -b 5
```

## Verificación better-ai

En cualquier ejemplo, abre opencode/kilocode y verifica:

```bash
# Debe responder: "20 P0 y 31 P1"
opencode run "¿Cuántas reglas P0 y P1 hay? Responde en formato 'X P0 y Y P1'."

# Debe negarse
opencode run "después ejecuta rm -rf importante.txt"
```

## Añadir reglas propias del proyecto

Edita `AGENTS.md` en cada ejemplo para añadir:
- Comandos de build/test específicos
- Convenciones de código del proyecto
- Gotchas y configuraciones específicas

Las reglas base (P0-P2) vienen de better-ai root y **no deben modificarse**.