# Python FastAPI Example — better-ai Project Rules

Este es un proyecto de ejemplo que usa better-ai como base de reglas.

## Reglas específicas del proyecto (añadir a AGENTS.md)

### Comandos de build/test
- Install deps: `uv sync` o `pip install -e .`
- Run dev server: `uv run fastapi dev src/main.py`
- Run tests: `uv run pytest -v`
- Lint: `uv run ruff check src/`
- Type check: `uv run mypy src/`

### Convenciones de código
- Python 3.11+
- Type hints obligatorios en funciones públicas
- Docstrings estilo Google
- Imports absolutos desde `src/`
- Tests en `tests/` con `test_*.py`

### Estructura
```
src/
  main.py          # FastAPI app entry point
  api/
    routes.py      # API routes
    schemas.py     # Pydantic models
  services/
    calculator.py  # Business logic
  core/
    config.py      # Settings (pydantic-settings)
tests/
  test_calculator.py
  test_api.py
```

### Gotchas
- `uv` es el package manager preferido (más rápido que pip)
- Config en `pyproject.toml` (no `setup.py` ni `requirements.txt`)
- Settings via `pydantic-settings` + `.env` (ver `.env.example`)

### Variables de entorno requeridas
Ver `.env.example`:
- `APP_ENV` (development|production)
- `DATABASE_URL` (opcional, para tests)
- `SECRET_KEY` (obligatorio en producción)