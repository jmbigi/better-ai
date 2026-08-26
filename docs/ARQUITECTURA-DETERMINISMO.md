# ARQUITECTURA-DETERMINISMO — Determinismo y control de generación en better-ai

> Documento de diseño técnico (adoptado 26-08-2026, tras revisar la propuesta
> "Determinismo y Control de Generación en better-ai" del programador).
> Extiende la capa de protección determinista del SO (deny/ask) hacia el motor de
> inferencia (temperature/top_p) como defensa de tres capas:
> **SO → reglas de texto → inferencia**.

## 1. Objetivo

Reducir la varianza estadística de las respuestas del LLM en tareas de misión
crítica (auditorías, revisiones, compliance) y garantizar que la evidencia
producida (P0.1) sea reproducible entre pasos (P1.10).

## 2. Estado verificado del soporte (26-08-2026) — P0.2, P0.1

Verificado contra la documentación oficial de opencode (docs/agents, última
actualización 26-08-2026) y el CLI real (opencode 1.18.23):

| Parámetro | Soporte opencode | Evidencia | Estado |
|---|---|---|---|
| `temperature` (por agente) | ✅ Nativo (JSON + frontmatter MD) | Doc oficial "Options → Temperature" + runtime JSON válido | **Aplicado** |
| `top_p` (por agente) | ✅ Nativo | Doc oficial "Options → Top P" | **Aplicado** |
| `seed` (por agente) | ⚠️ **Ausente del `$schema` oficial** (validado 26-08-2026 con jsonschema): `"seed"` no aparece en el schema, pero el objeto `agent` es abierto (`additionalProperties` no restringido) → **no se rechaza** y se pasaría al proveedor vía "Additional" **sin validación** | jsonschema contra `https://opencode.ai/config.json` (HTTP 200 con UA navegador): `temperature`/`top_p` ✅ presentes; `seed` ❌ ausente pero tolerado | **PENDIENTE verificación empírica** (ver §6) |
| `steps` (límite de iteraciones) | ✅ Nativo (`steps`; `maxSteps` **DEPRECIADO**) | Doc oficial "Options → Max steps" | No aplicado (no necesario) |
| `model` (por agente) | ✅ Nativo | Doc oficial "Options → Model" | No aplicado (no forzar; sigue config global) |
| `tools:` en frontmatter MD | ⚠️ DEPRECIADO → usar `permission` | Doc oficial "Options → Tools (deprecated)" | Nuestros subagentes ya usan `permission` (correcto) |
| Bloque `agent` en `kilo.json` | ❌ Sin evidencia de soporte | $schema de kilo no verificado | **NO aplicado** — solo en `opencode.json` |

> **Nota (26-08-2026)**: la propuesta original usaba `maxSteps` y
> `tools: {write: false}` en sus ejemplos; ambos están deprecados en la doc
> oficial actual → el plan se ajustó (`steps`/`permission`).

## 3. Perfiles de muestreo por rol (aplicado)

| Rol / Agente | temperature | top_p | Tipo de operación |
|---|---|---|---|
| `build` (primario) | 0.3 | 1.0 | Generativa (implementar, refactor) |
| `plan` (primario) | 0.1 | 1.0 | Análisis/planificación |
| `security-auditor` (subagente) | 0.0 | 1.0 | Crítica (auditoría) |
| `code-reviewer` (subagente) | 0.0 | 1.0 | Crítica (revisión) |
| `compliance-checker` (subagente) | 0.0 | 1.0 | Crítica (compliance) |
| `dependency-auditor` (subagente) | 0.0 | 1.0 | Crítica (supply chain) |
| `cost-optimizer` (subagente) | 0.1 | 1.0 | Análisis |

**Decisión (26-08-2026, programador)**: opción mínima — sin regla P0/P1 nueva;
el determinismo entra como safeguard listado en **P1.9** y como configuración
operativa. No se añade P1.31 porque `temperature`/`top_p` no previenen una clase
de error nueva (la varianza entre pasos ya está cubierta por P0.1 y P1.10) y una
regla extra diluiría las existentes (fuente Anthropic 5: no sobreconstreñir).

## 4. Implementación

### 4.1 Configuraciones afectadas

- `opencode.json` → bloque `agent` (`build`, `plan`), sin `model` ni `seed` ni `steps`.
- `.opencode/agents/*.md` → frontmatter `temperature`/`top_p` (5 subagentes).
- `scripts/verificar-proyecto.sh` → check "agente determinista" (valida presencia,
  valores, y **ausencia** de `seed`/`maxSteps` mientras la verificación esté pendiente).
- `kilo.json` / `.kilo/kilo.json` → **NO modificados** (sin evidencia de soporte
  del bloque `agent`; pendiente de verificación con su $schema).

### 4.2 Principio de no-romper coexistentes

- La config global sigue permitiendo `enabled_providers`/policies (deny all +
  allow list) — sin cambios.
- Los subagentes mantienen `permission` (edit/bash deny) — sin cambios.

## 5. Test de determinismo (`scripts/test-determinism.py`)

Alineado a la propuesta (EMR ≥ 95 %) con las reglas del proyecto:

- 10 ejecuciones del mismo prompt sintético complejo **por defecto** (`--runs 10`).
- EMR (Exact Match Ratio) tras normalización; umbral de varianza 5 %: **fail fast**.
- `--model` (por defecto `opencode-go/deepseek-v4-flash`, o el que el programador indique).
- **Falla explícito** si la API devuelve error (nunca "skip" silencioso, P0.1/P1.19).
- Reporta tiempo y coste estimado (P0.19).
- **Ejecución: PENDIENTE** — el 26-08-2026 todos los modelos permitidos devolvían
  error de servicio (evidencia: `opencode-go/deepseek-v4-flash` → 401 límite mensual;
  `opencode/deepseek-v4-flash-free` → UnknownError; `deepseek/deepseek-chat` →
  UnknownError). No se reporta EMR inventado (P0.1); se re-ejecutará con servicio
  disponible.

## 6. Verificación de `seed` (pendiente — decisión C2-primero)

1. **No se añade `seed` a configs** hasta una prueba empírica:
   `test-determinism.py` con y sin `seed`, comparando EMR.
2. Si EMR con `seed` > EMR sin `seed` **y** la API lo acepta sin error → añadir a
   configs (ronda 2) + documentar.
3. Si EMR idéntico o API lo ignora → declarar limitación (patrón de las rondas
   27-28: los parámetros no verificados no se reclaman).
4. Si la API rechaza el parámetro → `test-determinism.py` falla explícito
   (P1.19: excepción bloqueante, no fallback silencioso).

## 7. Limitaciones declaradas

- `temperature=0.0` **no** garantiza salidas bit a bit (FP no asociativo en GPUs,
  arquitecturas MoE; doc oficial de proveedores). La tríada completa requiere
  `seed` verificado (pendiente, §6).
- Los subagentes Markdown heredan el modelo del agente principal (doc oficial);
  el frontmatter no fija modelo → el perfil de determinismo aplica al sampling,
  no al router de modelos.
- `kilo.json` sin soporte verificado del bloque `agent` (§2).

## 8. Fuentes verificadas (26-08-2026)

- opencode Docs — Agents (Options: Temperature, Top P, Max steps/steps, Model,
  Tools deprecated, Additional): https://opencode.ai/docs/agents/
- opencode CLI 1.18.23 real (`opencode run --help`): sin flags `--seed`/
  `--temperature` → se configuran vía JSON/frontmatter.
- Propuesta del programador: "Determinismo y Control de Generación en better-ai"
  (PDF, 5 págs, revisada 26-08-2026).
