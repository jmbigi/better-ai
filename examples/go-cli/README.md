# Go CLI Example

Proyecto de ejemplo usando **better-ai** ruleset con Go CLI.

## Quick Start

```bash
# Build
go build -o bin/calculator ./cmd/calculator

# Run
./bin/calculator add -a 10 -b 5
./bin/calculator divide -a 10 -b 3

# Or run directly
go run ./cmd/calculator add -a 10 -b 5

# Test
go test -v ./...

# Vet
go vet ./...

# Lint (requires golangci-lint)
golangci-lint run
```

## Estructura

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
```

## Comandos

- `add -a <float> -b <float>` - Suma
- `subtract -a <float> -b <float>` - Resta
- `multiply -a <float> -b <float>` - Multiplicación
- `divide -a <float> -b <float>` - División

## Variables de entorno

- `CALCULATOR_FORMAT` - `text`|`json` (default: text)
- `CALCULATOR_DEBUG` - `true`|`false` (default: false)

## Ejemplos

```bash
calculator add -a 10 -b 5
# Output: 15

calculator divide -a 10 -b 3
# Output: 3.3333333333333335

CALCULATOR_FORMAT=json calculator multiply -a 6 -b 7
# Output: {"result":42,"operation":"multiply"}
```