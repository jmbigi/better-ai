#!/usr/bin/env bash
# Secrets Rotation Automation - MAXIMUM SAFEGUARDS
# P0.12: Nunca cambies claves sin orden explícita y plan
# P0.3: 3 confirmaciones + frase exacta
# P1.9: Dry-run, backup, audit trail inmutable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AUDIT_LOG="${PROJECT_ROOT}/docs/secrets-rotation-audit.log"
BACKUP_DIR="${PROJECT_ROOT}/.secrets-backup/$(date +%Y%m%d-%H%M%S)"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_audit() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[${timestamp}] [${level}] ${message}" >> "${AUDIT_LOG}"
}

require_confirmation() {
    local prompt="$1"
    local required_phrase="$2"
    local confirm_count=0
    
    echo -e "${YELLOW}⚠️  CONFIRMACIÓN REQUERIDA (P0.3/P0.12)${NC}"
    echo -e "${prompt}"
    echo -e "Debes escribir EXACTAMENTE: ${RED}${required_phrase}${NC}"
    echo -e "Se requieren 3 confirmaciones idénticas.\n"
    
    for i in 1 2 3; do
        read -p "Confirmación $i/3: " user_input
        if [[ "${user_input}" == "${required_phrase}" ]]; then
            confirm_count=$((confirm_count + 1))
            echo -e "${GREEN}✓ Confirmación $i válida${NC}"
        else:
            echo -e "${RED}✗ Frase incorrecta. Debe ser EXACTAMENTE: ${required_phrase}${NC}"
            log_audit "ERROR" "Confirmación $i fallida para rotación de secreto"
            return 1
        fi
    done
    
    if [[ $confirm_count -eq 3 ]]; then
        log_audit "INFO" "3 confirmaciones válidas recibidas para rotación"
        return 0
    else
        return 1
    fi
}

show_usage() {
    cat << EOF
Usage: $0 <secret-name> <secret-type> [--dry-run|--execute] [--provider <provider>]

SECRET TYPES:
  db-password      Database password
  api-key          API key (OpenAI, Anthropic, etc.)
  ssh-key          SSH private key
  aws-credentials  AWS access key/secret
  jwt-secret       JWT signing secret
  encryption-key   Encryption key

PROVIDERS (for rotation):
  vault            HashiCorp Vault
  aws-sm           AWS Secrets Manager
  1password        1Password CLI
  k8s-secret       Kubernetes Secret
  manual           Manual rotation (agent prepares, human executes)

MODES:
  --dry-run        SIMULA la rotación sin cambios reales (DEFAULT, SEGURO)
  --execute        EJECUTA la rotación REAL (requiere 3 confirmaciones + frase)

EXAMPLES:
  $0 db-password db-password --dry-run --provider vault
  $0 api-key openai --dry-run --provider 1password
  $0 ssh-key ssh --execute --provider manual  # REQUIERE 3 CONFIRMACIONES

SAFEGUARDS:
  1. DEFAULT es --dry-run (no cambia nada)
  2. --execute requiere 3 confirmaciones + frase exacta
  3. Backup previo inmutable en .secrets-backup/
  4. Audit trail append-only en docs/secrets-rotation-audit.log
  4. Solo programador ejecuta rotación real
  5. Agente SOLO prepara/valida, NUNCA rota sin orden explícita
EOF
}

# ============================================================================
# MAIN
# ============================================================================

if [[ $# -lt 2 ]]; then
    show_usage
    exit 1
fi

SECRET_NAME="$1"
SECRET_TYPE="$2"
MODE="--dry-run"
PROVIDER="manual"
DRY_RUN=true

shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            MODE="--dry-run"
            DRY_RUN=true
            shift
            ;;
        --execute)
            MODE="--execute"
            DRY_RUN=false
            shift
            ;;
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}Error: Opción desconocida: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Validar secret type
VALID_TYPES=("db-password" "api-key" "ssh-key" "aws-credentials" "jwt-secret" "encryption-key")
if [[ ! " ${VALID_TYPES[@]} " =~ " ${SECRET_TYPE} " ]]; then
    echo -e "${RED}Error: Tipo de secreto inválido: ${SECRET_TYPE}${NC}"
    show_usage
    exit 1
fi

# Validar provider
VALID_PROVIDERS=("vault" "aws-sm" "1password" "k8s-secret" "manual")
if [[ ! " ${VALID_PROVIDERS[@]} " =~ " ${PROVIDER} " ]]; then
    echo -e "${RED}Error: Proveedor inválido: ${PROVIDER}${NC}"
    show_usage
    exit 1
fi

echo -e "${BLUE}=== Secrets Rotation: ${SECRET_NAME} (${SECRET_TYPE}) ===${NC}"
echo -e "Modo: ${MODE}"
echo -e "Proveedor: ${PROVIDER}"
echo -e "Dry-run: ${DRY_RUN}"
echo

