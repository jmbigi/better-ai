---
name: cost-tracker
description: Rastrea uso de tokens, coste estimado, latencia y modelo por sesión/llamada
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: observability
---

## Qué hace

Instrumenta y reporta métricas de consumo por sesión de opencode:
- **Tokens**: input + output totales, por llamada, por modelo
- **Coste estimado USD**: basado en pricing público de proveedores permitidos
- **Latencia**: p50, p95, p99 por llamada
- **Modelo(s) usado(s)**: tracking de switches de modelo

## Cuándo usarme

- Al inicio de cada sesión (auto-inicio via hook/skill)
- Al final de cada tarea (reporte obligatorio en checklist P0.19)
- Para alertas de umbral (80% warning, 100% bloqueo)
- Para optimización de routing de modelos

## Cómo usarme

```bash
# Desde opencode (auto-ejecutado via hook pre-task)
skill cost-tracker start

# Durante la tarea: logging automático por cada llamada al modelo

# Al final de la tarea
skill cost-tracker report

# Ver métricas acumuladas
cat /tmp/opencode/cost-tracker-$(date +%F).jsonl
```

## Implementación (P0.19 + P1.30)

### Hooks de instrumentación
- `opencode.json` → `hooks` (pre-tool, post-tool para model calls)
- Skills pueden registrar via `bash` tool calls a script collector

### Colector de métricas (JSONL)
```json
{
  "timestamp": "2026-08-26T10:30:00Z",
  "session_id": "abc123",
  "model": "opencode-go/deepseek-v4-flash",
  "tokens_in": 1500,
  "tokens_out": 800,
  "cost_usd": 0.00023,
  "latency_ms": 1250,
  "call_type": "chat"
}
```

### Umbrales por defecto (configurables)
| Métrica | Warning (80%) | Block (100%) | Acción |
|---------|---------------|--------------|--------|
| Tokens totales | 800K | 1M | Alerta / Requiere confirmación |
| Coste USD | $4.00 | $5.00 | Alerta / Requiere confirmación |
| Tiempo sesión | 24 min | 30 min | Alerta / Requiere confirmación |

### Modelos permitidos y pricing (approx)
| Modelo | Input $/1M | Output $/1M |
|--------|-----------|------------|
| opencode/deepseek-v4-flash-free | $0.00 | $0.00 |
| opencode-go/deepseek-v4-flash | $0.14 | $0.28 |
| deepseek/deepseek-chat | $0.14 | $0.28 |
| kilo-auto/free | $0.00 | $0.00 |
| kilo-auto/efficient | $0.14 | $0.28 |

## Reportes

### Al final de cada tarea (obligatorio P0.19)
```
=== COST REPORT ===
Session: abc123 | Duration: 12m 34s
Model: opencode-go/deepseek-v4-flash (100%)
Tokens: 45,230 in + 18,920 out = 64,150 total
Cost: $0.0123 USD
Latency: p50=890ms p95=2.1s p99=4.5s
Thresholds: 6.4% tokens, 0.2% cost, 42% time → OK
```

### Alerta de umbral
```
⚠️ WARNING: 85% token threshold reached (850K/1M)
   Recommendation: switch to free model or request continuation
```

### Bloqueo de umbral
```
🛑 BLOCKED: 100% token threshold reached (1M/1M)
   Required: explicit confirmation "Confirmo continuar sesion"
   Action: session paused until human approval
```

## Integración

- **P0.19 checklist**: "¿Respeté límites tokens/coste/tiempo? ¿Alerté/bloqueé?"
- **P1.30 observabilidad**: traces correlacionados con request IDs
- **Subagentes**: heredan session_id para tracking unificado
- **Export**: JSONL → Arize Phoenix / Jaeger / local analysis

## Salida

- Archivo JSONL: `/tmp/opencode/cost-tracker-YYYY-MM-DD.jsonl`
- Resumen en consola al final de tarea
- Alerta visible si umbrales superados