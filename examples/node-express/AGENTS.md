# Node Express Example — better-ai Project Rules

Este es un proyecto de ejemplo que usa better-ai como base de reglas.

## Reglas específicas del proyecto (añadir a AGENTS.md)

### Comandos de build/test
- Install deps: `npm ci`
- Run dev: `npm run dev`
- Run tests: `npm test`
- Lint: `npm run lint`
- Type check: `npm run typecheck` (si usas TypeScript)

### Convenciones de código
- Node.js 20+ (LTS)
- ES Modules (`"type": "module"` en package.json)
- ESLint + Prettier
- Tests con Jest
- Imports relativos con `@/` alias

### Estructura
```
src/
  index.js           # Express app entry
  routes/
    calculator.js    # Calculator routes
  services/
    calculator.js    # Business logic
  middleware/
    error.js         # Error handling
  config/
    index.js         # Configuration
tests/
  calculator.test.js
  api.test.js
```

### Gotchas
- Usa `npm ci` en CI para instalar exact versions
- `.env` para secrets (ver `.env.example`)
- ESLint config en `eslint.config.js` (flat config)
- Jest config en `jest.config.js`