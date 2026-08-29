# Task runner local para better-ai
# No requiere cuentas en la nube ni infraestructura externa.

SHELLCHECK_SEVERITY ?= error

.PHONY: check lint test sync hooks hooks-lefthook ci-local dagger clean help install update ci install-ps update-ps

help:
	@echo "Targets disponibles:"
	@echo "  make check         - Ejecuta lint + test + verificacion completa + SBOM/vuln scan si estan disponibles"
	@echo "  make ci            - CI local pura sin Docker (lint opcional + test + verificar)"
	@echo "  make lint          - shellcheck (si esta disponible) y validacion JSON"
	@echo "  make test          - doc_validator, parity de configs, symlinks y pipes peligrosos"
	@echo "  make sbom          - Genera SBOM SPDX con syft (requiere syft)"
	@echo "  make vuln-scan     - Escanea vulnerabilidades con grype (requiere grype)"
	@echo "  make sync          - Sincroniza .kilo/agents con .opencode/agents"
	@echo "  make hooks         - Instala el hook git pre-commit (legacy)"
	@echo "  make hooks-lefthook - Instala hooks via Lefthook (recomendado)"
	@echo "  make ci-local      - Ejecuta .github/workflows/ci.yml con act"
	@echo "  make dagger        - Ejecuta pipeline Dagger local"
	@echo "  make clean         - Limpia temporales de red-team"
	@echo "  make install DEST=/ruta  - Instala better-ai en otro proyecto (Bash)"
	@echo "  make update DEST=/ruta   - Actualiza better-ai en otro proyecto (Bash)"
	@echo "  make install-ps DEST=/ruta - Instala better-ai en otro proyecto (PowerShell)"
	@echo "  make update-ps DEST=/ruta  - Actualiza better-ai en otro proyecto (PowerShell)"

check: lint test sbom vuln-scan
	bash scripts/verificar-proyecto.sh

ci:
	bash scripts/ci-local-pure.sh

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck --severity=$(SHELLCHECK_SEVERITY) scripts/*.sh; \
	else \
		echo "[WARNING] shellcheck no instalado; se omite (instalar para lint completo)"; \
	fi
	python3 -m json.tool opencode.json >/dev/null
	python3 -m json.tool kilo.json >/dev/null

test:
	python3 scripts/doc_validator.py --root .
	python3 scripts/check-config-parity.py
	bash scripts/check-symlinks.sh
	python3 scripts/check-shell-pipes.py

sbom:
	@if command -v syft >/dev/null 2>&1; then \
		bash scripts/generate-sbom.sh; \
	else \
		echo "[SKIP] syft no instalado; SBOM no regenerado"; \
	fi

vuln-scan:
	@if command -v grype >/dev/null 2>&1; then \
		echo "[INFO] Escaneando vulnerabilidades con grype..."; \
		grype dir:. -o table; \
	else \
		echo "[SKIP] grype no instalado; vuln scan no ejecutado"; \
	fi

sync:
	bash scripts/sync-agents.sh
	python3 scripts/check-config-parity.py

hooks:
	bash scripts/install-hooks.sh

hooks-lefthook:
	@command -v lefthook >/dev/null 2>&1 || { echo "[FALLO] lefthook no esta instalado. Ver https://lefthook.dev/installation"; exit 1; }
	lefthook install
	@echo "[OK] Hooks de Lefthook instalados"

ci-local:
	@command -v act >/dev/null 2>&1 || { echo "[FALLO] act no esta instalado. Ver https://nektos.github.io/act"; exit 1; }
	act -j verify

dagger:
	@command -v dagger >/dev/null 2>&1 || { echo "[FALLO] dagger no esta instalado. Ver https://dagger.io/"; exit 1; }
	dagger run python ci/dagger.py

clean:
	rm -rf /tmp/opencode/redteam.*

install:
	@if [ -z "$(DEST)" ]; then echo "[FALLO] Define DEST=/ruta/del/proyecto"; exit 1; fi
	bash scripts/install-better-ai.sh "$(DEST)"

update:
	@if [ -z "$(DEST)" ]; then echo "[FALLO] Define DEST=/ruta/del/proyecto"; exit 1; fi
	bash scripts/update-better-ai.sh "$(DEST)"

install-ps:
	@if [ -z "$(DEST)" ]; then echo "[FALLO] Define DEST=/ruta/del/proyecto"; exit 1; fi
	pwsh -File scripts/install-better-ai.ps1 -Destino "$(DEST)"

update-ps:
	@if [ -z "$(DEST)" ]; then echo "[FALLO] Define DEST=/ruta/del/proyecto"; exit 1; fi
	pwsh -File scripts/update-better-ai.ps1 -Destino "$(DEST)"
