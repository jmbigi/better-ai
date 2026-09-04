# Integracion con asistentes y sistemas operativos

## Nucleo comun

`AGENTS.md` es la fuente de reglas compartida para agentes que soportan ese
formato. El contrato de requisitos vive en `.docs/requirements/` y se valida
con `scripts/doc_validator.py`, escrito solo con la biblioteca estandar de
Python 3.

El validador puede ejecutarse en cualquier sistema operativo con Python 3:

```text
python scripts/doc_validator.py --root .
```

En Windows tambien se incluyen `scripts/verificar-requisitos.ps1` y
`scripts/verificar-requisitos.cmd`, que detectan explicitamente `py` o
`python` y fallan si Python no esta disponible.

## Adaptadores

| Herramienta | Configuracion | Garantia |
|---|---|---|
| opencode | `AGENTS.md` + `opencode.json` + `.opencode/` | Reglas de texto y permisos deterministas del runtime. |
| kilocode | `AGENTS.md` + `kilo.json` + `.kilo/` | Reglas de texto y permisos deterministas del runtime. |
| Kimi Code CLI | `AGENTS.md` + `.kimi-code/local.toml` + `.kimi-code/hooks/` | Reglas de texto + permisos declarativos + hook PreToolUse; pendiente verificacion empirica. |
| GitHub Copilot | `AGENTS.md` + `.github/copilot-instructions.md` | Instrucciones de trabajo; no sustituye un sandbox ni bloquea comandos por si solo. |
| Cline | `AGENTS.md` + `.clinerules/` en la raiz del proyecto | Instrucciones de texto; sin deny determinista estilo `opencode.json`. |
| Roo Code | `AGENTS.md` + `.roo/rules/` (o `.roorules` legacy) | Instrucciones de texto; sin deny determinista estilo `opencode.json`. |
| Otros asistentes | `AGENTS.md` y el contrato `.docs/requirements/` | Depende de si el asistente lee esos formatos y ejecuta el validador. |

<!-- REQ-002 -->
<!-- REQ-005 -->

### Kimi Code CLI

