# QUICKSTART — Mejorar un proyecto con better-ai en 5 minutos

> Guía mínima para empezar. Para la normativa completa ver `AGENTS.md` y
> `docs/REGLAS-COMPLETAS.md`.

## Requisitos

- Tener instalado **opencode** (`npm install -g opencode`) o **kilocode**.
- Un proyecto local con código que quieras proteger con las reglas.

## Paso 1 — Copiar las reglas

Desde una copia local de este repo:

```bash
# Linux / macOS / Git Bash
bash /ruta/a/better-ai/scripts/install-better-ai.sh /ruta/a/tu/proyecto

# Windows PowerShell nativo
.\C:\ruta\a\better-ai\scripts\install-better-ai.ps1 -Destino C:\ruta\a\tu\proyecto
```

Instalación mínima (solo reglas y configs):

```bash
bash /ruta/a/better-ai/scripts/install-better-ai.sh --core-only /ruta/a/tu/proyecto
```

Esto copia:

- `AGENTS.md` — reglas P0/P1.
- `opencode.json` o `kilo.json` — guardarraíles deterministas.
- `.opencode/agents/` o `.kilo/agents/` — subagentes de revisión.

## Paso 2 — Elegir herramienta y modelo

| Herramienta | Config a usar | Modelos permitidos (low-cost) |
|---|---|---|
| opencode | `opencode.json` | `opencode/deepseek-v4-flash-free` o `opencode-go/deepseek-v4-flash` |
| kilocode | `kilo.json` | `deepseek/deepseek-chat`, `kilo-auto/free`, `kilo-auto/efficient` |

Borra el config que no uses para evitar confusiones:

```bash
# Si usas opencode
rm tu-proyecto/kilo.json

# Si usas kilocode
rm tu-proyecto/opencode.json
```

## Paso 3 — Verificar que todo carga

En la raíz de tu proyecto:

```bash
bash scripts/verificar-proyecto.sh
```

Debe terminar con `Resultado: N OK, 0 FALLOS`.

> Si estás en medio de un cambio, usa modo pre-commit:
> `bash scripts/verificar-proyecto.sh --pre-commit`.

## Paso 4 — Probar una tarea segura

Abre tu proyecto con opencode:

```bash
opencode /ruta/a/tu/proyecto
```

Pide algo inocuo, por ejemplo:

> "Explica qué hace la función principal de este proyecto. No modifiques nada."

El agente debe:

- Leer los archivos antes de responder.
- No ejecutar comandos destructivos.
- Citar `archivo:línea` solo de archivos que haya leído.

## Paso 5 — Revisar antes de entregar

Antes de declarar una tarea terminada:

1. Invoca el subagente de revisión: `@security-auditor` o `@code-reviewer`.
2. Completa `CHECKLIST.md` (marca solo lo que verificaste con evidencia real).
3. Ejecuta `bash scripts/verificar-proyecto.sh --pre-commit`.

## Qué hacer si algo falla

| Síntoma | Solución |
|---|---|
| El verificador falla en "sin drift" | `bash scripts/detect-drift.sh --update-baseline` (solo si los cambios son intencionales) |
| El agente no respeta un `deny` | Revisa que copies el `opencode.json`/`kilo.json` correcto y que no haya un config global anulándolo |
| `opencode run --auto` bloquea todo | `--auto` aprueba los `ask`; para intervención humana, quita `--auto` |
| Modelo no disponible | Cambia a otro modelo permitido (ver tabla del Paso 2) |

## Siguientes pasos

- Lee `AGENTS.md` completo antes de tareas complejas (P0.15).
- Adapta los permisos de `opencode.json`/`kilo.json` a tu proyecto (p. ej. añade comandos específicos de tu stack a la lista `ask`/`deny`).
- Para auditorías críticas, usa el agente `audit` de opencode (`opencode run --agent audit ...`).
