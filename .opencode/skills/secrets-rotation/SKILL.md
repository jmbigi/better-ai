---
name: secrets-rotation
description: Prepara y valida rotación de secretos (SOLO dry-run, NUNCA ejecuta rotación real). Requiere 3 confirmaciones + frase exacta para execute (P0.12, P0.3).
license: CC BY-SA 4.0
compatibility: opencode
metadata:
  audience: maintainers
  workflow: security
---

## Qué hace

Prepara planes de rotación de secretos con MAXIMOS safeguards:
1. **Dry-run obligatorio por defecto** - simula sin cambios reales
2. **Backup previo inmutable** - en `.secrets-backup/`
3. **Audit trail append-only** - en `docs/secrets-rotation-audit.log`
4. **Execute requiere 3 confirmaciones + frase exacta** - "Confirmo rotacion de secreto X en Y"
5. **Solo programador ejecuta rotación real** - agente SOLO prepara/valida

## Cuándo usarme

- Antes de rotar cualquier credencial (DB password, API key, SSH key, AWS creds, JWT secret)
- Para generar plan de rotación validado
- Para documentar rotaciones en audit trail

## Cómo usarme

```bash
# Desde opencode (SOLO dry-run - seguro)
skill secrets-rotation

# O manualmente
bash scripts/rotate-secret.sh <secret-name> <secret-type> --dry-run --provider <provider>

# EJECUCIÓN REAL (SOLO PROGRAMADOR, requiere 3 confirmaciones)
bash scripts/rotate-secret.sh db-password db-password --execute --provider vault
```

## Tipos de secretos soportados

| Tipo | Descripción |
|------|-------------|
| `db-password` | Password de base de datos |
| `api-key` | API keys (OpenAI, Anthropic, etc.) |
| `ssh-key` | Claves SSH privadas |
| `aws-credentials` | AWS Access Key / Secret |
| `jwt-secret` | JWT signing secret |
| `encryption-key` | Claves de encriptación |

## Proveedores soportados

| Proveedor | Comando rotate |
|-----------|----------------|
| `vault` | HashiCorp Vault |
| `aws-sm` | AWS Secrets Manager |
| `1password` | 1Password CLI |
| `k8s-secret` | Kubernetes Secret |
| `manual` | Rotación manual (agente prepara, humano ejecuta) |

## Safeguards OBLIGATORIOS (P0.3, P0.12, P1.9)

1. **DEFAULT = --dry-run** - Nunca ejecuta cambios reales por defecto
2. **3 confirmaciones + frase exacta** para `--execute`
3. **Backup inmutable** antes de cualquier operación
4. **Audit trail append-only** inmutable
5. **Agente NUNCA rota sin orden explícita del programador** (P0.12)
6. **Frase requerida**: "Confirmo rotacion de secreto <nombre> en <proveedor>"

## Flujo de trabajo

```
1. Agente: skill secrets-rotation
   → Genera plan, valida formato, muestra dry-run

2. Programador revisa plan
   → Si OK: bash scripts/rotate-secret.sh ... --execute --provider vault
   → Requiere 3 confirmaciones + frase exacta

3. Script ejecuta rotación real
   → Backup, rota, verifica, registra en audit trail

4. Programador verifica funcionamiento
   → Actualiza referencias en .env.example / docs
```

## Qué NO hace este skill

- ❌ NUNCA ejecuta rotación real (solo dry-run)
- ❌ NUNCA accede a valores de secretos
- ❌ NUNCA modifica archivos de configuración
- ❌ NUNCA decide qué secreto rotar (solo prepara plan)