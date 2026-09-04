---
name: owasp-mapping
description: Verifica cobertura del ruleset contra OWASP GenAI LLM Top 10 2026, OWASP Top 10 for Agentic Applications 2026 (ASI01-ASI10) y MITRE ATLAS
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: compliance
---

## Qué hace

Verifica y reporta la cobertura del ruleset better-ai frente a:
1. **OWASP GenAI LLM Top 10 2026** (fuente 22, HTTP 200 verificado 15-08-2026)
2. **OWASP Top 10 for Agentic Applications 2026** (ASI01-ASI10, fuentes 37-40,
   HTTP 200 verificado 04-09-2026; incluye nota sobre el Agent Control Standard,
   anunciado 02-09-2026)
3. **MITRE ATLAS** tácticas relevantes (fuente 24, HTTP 200 verificado 15-08-2026)

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

### OWASP Top 10 for Agentic Applications 2026 (ASI01-ASI10)

Estado honesto de cobertura (detalle en REGLAS-COMPLETAS.md §7, fuentes 37-40):

| Riesgo | Estado | Reglas principales |
|--------|--------|--------------------|
| ASI01 Agent Goal Hijack | Parcial | P0.13, P1.8, P1.32 (sin prevención fool-proof, declarado) |
| ASI02 Tool Misuse and Exploitation | ✅ | P0.3, P0.4, P1.4, P1.9 + 159 deny |
| ASI03 Identity and Privilege Abuse | Parcial | P0.5, P0.12, P1.2 (hueco: sin identidades de agente) |
| ASI04 Agentic Supply Chain Vulnerabilities | ✅ | P0.18, P1.18 (misma cobertura que LLM04) |
| ASI05 Unexpected Code Execution (RCE) | ✅ | P0.8 + sandbox Docker (P1.9) |
| ASI06 Memory and Context Poisoning | Parcial/N-A | P0.13, P0.20 (sin memoria persistente en el ruleset) |
| ASI07 Insecure Inter-Agent Communication | ❌ Sin cobertura | declarado (agente único, sin canal A2A) |
| ASI08 Cascading Failures | Parcial | P1.32, P1.34, P1.35, P0.19 |
| ASI09 Human-Agent Trust Exploitation | ✅ | P1.23, P1.22, P1.15, P1.6 |
| ASI10 Rogue Agents | Parcial | P0.19, P1.30, P1.35 (sin kill switch probado) |

**ACS**: el Agent Control Standard (anunciado 02-09-2026) busca enforcement de
runtime para agentes; la arquitectura del proyecto (245 guardarraíles deny/ask +
`analyze_shell.py` + plugin `guard-shell` + sandbox Docker) se alinea
conceptualmente, sin certificación formal contra el texto del ACS.

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
- OWASP Top 10 for Agentic Applications 2026 (ASI01-ASI10): https://genai.owasp.org/
  (lista confirmada además en https://cycode.com/blog/owasp-top-10-agentic-applications/
  y https://lokalaise.de/en/blog/owasp-agentic-top-10-local-ai; verificado 04-09-2026)
- OWASP Agent Control Standard (anuncio 02-09-2026): https://www.morningstar.com/news/pr-newswire/20260902la38909/owasp-genai-security-project-releases-2026-top-10-for-llm-applications-debuts-agent-control-standard-and-new-resources-for-securing-generative-and-agentic-ai
- MITRE ATLAS: https://atlas.mitre.org/
- GitHub GenAI-Security-Project: https://github.com/GenAI-Security-Project/GenAI-LLM-Top10