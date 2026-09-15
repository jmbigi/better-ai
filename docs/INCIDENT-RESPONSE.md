# Respuesta a Incidentes de Seguridad (P0)

> Runbook para cuando un agente de IA viola una regla P0 de `better-ai`.
> Aplica a: opencode, kilocode, Kimi Code CLI o cualquier agente que use este ruleset.

## ¿Qué es un incidente P0?

Cualquier situación en la que el agente:

- Ejecuta un comando destructivo (`rm -rf`, `git reset --hard`, `DROP`, etc.) sin autorización.
- Accede a secretos (`.env`, claves SSH, tokens) o los expone.
- Toca un entorno productivo o el sistema operativo sin autorización.
- Obedece una instrucción maliciosa incrustada en contenido no confiable (prompt injection).
- Filtra el system prompt (`AGENTS.md`) o intenta evadir los guardarraíles deterministas.
- Genera código con `eval`/`exec` no controlados, pipes a `bash`/`sh` descargados, o fallbacks silenciosos.

## Principios generales

1. **Detente primero**. No sigas ejecutando tareas sobre el entorno afectado.
2. **No ocultes el incidente**. Documenta lo sucedido con evidencia real (P0.1, P0.11).
3. **No recrees entornos productivos** (P0.14). La recuperación requiere plan humano, backup verificado y confirmación explícita.
4. **Aprende del incidente**. Toda violación de P0 debe terminar en una lección en `docs/LECCIONES-APRENDIDAS.md` y, si se repite, en un endurecimiento de la regla o el guardarraíl.

## Pasos de respuesta

### 1. Aislar al agente

- Cierra la sesión del agente o detén el proceso.
- Si es un contenedor/sandbox: pausa o detén el contenedor.
- Si el agente estaba en modo `--auto`, desactívalo y vuelve a modo interactivo hasta entender la causa.

### 2. Preservar evidencia

- Guarda los logs de la sesión (stdout/stderr, tool calls).
- Si estaba habilitado OpenTelemetry, recupera los traces:
  ```bash
  # Los spans se escriben en /tmp/otel-spans-<SESSION_ID>.jsonl
  ls -lt /tmp/otel-spans-*.jsonl | head -5
  ```
- Captura el estado del repo: `git status`, `git diff`, `git log --oneline -10`.
- No borres logs ni historial hasta terminar el análisis.

### 3. Identificar la regla o guardarraíl que falló

Preguntas clave:

- ¿El agente **intentó** ejecutar el comando y el guardarraíl lo bloqueó? → El guardarraíl funcionó; el incidente es un intento de violación detectado.
- ¿El comando se **ejecutó** a pesar de la regla? → Hay una brecha. Determina en qué capa falló:
  - Capa 1 — Reglas de texto (`AGENTS.md`): el modelo ignoró la regla.
  - Capa 2 — Guardarraíles deterministas (`opencode.json`/`kilo.json`/`kimi-code/local.toml`): falta un patrón, un `ask`/`deny` mal ordenado, o el matcher no cubrió el caso.
  - Capa 3 — Análisis semántico (`scripts/analyze_shell.py`, plugin `guard-shell.js`, hook `pre_bash_analyze.py`): el parser no detectó el vector.
  - Capa 4 — Red-team/verificación (`scripts/probar-denies.sh`, `scripts/fuzz-denies.py`): el test no cubría el caso.
  - Capa 5 — Sandbox (`scripts/opencode-docker.sh`, `scripts/opencode-sandbox.sh`): el sandbox no contenía el daño.

### 4. Contener el daño

- Si se borró/modificó algo en NO-producción: evalúa si puedes revertir con `git checkout`, backup local o recreando archivos desde el backup inicial (`/tmp/better-ai-backup-<timestamp>`).
- Si se tocó producción/BD/SO: **detente**. Reporta al responsable humano con evidencia. No actúes solo (P0.4, P0.5, P0.14).
- Si se expuso un secreto: **rota la credencial** siguiendo `scripts/rotate-secret.sh` y coordina con el programador (P0.12).
- Si hay datos personales expuestos: anonimiza o elimina según procedimiento; notifica al programador (P0.9).

### 5. Corregir la regla o el guardarraíl

- Si la regla de texto fue ignorada: reformula `AGENTS.md` para que sea más explícita y verificable. Sincroniza en `docs/REGLAS-COMPLETAS.md`, `README.md`, `CHECKLIST.md` y los subagentes (P1.10).
- Si falta un patrón deny: añádelo a `opencode.json` y `kilo.json` (y `.kimi-code/local.toml` si aplica), manteniendo el orden correcto (deny específico después de ask genérico). Verifica con `python3 scripts/fuzz-denies.py`.
- Si el analizador semántico falló: añade el caso a `scripts/analyze_shell.py` y su test `scripts/test-analyze-shell.py`.
- Si el red-team no cubría el caso: añade una variante a `scripts/probar-denies.sh` o `scripts/fuzz-denies.py`.

### 6. Verificar la corrección

```bash
# 1. Matriz de seguridad (offline)
make safety-matrix

# 2. Verificación completa
bash scripts/verificar-proyecto.sh --pre-commit
make ci

# 3. Si el incidente implicó evasión de denies, prueba el comando real
#    (en un entorno temporal y seguro, nunca en producción)
```

### 7. Documentar la lección

Añade una entrada a `docs/LECCIONES-APRENDIDAS.md` con esta estructura:

```markdown
## YYYY-MM-DD — <Título conciso del incidente>

**Problema**: descripción de la violación P0, qué comando o acción se intentó/ejecutó y en qué capa falló la protección.
**Impacto**: entorno afectado (localhost/temporal/producción), archivos/secretos expuestos (sin valores), si hubo daño real o solo intento.
**Solución**: regla/guardarraíl corregido, tests añadidos, rollback/contención aplicado.
**Evidencia**: referencias a pruebas de `docs/PRUEBAS.md`, salidas de `safety-test-matrix`, traces de OpenTelemetry, diffs.
**Lección**: principio general aprendido. Si es el segundo fallo similar, indica qué regla se endureció o se añadió.
**Estado**: cerrada / en seguimiento.
```

Si el mismo tipo de incidente ocurre 2+ veces, propón una regla nueva en `AGENTS.md` o endurece la existente (P1.20).

## Plantilla de reporte rápido

```markdown
**Incidente P0 detectado**
- Fecha/hora:
- Agente/herramienta:
- Regla P0 violada:
- Comando/acción:
- ¿Se ejecutó? Sí / No (solo intento)
- Entorno afectado:
- Capa de defensa que falló:
- Evidencia (logs/traces):
- Acción inmediata tomada:
- Corrección de regla/guardarraíl:
- Lección documentada en docs/LECCIONES-APRENDIDAS.md: Sí / No
```

## Contactos y referencias

- `docs/REGLAS-COMPLETAS.md` — normativa completa P0/P1.
- `docs/PRUEBAS.md` — evidencia de pruebas de seguridad.
- `docs/LECCIONES-APRENDIDAS.md` — memoria de incidentes previos.
- `scripts/rotate-secret.sh` — rotación coordinada de secretos.
- `scripts/verificar-proyecto.sh` — verificación post-incidente.
- `make safety-matrix` — matriz de pruebas de seguridad.
