# Task runner local para better-ai
# No requiere cuentas en la nube ni infraestructura externa.

SHELLCHECK_SEVERITY ?= error

.PHONY: check lint test sync hooks clean help

help:
	@echo "Targets disponibles:"
	@echo "  make check   - Ejecuta lint + test + verificacion completa"
	@echo "  make lint    - shellcheck y validacion JSON"
	@echo "  make test    - doc_validator, parity de configs y symlinks"
	@echo "  make sync    - Sincroniza .kilo/agents con .opencode/agents"
	@echo "  make hooks   - Instala el hook git pre-commit"
	@echo "  make clean   - Limpia temporales de red-team"

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

sync:
	bash scripts/sync-agents.sh
	python3 scripts/check-config-parity.py

hooks:
	bash scripts/install-hooks.sh

clean:
	rm -rf /tmp/opencode/redteam.*
