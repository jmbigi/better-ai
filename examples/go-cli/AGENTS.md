# Go CLI Example — better-ai Project Rules

Este es un proyecto de ejemplo que usa better-ai como base de reglas.

## Reglas específicas del proyecto (añadir a AGENTS.md)

### Comandos de build/test
- Build: `go build -o bin/calculator ./cmd/calculator`
- Run: `go run ./cmd/calculator add 2 3`
- Test: `go test -v ./...`
- Lint: `golangci-lint run`
- Vet: `go vet ./...`

### Convenciones de código
- Go 1.22+
- Standard library preferred
- Error handling explícito (no panic)
- Tests con `testing` package
- `go:generate` para mocks si necesario

### Estructura
```
cmd/
  calculator/
    main.go           # CLI entry point
internal/
  calculator/
    calculator.go     # Business logic
    calculator_test.go
  config/
    config.go         # Configuration
tests/
  integration_test.go
```

### Gotchas
- `go.mod` define module name
- Config via env vars (ver `.env.example`)
- CLI flags con `flag` package o `cobra` (aquí `flag` simple)
- Tests en `_test.go` files junto al código