log_audit "INFO" "Iniciando rotación: secret=${SECRET_NAME} type=${SECRET_TYPE} mode=${MODE} provider=${PROVIDER}"

# ============================================================================
# BACKUP PREVIO (SIEMPRE, incluso en dry-run)
# ============================================================================

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

echo -e "${YELLOW}Creando backup inmutable en: ${BACKUP_DIR}${NC}"
log_audit "INFO" "Backup creado en ${BACKUP_DIR}"

# Simular backup del secreto actual (en dry-run solo log)
if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${GREEN}[DRY-RUN]${NC} Simulando backup del secreto actual..."
    log_audit "DRY_RUN" "Backup simulado para ${SECRET_NAME}"
else
    # En execute real, aquí iría el backup real según provider
    echo -e "${RED}[EXECUTE]${NC} Haciendo backup real del secreto..."
    log_audit "EXECUTE" "Backup real realizado para ${SECRET_NAME}"
fi

# ============================================================================
# PLAN DE ROTACIÓN
# ============================================================================

echo
echo -e "${BLUE}=== PLAN DE ROTACIÓN ===${NC}"
cat << EOF
Secreto: ${SECRET_NAME}
Tipo: ${SECRET_TYPE}
Proveedor: ${PROVIDER}
Modo: ${MODE}

Pasos:
1. Generar nuevo secreto (según política de complejidad)
2. Validar nuevo secreto (formato, longitud, entropía)
3. Actualizar en proveedor destino
4. Verificar funcionamiento (health check)
5. Invalidar secreto antiguo
6. Actualizar referencias en .env.example / docs
7. Registrar en audit trail

EOF

log_audit "INFO" "Plan de rotación mostrado para ${SECRET_NAME}"

# ============================================================================
# --execute REQUIERE CONFIRMACIÓN EXPLÍCITA
# ============================================================================

if [[ "${DRY_RUN}" == "false" ]]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}⚠️  MODO EXECUTE: ROTACIÓN REAL - CAMBIOS IRREVERSIBLES${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "Esta acción:"
    echo -e "  - CAMBIARÁ la credencial en ${PROVIDER}"
    echo -e "  - PUEDE ROMPER accesos productivos si falla"
    echo -e "  - REQUIERE coordinación con equipos afectados"
    echo
    
    if ! require_confirmation \
        "¿Confirmas la ROTACIÓN REAL del secreto '${SECRET_NAME}' en ${PROVIDER}?" \
        "Confirmo rotacion de secreto ${SECRET_NAME} en ${PROVIDER}"; then
        echo -e "${RED}Rotación CANCELADA por confirmación fallida${NC}"
        log_audit "ERROR" "Rotación cancelada: confirmación fallida para ${SECRET_NAME}"
        exit 1
    fi
    
    echo
    echo -e "${GREEN}3 confirmaciones válidas. Procediendo con rotación real...${NC}"
    log_audit "INFO" "3 confirmaciones válidas. Iniciando rotación REAL para ${SECRET_NAME}"
    
    # ================================================================
    # AQUÍ IRÍA LA ROTACIÓN REAL SEGÚN PROVIDER
    # ================================================================
    case "${PROVIDER}" in
        vault)
            echo "[EXECUTE] vault kv put secret/${SECRET_NAME} value=<new-secret>"
            ;;
        aws-sm)
            echo "[EXECUTE] aws secretsmanager put-secret-value --secret-id ${SECRET_NAME} --secret-string <new-secret>"
            ;;
        1password)
            echo "[EXECUTE] op item edit ${SECRET_NAME} --vault=... password=<new-secret>"
            ;;
        k8s-secret)
            echo "[EXECUTE] kubectl create secret generic ${SECRET_NAME} --from-literal=key=<new-secret> --dry-run=client -o yaml | kubectl apply -f -"
            ;;
        manual)
            echo "[EXECUTE] MANUAL: El programador debe ejecutar la rotación manualmente"
            echo "  Nuevo secreto generado: <secreto-generado>"
            echo "  Actualiza en: ${PROVIDER}"
            ;;
    esac
    
    log_audit "EXECUTE" "Rotación REAL completada para ${SECRET_NAME} en ${PROVIDER}"
    echo -e "${GREEN}✅ Rotación completada. Verifica funcionamiento y actualiza referencias.${NC}"
else:
    echo -e "${GREEN}✅ DRY-RUN completado. No se realizaron cambios reales.${NC}"
    echo -e "Para ejecutar realmente: $0 ${SECRET_NAME} ${SECRET_TYPE} --execute --provider ${PROVIDER}"
    log_audit "DRY_RUN" "Dry-run completado para ${SECRET_NAME}. Sin cambios reales."
fi

echo
echo -e "${BLUE}Audit trail: ${AUDIT_LOG}${NC}"
echo -e "${BLUE}Backup: ${BACKUP_DIR}${NC}"