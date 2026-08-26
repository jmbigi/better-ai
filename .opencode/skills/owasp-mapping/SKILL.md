---
name: owasp-mapping
description: Verifica cobertura del ruleset contra OWASP GenAI LLM Top 10 2026 y MITRE ATLAS
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: compliance
---

## Qué hace

Verifica y reporta la cobertura del ruleset better-ai frente a:
1. **OWASP GenAI LLM Top 10 2026** (fuente 22, HTTP 200 verificado 15-08-2026)
2. **MITRE ATLAS** tácticas relevantes (fuente 24, HTTP 200 verificado 15-08-2026)

## Cuándo usarme

- Tras añadir/modificar reglas P0/P1
- Para auditorías de compliance
- Antes de releases para certificar cobertura
- Cuando el programador pide "estado de cobertura OWASP"

## Cómo usarme

```bash
# Desde opencode
skill owasp-mapping

# O manualmente: revisar sección 7 de docs/REGLAS-COMPLETAS.md
```

## Mapeo actual (sección 7 REGLAS-COMPLETAS.md)

### OWASP GenAI LLM Top 10 2026 - COBERTURA COMPLETA (10/10)

| Riesgo | Reglas better-ai | Capa determinista | Estado |
|--------|------------------|-------------------|--------|
| LLM01 Prompt Injection | P0.13, P0.8, P0.2 | deny eval/pipes | ✅ |
| LLM02 Sensitive Info Disclosure | P0.6, P0.9, P0.10, P0.11 | deny .env/.ssh/.aws/claves | ✅ |
| LLM03 Excessive Agency | P0.3, P0.4, P1.8, P1.9, P1.11 | 159 deny + ask | ✅ |
| **LLM04 Supply Chain** | **P0.18, P1.18, P1.2** | ask pip/npm + verificador SBOM | ✅ |
| LLM05 Data Model Poisoning | N/A (no entrena modelo) | — | N/A |
| **LLM06 Unbounded Consumption** | **P0.19, P1.30** | experimental.policies + cost-tracker | ✅ |
| LLM07 Misinformation | P0.1, P1.1, P1.6, P1.15, P1.30 | — | ✅ |
| LLM08 Hidden Context Exposure | P0.13, P0.11, P1.30 | deny eval/pipes | ✅ |
| **LLM09 Vector/Embedding Weaknesses** | **P0.20, P1.21** | — | ✅ |
| LLM10 Improper Output Handling | P0.1, P1.1, P1.15, P1.19 | verificador hook pre-commit | ✅ |

### MITRE ATLAS - Tácticas cubiertas

| Táctica | Reglas |
|---------|--------|
| Reconnaissance / Resource Development | P1.7, P0.2 |
| Initial Access / Execution | P0.8, P0.13, P1.4 + deny deterministas |
| Persistence / Impact | P0.3, P0.4, P0.12, P1.9 + deny deterministas |
| Exfiltration | P0.6, P0.9, P0.10, P0.11 + deny lectura claves |
| Denial of Service | Decisión de coste + P1.6 |

## Verificación automática

El skill comprueba:
1. Que las 3 reglas nuevas P0 (P0.18, P0.19, P0.20) existan en AGENTS.md
2. Que la tabla de mapeo en REGLAS-COMPLETAS.md §7 esté actualizada
3. Que el verificador incluya checks de Supply Chain (P0.18)
4. Que el checklist incluya P0.18, P0.19, P0.20

## Fuentes verificadas (HTTP 200)

- OWASP GenAI LLM Top 10 2026: https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/
- MITRE ATLAS: https://atlas.mitre.org/
- GitHub GenAI-Security-Project: https://github.com/GenAI-Security-Project/GenAI-LLM-Top10