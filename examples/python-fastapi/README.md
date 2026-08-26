# Python FastAPI Example

Proyecto de ejemplo usando **better-ai** ruleset con FastAPI.

## Quick Start

```bash
# Install uv (si no lo tienes)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync

# Copy env example
cp .env.example .env

# Run dev server
uv run fastapi dev src/main.py

# Run tests
uv run pytest -v

# Lint
uv run ruff check src/

# Type check
uv run mypy src/
```

## Estructura

```
src/
  main.py              # FastAPI app entry
  api/
    routes.py          # API endpoints
    schemas.py         # Pydantic models
  services/
    calculator.py      # Business logic
  core/
    config.py          # Settings (pydantic-settings)
tests/
  test_calculator.py   # Unit tests
  test_api.py          # Integration tests
```

## Endpoints

- `GET /health` - Health check
- `POST /api/v1/calculate` - Calculator operations
  - Operations: `add`, `subtract`, `multiply`, `divide`
- `GET /docs` - Swagger UI (solo development)

## Variables de entorno

Ver `.env.example`:
- `APP_ENV` - development|production
- `SECRET_KEY` - Obligatorio en producción
- `DATABASE_URL` - Opcional
- `CORS_ORIGINS` - Orígenes permitidos