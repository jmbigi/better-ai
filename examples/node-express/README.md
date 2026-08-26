# Node Express Example

Proyecto de ejemplo usando **better-ai** ruleset con Express.

## Quick Start

```bash
# Install dependencies
npm ci

# Copy env example
cp .env.example .env

# Run dev server
npm run dev

# Run tests
npm test

# Lint
npm run lint
```

## Estructura

```
src/
  index.js              # Express app entry
  routes/
    calculator.js       # Calculator routes
  services/
    calculator.js       # Business logic
  middleware/
    error.js            # Error handling
  config/
    index.js            # Configuration
tests/
  calculator.test.js    # Unit tests
  api.test.js           # Integration tests
```

## Endpoints

- `GET /health` - Health check
- `POST /api/v1/calculate` - Calculator operations
  - Operations: `add`, `subtract`, `multiply`, `divide`