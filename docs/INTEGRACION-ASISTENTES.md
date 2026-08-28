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
| GitHub Copilot | `AGENTS.md` + `.github/copilot-instructions.md` | Instrucciones de trabajo; no sustituye un sandbox ni bloquea comandos por si solo. |
| Otros asistentes | `AGENTS.md` y el contrato `.docs/requirements/` | Depende de si el asistente lee esos formatos y ejecuta el validador. |

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
