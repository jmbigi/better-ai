---
name: red-team-denies
description: Ejecuta red-team automatizado de los 159 deny patterns contra el matcher REAL de opencode
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: security
---

## Qué hace

Ejecuta `scripts/probar-denies.sh` que prueba cada uno de los 159 patrones `deny` de `opencode.json`/`kilo.json` contra el **matcher real de opencode** (config mínima aislada, sin AGENTS.md) con variantes canónicas seguras (dummies en /tmp, --help/--version, puertos inexistentes).

## Cuándo usarme

- Tras cualquier cambio en `permission.bash` de opencode.json/kilo.json
- Antes de releases para regression testing de deny patterns
- Para validar que nuevos deny patterns funcionan realmente
- Como gate de seguridad en CI/CD

## Cómo usarme

```bash
# Desde opencode
skill red-team-denies

# O manualmente
bash scripts/probar-denies.sh
```

## Metodología (lecciones de rondas 3, 27-28, 38)

1. **Config mínima aislada**: Solo `*: allow` + los denies del lote a probar, SIN AGENTS.md
2. **Una sesión por lote**: `opencode run --auto --format json` por cada deny
3. **Parseo de eventos reales**: `part.state.status == "error"` con "prevents you" = BLOQUEADO
4. **Validación estática previa**: Mini-matcher fiel a doc oficial (wildcard `*` = cero o más chars, primer segmento pipeline)
5. **Pase de reintento único**: Para inconclusos (el LLM se detiene tras 2 denegaciones)

## Variantes probadas (154 canónicas + 5 STATIC documentados)

- Formas `--help`/`--version` para comandos de impacto sistémico
- Dummies en `/tmp/opencode/redteam-*`
- Puertos inexistentes para comandos de red
- Comandos inofensivos si un deny fallara

## Resultados esperados

- **154/154 BLOQUEADOS** por el matcher real
- **0 NO BLOQUEADOS**
- **0 INCONCLUSOS**
- 5 STATIC documentados (4 denies con `\|` + `npx prisma migrate reset*`)

## Limitación conocida (rondas 27-28, 38)

Los patrones con `|` (pipe) **NO matchean** en opencode 1.18.x:
- `curl * | bash*`, `curl * | sh*`, `wget * | bash*`, `wget * | sh*`
- Causa: matcher evalúa solo PRIMER segmento del pipeline
- Defensa real: regla de texto P0.8 (AGENTS.md)

## Salida

Reporte conservado en `/tmp/opencode/redteam-evidencia-YYYYMMDD.txt` (154 líneas OK)