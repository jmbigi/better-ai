#!/usr/bin/env bash
# Config Drift Detection - P1.9 Safeguards
# Detecta cambios no autorizados en configs críticas comparando con baseline firmada
# Uso: bash scripts/detect-drift.sh [--update-baseline] [--strict]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASELINE_FILE="${PROJECT_ROOT}/docs/config-baseline.sha256"
AUDIT_LOG="${PROJECT_ROOT}/docs/drift-audit.log"

# Configs críticas a monitorear (relativo a PROJECT_ROOT)
CRITICAL_CONFIGS=(
    "opencode.json"
    "kilo.json"
    ".kilo/kilo.json"
    "AGENTS.md"
    "scripts/verificar-proyecto.sh"
    "scripts/probar-denies.sh"
    "scripts/rotate-secret.sh"
    "scripts/opencode-sandbox.sh"
    "scripts/install-better-ai.sh"
    "scripts/update-better-ai.sh"
    "scripts/install-better-ai.ps1"
    "scripts/update-better-ai.ps1"
    "scripts/test-installer.sh"
    "scripts/ci-local-pure.sh"
    "scripts/analyze_shell.py"
    "scripts/check-shell-pipes.py"
)

UPDATE_BASELINE=false
STRICT_MODE=false

for arg in "$@"; do
    case $arg in
        --update-baseline)
            UPDATE_BASELINE=true
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        *)
            echo "Uso: $0 [--update-baseline] [--strict]"
            echo "  --update-baseline  Actualiza baseline con hashes actuales"
            echo "  --strict           Falla si hay cualquier drift (para CI/CD)"
            exit 1
            ;;
    esac
done

log_audit() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[${timestamp}] [${level}] ${message}" >> "${AUDIT_LOG}"
}

compute_hash() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sha256sum "$file" | cut -d' ' -f1
    else
        echo "MISSING"
    fi
}

generate_baseline() {
    echo "# Config Baseline - Generated $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "# DO NOT EDIT MANUALLY - Use: bash scripts/detect-drift.sh --update-baseline"
    echo "# Format: <sha256>  <relative-path>"
    echo
    for config in "${CRITICAL_CONFIGS[@]}"; do
        local full_path="${PROJECT_ROOT}/${config}"
        local hash=$(compute_hash "$full_path")
        echo "${hash}  ${config}"
    done
}

load_baseline() {
    declare -gA BASELINE_HASHES
    if [[ ! -f "$BASELINE_FILE" ]]; then
        log_audit "WARNING" "Baseline file not found: $BASELINE_FILE"
        return 1
    fi
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        local hash=$(echo "$line" | awk '{print $1}')
        local path=$(echo "$line" | awk '{print $2}')
        BASELINE_HASHES["$path"]="$hash"
    done < "$BASELINE_FILE"
    return 0
}

check_drift() {
    local drift_found=false
    local drift_details=()
    
    echo "=== Config Drift Detection ==="
    echo "Baseline: $BASELINE_FILE"
    echo
    
    if ! load_baseline; then
        echo "⚠️  No baseline found. Run with --update-baseline to create initial baseline."
        log_audit "WARNING" "No baseline found for drift detection"
        return 1
    fi
    
    echo "Checking ${#CRITICAL_CONFIGS[@]} critical configs..."
    echo
    
    for config in "${CRITICAL_CONFIGS[@]}"; do
        local full_path="${PROJECT_ROOT}/${config}"
        local current_hash=$(compute_hash "$full_path")
        local baseline_hash="${BASELINE_HASHES[$config]:-NOT_IN_BASELINE}"
        
        if [[ "$baseline_hash" == "NOT_IN_BASELINE" ]]; then
            echo -e "  [NEW]    $config (not in baseline)"
            drift_details+=("NEW: $config")
            drift_found=true
            log_audit "WARNING" "New config not in baseline: $config"
        elif [[ "$current_hash" == "MISSING" ]]; then
            echo -e "  [MISSING] $config (file deleted)"
            drift_details+=("MISSING: $config")
            drift_found=true
            log_audit "ERROR" "Critical config missing: $config"
        elif [[ "$current_hash" != "$baseline_hash" ]]; then
            echo -e "  [DRIFT]  $config"
            echo -e "    Baseline: $baseline_hash"
            echo -e "    Current:  $current_hash"
            drift_details+=("DRIFT: $config")
            drift_found=true
            log_audit "ERROR" "Config drift detected: $config (baseline: $baseline_hash, current: $current_hash)"
        else
            echo -e "  [OK]     $config"
        fi
    done
    
    echo
    if [[ "$drift_found" == "true" ]]; then
        echo -e "\033[0;31m⚠️  DRIFT DETECTADO en ${#drift_details[@]} config(s)\033[0m"
        echo
        echo "Acciones requeridas (P1.9, P1.23):"
        echo "  1. Revisa los cambios: git diff <config>"
        echo "  2. Si son cambios autorizados: bash scripts/detect-drift.sh --update-baseline"
        echo "  3. Si NO son autorizados: RESTAURA desde git (git checkout -- <config>)"
        echo "  4. Requiere autorización explícita del programador para actualizar baseline"
        log_audit "ALERT" "Drift detection completed - ${#drift_details[@]} drifts found"
        return 1
    else
        echo -e "\033[0;32m✅ Sin drift detectado - Todas las configs coinciden con baseline\033[0m"
        log_audit "INFO" "Drift detection completed - no drifts found"
        return 0
    fi
}

update_baseline() {
    echo "=== Actualizando Baseline ==="
    echo "Esto sobrescribirá $BASELINE_FILE con hashes actuales."
    echo
    
    if [[ -f "$BASELINE_FILE" ]]; then
        echo "Baseline anterior:"
        cat "$BASELINE_FILE"
        echo
    fi
    
    # Confirmación de seguridad
    read -p "¿Confirmas actualizar baseline? (escribe 'actualizar-baseline'): " confirm
    if [[ "$confirm" != "actualizar-baseline" ]]; then
        echo "Cancelado."
        return 1
    fi
    
    generate_baseline > "$BASELINE_FILE"
    echo -e "\033[0;32m✅ Baseline actualizado\033[0m"
    echo
    cat "$BASELINE_FILE"
    log_audit "INFO" "Baseline updated by user"
    return 0
}

# ============================================================================
# MAIN
# ============================================================================

if [[ "$UPDATE_BASELINE" == "true" ]]; then
    update_baseline
    exit $?
fi

check_drift
EXIT_CODE=$?

if [[ "$STRICT_MODE" == "true" && $EXIT_CODE -ne 0 ]]; then
    echo
    echo "Modo estricto: fallando debido a drift detectado"
    exit 1
fi

exit $EXIT_CODE