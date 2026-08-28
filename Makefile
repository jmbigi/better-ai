# Task runner local para better-ai
# No requiere cuentas en la nube ni infraestructura externa.

SHELLCHECK_SEVERITY ?= error

.PHONY: check lint test sync hooks hooks-lefthook ci-local dagger clean help install update

help:
	@echo "Targets disponibles:"
	@echo "  make check         - Ejecuta lint + test + verificacion completa"
	@echo "  make lint          - shellcheck y validacion JSON"
	@echo "  make test          - doc_validator, parity de configs, symlinks y pipes peligrosos"
	@echo "  make sync          - Sincroniza .kilo/agents con .opencode/agents"
	@echo "  make hooks         - Instala el hook git pre-commit (legacy)"
	@echo "  make hooks-lefthook - Instala hooks via Lefthook (recomendado)"
	@echo "  make ci-local      - Ejecuta .github/workflows/ci.yml con act"
	@echo "  make dagger        - Ejecuta pipeline Dagger local"
	@echo "  make clean         - Limpia temporales de red-team"
	@echo "  make install DEST=/ruta  - Instala better-ai en otro proyecto"
	@echo "  make update DEST=/ruta   - Actualiza better-ai en otro proyecto"

check: lint test
	bash scripts/verificar-proyecto.sh

lint:
	shellcheck --severity=$(SHELLCHECK_SEVERITY) scripts/*.sh
	python3 -m json.tool opencode.json >/dev/null
	python3 -m json.tool kilo.json >/dev/null

test:
	python3 scripts/doc_validator.py --root .
	python3 scripts/check-config-parity.py
	bash scripts/check-symlinks.sh
	python3 scripts/check-shell-pipes.py

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
