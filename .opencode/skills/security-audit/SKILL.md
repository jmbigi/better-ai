---
name: security-audit
description: Ejecuta auditoría completa de seguridad: verificador del proyecto + subagente security-auditor
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: security
---

## Qué hace

Ejecuta una auditoría completa de seguridad del proyecto combinando:
1. El verificador determinista (`verificar-proyecto.sh`) que comprueba coherencia de reglas, configs, permisos y repositorio
2. El subagente `security-auditor` (solo lectura) que escanea secretos, datos personales, código peligroso y contenido no confiable

## Cuándo usarme

- Antes de cada commit/push (integración con hook pre-commit)
- Antes de hacer público un repositorio
- Tras detectar posibles fugas en PRs o issues
- Como parte de CI/CD para gate de seguridad

## Cómo usarme

```bash
# Desde opencode
skill security-audit

# O manualmente
bash scripts/verificar-proyecto.sh
# Luego invocar @security-auditor para auditoría profunda
```

## Qué verifica

### Verificador determinista (verificar-proyecto.sh)
- 20 reglas P0 / 31 reglas P1 en AGENTS.md
- IDs coherentes entre AGENTS.md, REGLAS-COMPLETAS.md, README.md, CHECKLIST.md
- 245 patrones de permisos bash (159 deny, 85 ask)
- experimental.policies: deny all + allow list
- Sin .env versionado, sin IPs/emails/claves en archivos
- SBOM generado, grype/syft disponibles
- Hook pre-commit instalado, git fsck limpio

### Subagente security-auditor
- Secretos: API keys (sk-, ghp_, AKIA, AIza, xoxb-, PRIVATE KEY), .env, claves SSH, credenciales
- Datos personales: emails, IPs, rutas de usuario (/home/<usuario>/)
- Código peligroso: eval/exec, pipes a bash, chmod 777
- Contenido no confiable como instrucción (prompt injection)
- Historial git (si accesible)

## Salida esperada

Reporte conciso con:
- Hallazgos con `archivo:línea`, severidad y remediación
- "Sin hallazgos" + lista de comprobaciones si todo limpio
- NUNCA imprime valores de secretos ni datos personales
- ⚠️ explícito si detecta posible filtración