Kimi Code CLI lee `AGENTS.md` nativamente y anade permisos declarativos en
TOML (`[[permission.rules]]` con `decision`/`pattern`) y hooks `PreToolUse`
que reciben el comando por stdin en JSON. El adaptador vive en
`.kimi-code/local.toml` y `.kimi-code/hooks/pre_bash_analyze.py` (REQ-005).
Ojo al portar reglas: el matcher de Kimi documenta primer-match-gana, lo
que INVIERTE el orden de `opencode.json`/`kilo.json` (last-match-wins): las
excepciones allow van antes que los denies y el allow comodin al final.
Ademas, los hooks son fail-open por diseno (un fallo del hook permite el
comando), asi que el bloqueo real depende de las reglas deny declarativas,
no del hook. Pendiente: verificacion empirica (kimi-code no instalado aqui)
y confirmar si `local.toml` carga `permission.rules`/`hooks` o solo
`[workspace]` (la doc oficial solo menciona lo segundo; si no carga, copiar
el contenido a `~/.kimi-code/config.toml`). Fuente:
[Kimi Code - Configuration files](https://www.kimi.com/code/docs/en/kimi-code-cli/configuration/config-files.html)
y [Kimi Code - Hooks](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html).

### Cline y Roo Code (extensiones de VS Code)

Ambas herramientas leen `AGENTS.md` de la raiz del proyecto de forma nativa,
ademas de sus propios formatos de reglas. Para reforzar o sustituir esa
carga, se puede inyectar el contenido de `AGENTS.md` en el mecanismo propio
de cada una.

**Cline**: las reglas de proyecto viven en `.clinerules/`, un directorio en
la raiz del proyecto cuyos archivos `.md` y `.txt` Cline combina como reglas
(workspace rules); el formato historico de archivo unico `.clinerules`
(single file, desde Cline v3) tambien es reconocido. Cline detecta ademas
otros formatos (`.cursorrules`, `.windsurfrules`, `AGENTS.md` global en
`~/.agents/AGENTS.md`). Fuente: [Cline Rules](https://docs.cline.bot/customization/cline-rules)
y [discussion #622 de cline/cline](https://github.com/cline/cline/discussions/622).

**Roo Code**: el metodo preferido es el directorio `.roo/rules/` en la raiz
del workspace (lectura recursiva, en orden alfabetico); si no existe o esta
vacio, se usa como fallback el archivo `.roorules` (legacy). Hay variantes
por modo: `.roo/rules-{modeSlug}/` y `.roorules-{modeSlug}`. Roo Code carga
`AGENTS.md` (o `AGENT.md`) del workspace por defecto, configurable con
`roo-cline.useAgentRules`. Fuente: [Custom Instructions - Roo Code](https://docs.roocode.com/features/custom-instructions).

Garantia honesta: en ambas herramientas estas reglas son instrucciones de
texto inyectadas en el system prompt. No hay bloqueo determinista equivalente
a los 159 `deny` de `opencode.json` / `kilo.json`; el cumplimiento depende
del modelo y solo los permisos nativos de cada extension (aprobaciones de
herramientas, auto-approve denylists, etc.) ofrecen control real de
ejecucion, tal como se advierte en "Verificacion completa".

## Verificacion completa

`scripts/verificar-proyecto.sh` conserva la verificacion completa existente
para entornos Unix con Bash. En cualquier sistema operativo, el requisito
portable minimo es ejecutar `doc_validator.py`; las comprobaciones adicionales
deben conectarse al sistema de tareas o CI nativo de cada proyecto.

No existe una configuracion universal que pueda imponer permisos de ejecucion
a todos los asistentes. Para obtener bloqueo real, hay que usar un sandbox o
los permisos nativos del asistente, ademas de estas reglas compartidas.

## Verificacion local sin nube

El proyecto no requiere cuentas en GitHub, GitLab ni ningun servicio cloud para
ser verificado. El task runner local esta en el `Makefile`:

```text
make check   # lint + tests + verificacion completa
make lint    # shellcheck y validacion JSON
make test    # doc_validator, parity de configs y symlinks
make sync    # sincroniza .kilo/agents con .opencode/agents
make hooks   # instala el hook pre-commit con backup
make clean   # limpia temporales de red-team
```

### Contenedor local

Tambien puedes usar el `Containerfile` para ejecutar la verificacion en un
entorno aislado y reproducible:

```text
podman build -t better-ai -f Containerfile .
podman run --rm better-ai
```

Esto garantiza que el proyecto puede verificarse sin depender de infraestructura
externa, cuentas de terceros ni API keys.

### CI local con Lefthook

[Lefthook](https://lefthook.dev/) es un gestor de hooks Git multiplataforma
(Windows, macOS, Linux) que no requiere cuenta en la nube. La configuracion esta
en `lefthook.yml`:

```text
make hooks-lefthook   # instala los hooks configurados
lefthook run pre-commit  # ejecuta los checks manualmente
```

Si Lefthook no esta instalado, `make hooks` sigue funcionando con el script
legacy `scripts/install-hooks.sh`.

### Workflow local con act

[act](https://nektos.github.io/act) ejecuta workflows de GitHub Actions en tu
maquina usando Docker/Podman. No requiere cuenta de GitHub ni sube nada:

```text
make ci-local
```

Esto ejecuta `.github/workflows/ci.yml` localmente. El archivo de workflow es
opcional: el proyecto funciona completamente sin el.

### Pipeline portable con Dagger

[Dagger](https://dagger.io/) permite definir pipelines como codigo y ejecutarlas
localmente o en cualquier CI. El ejemplo del proyecto esta en `ci/dagger.py`:

```text
make dagger
```

### CI self-hosted avanzado

Para equipos que necesiten un servidor de CI propio sin nube, opciones mas
potentes como Woodpecker CI o Tekton se pueden evaluar. No son obligatorias
para usar `better-ai`.
