#!/usr/bin/env bash
# Sandbox de opencode con Docker: capa determinista del SISTEMA OPERATIVO
# (REQ-004). Sustituye a scripts/opencode-sandbox.sh (bubblewrap), cuyo
# runtime Bun crashea en los user namespaces de este kernel (README.md:50,
# docs/PRUEBAS.md:554). Si el matcher de permisos fallara o el modelo ignorara
# las reglas, el contenedor sigue limitando el dano: filesystem raiz SOLO
# LECTURA, workspace de solo lectura, rutas de datos de opencode de
# lectura/escritura, red BLOQUEADA por defecto, sin capabilities ni privilegios.
# Uso: bash scripts/opencode-docker.sh [--net] [argumentos de opencode...]
#      Ejemplos:
#        bash scripts/opencode-docker.sh run "resumen del proyecto"
#        bash scripts/opencode-docker.sh --net run "verifica una URL"
set -u

NET="none"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --net)
            NET="bridge"
            shift
            ;;
        --help|-h)
            echo "Uso: bash scripts/opencode-docker.sh [--net] <comando...> (por defecto: opencode)"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

# Sin argumentos, el ENTRYPOINT de la imagen arranca opencode en modo TUI.

# Pre-flight: docker instalado y daemon accesible (fail fast, P1.19/P1.26).
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker no esta instalado o no esta en el PATH."
    echo "         Instala Docker para usar la capa de sandbox (REQ-004)."
    exit 1
fi
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: el daemon de docker no responde (docker info fallo)."
    echo "         Inicia el servicio y reintenta. No se ejecuta nada sin sandbox."
    exit 1
fi

# Workspace actual (absoluto): unico punto del host montado, de SOLO LECTURA.
WS="$(pwd -P)"

# HOME del contenedor (usuario sin privilegios de la imagen). El wrapper corre
# el contenedor con el uid/gid del host, asi que este usuario solo da nombre.
CHOME="/home/opencode"

# Rutas de config/datos de opencode. Solo se montan rw si existen en el host.
DATA_OPTS=()
for ruta in ".local/share/opencode" ".config/opencode" ".cache/opencode"; do
    if [ -d "$HOME/$ruta" ]; then
        DATA_OPTS+=(--volume "$HOME/$ruta:$CHOME/$ruta")
    fi
done
# gitconfig global: de solo lectura si existe (git no necesita escribirlo).
if [ -f "$HOME/.gitconfig" ]; then
    DATA_OPTS+=(--volume "$HOME/.gitconfig:$CHOME/.gitconfig:ro")
fi

# Mismo uid/gid que en el host: los binds rw de las rutas de datos pertenecen
# al usuario del host y asi el contenedor puede escribirlos (fail fast si id falla).
USER_ID="$(id -u)" || { echo "ERROR: no se pudo obtener el uid actual."; exit 1; }
GROUP_ID="$(id -g)" || { echo "ERROR: no se pudo obtener el gid actual."; exit 1; }

# -t solo con terminal real; sin TTY (scripts/CI) docker run -t fallaria.
TTY_OPTS="-i"
if [ -t 0 ] && [ -t 1 ]; then
    TTY_OPTS="-it"
fi

# docker run es la ultima orden: su codigo de salida queda como el del script.
docker run --rm $TTY_OPTS \
    --user "$USER_ID:$GROUP_ID" \
    --env HOME="$CHOME" \
    --network "$NET" \
    --read-only \
    --tmpfs /tmp \
    --tmpfs "$CHOME/.local:uid=$USER_ID,gid=$GROUP_ID" \
    --tmpfs "$CHOME/.config:uid=$USER_ID,gid=$GROUP_ID" \
    --tmpfs "$CHOME/.cache:uid=$USER_ID,gid=$GROUP_ID" \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --volume "$WS:/workspace:ro" \
    "${DATA_OPTS[@]}" \
    --workdir /workspace \
    better-ai-opencode "$@"
