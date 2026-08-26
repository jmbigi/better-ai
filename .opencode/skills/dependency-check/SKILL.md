---
name: dependency-check
description: Escanea dependencias, genera SBOM (syft), detecta vulnerabilidades (grype), verifica licencias
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: supply-chain
---

## Qué hace

Ejecuta escaneo completo de cadena de suministro:
1. **SBOM** con `syft` (formato SPDX/CycloneDX) → `docs/SBOM-<fecha>.spdx.json`
2. **Vulnerabilidades** con `grype` (multi-ecosistema) + `pip-audit`/`npm audit`/`cargo audit` según proyecto
3. **Licencias** verificadas (compatible con CC BY-SA 4.0 del proyecto)
4. **Proveniencia SLSA Level 1+**: hashes, firmas, reproducible builds

## Cuándo usarme

- Antes de añadir/actualizar dependencias
- En CI/CD como gate (bloquea si CRITICAL/HIGH sin excepción documentada)
- Para generar evidencia de compliance (SBOM archivado)
- Tras detectar CVE en dependencias transitivas

## Cómo usarme

```bash
# Desde opencode
skill dependency-check

# O manualmente
syft dir:. -o spdx-json > docs/SBOM-$(date +%F).spdx.json
grype dir:. -o json | jq '.matches[] | select(.vulnerability.severity == "Critical" or .vulnerability.severity == "High")'
pip-audit  # si Python
npm audit  # si Node.js
cargo audit  # si Rust
```

## Criterios de bloqueo (P0.18)

**BLOQUEA la tarea si:**
- Vulnerabilidades CRITICAL o HIGH detectadas **SIN** excepción documentada
- Excepción = aprobada por escrito por programador con: justificación + plan de mitigación + fecha de revisión
- Sin SBOM generado y verificado

**PERMITE si:**
- Vulnerabilidades MEDIUM/LOW (reportadas, no bloqueantes)
- CRITICAL/HIGH con excepción documentada válida
- Sin dependencias externas (proyecto standalone)

## Ecosistemas soportados

| Ecosistema | SBOM | Vuln Scan | Licencia |
|------------|------|-----------|----------|
| Python (pip/poetry/uv) | syft | grype + pip-audit | pip-licenses |
| Node.js (npm/yarn/pnpm) | syft | grype + npm audit | npm ls --json |
| Rust (cargo) | syft | grype + cargo audit | cargo-license |
| Go (go modules) | syft | grype + govulncheck | go-licenses |
| Java (maven/gradle) | syft | grype + OWASP dependency-check | license-maven-plugin |

## Integración con verificar-proyecto.sh

El verificador ya incluye checks:
- `syft` disponible
- `grype` disponible  
- SBOM generado en `docs/SBOM-*.spdx.json`
- Sin vulns CRITICAL/HIGH sin excepción (check opcional, warning si detectadas)

## Salida

- SBOM archivado en `docs/SBOM-YYYY-MM-DD.spdx.json`
- Reporte vulns: cuenta por severidad, IDs CVE, paquetes afectados
- Reporte licencias: tabla paquete → licencia → compatible (sí/no)
- ⚠️ explícito si CRITICAL/HIGH sin excepción