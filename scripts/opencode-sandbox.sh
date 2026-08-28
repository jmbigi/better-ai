#!/usr/bin/env bash
# Sandbox de opencode con bubblewrap: capa determinista del SISTEMA OPERATIVO
# (defensa en profundidad por encima de los deny de opencode.json, inspirada en el
# sandboxing de Codex/OpenAI). Si el matcher de permisos fallara o el modelo
# ignorara las reglas, el kernel sigue limitando el dano: toda la maquina en SOLO
# LECTURA salvo el workspace y las rutas de config/datos de opencode y git.
# Red BLOQUEADA por defecto (--unshare-net); activar con --net.
# Uso: bash scripts/opencode-sandbox.sh [--net] [--disable-sandbox] [argumentos de opencode...]
#      Ejemplos:
#        bash scripts/opencode-sandbox.sh run "resumen del proyecto"
#        bash scripts/opencode-sandbox.sh --net run "verifica una URL"
#        bash scripts/opencode-sandbox.sh --disable-sandbox run "comando"
set -u

# Flags opcionales
NET="--unshare-net"
DISABLE_SANDBOX=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --net)
            NET="--share-net"
            shift
            ;;
        --disable-sandbox)
            DISABLE_SANDBOX=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [ "$#" -eq 0 ]; then
    echo "Uso: bash scripts/opencode-sandbox.sh [--net] [--disable-sandbox] <comando opencode...>"
    exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
    echo "ERROR: opencode no esta en el PATH dentro de este entorno."
    exit 1
fi

# Pre-flight: si el usuario solicita explicitamente --disable-sandbox, saltamos
# bubblewrap sin mas preguntas (P1.8: obedece la orden explicita).
if [ "$DISABLE_SANDBOX" = true ]; then
    echo "AVISO: sandbox deshabilitado por --disable-sandbox."
    echo "         La unica proteccion restante son los deny/ask de opencode.json."
    exec opencode "$@"
fi

if ! command -v bwrap >/dev/null 2>&1; then
    echo "AVISO: bwrap (bubblewrap) no esta instalado."
    echo "         Ejecutando opencode SIN sandbox (solo proteccion de opencode.json)."
    echo "         Instala el paquete 'bubblewrap' para activar la capa de sandbox."
    exec opencode "$@"
fi

# Pre-flight funcional: verificar que bwrap puede crear un namespace minimo.
# Esto detecta kernels/user namespaces incompatibles antes de intentar lanzar
# opencode y evita el crash documentado del runtime Bun en ciertos kernels.
if ! bwrap --unshare-all --die-with-parent true >/dev/null 2>&1; then
    echo "AVISO: bubblewrap esta instalado pero no puede crear el namespace de sandbox"
    echo "         en este kernel (posible user namespace deshabilitado o incompatible)."
    echo "         Ejecutando opencode SIN sandbox (solo proteccion de opencode.json)."
    exec opencode "$@"
fi

# Workspace actual (absoluto) -> unico punto de escritura del filesystem.
WS="$(pwd -P)"

# Rutas de config/datos que opencode y git necesitan poder escribir.
CONFIG_OPTS=()
for ruta in "$HOME/.config/opencode" "$HOME/.local/share/opencode" "$HOME/.cache/opencode"; do
    if [ -d "$ruta" ]; then
        CONFIG_OPTS+=(--bind "$ruta" "$ruta")
    fi
done
# gitconfig global: de solo lectura si existe (git no necesita escribirlo para trabajar)
if [ -f "$HOME/.gitconfig" ]; then
    CONFIG_OPTS+=(--ro-bind "$HOME/.gitconfig" "$HOME/.gitconfig")
fi

# Rutas de credenciales: los directorios EXISTENTES se montan VACIOS (--tmpfs) para
# que el kernel no los exponga ni en lectura dentro del sandbox (refuerzo
# determinista de P0.6/P0.9, por encima de los denies de opencode.json). Si la ruta
# no existe en el host no hay nada que proteger (bwrap no puede crear el mount point
# sobre un arbol de solo lectura). ~/.netrc (archivo) se sustituye por uno vacio.
SECRET_OPTS=()
for ruta in "$HOME/.ssh" "$HOME/.aws" "$HOME/.gnupg"; do
    [ -d "$ruta" ] && SECRET_OPTS+=(--tmpfs "$ruta")
done
if [ -f "$HOME/.netrc" ]; then
    NETRC_DUMMY="$(mktemp)"
    SECRET_OPTS+=(--ro-bind "$NETRC_DUMMY" "$HOME/.netrc")
fi

exec bwrap \
    --die-with-parent \
    --new-session \
    "$NET" \
    --proc /proc \
    --dev /dev \
    --tmpfs /tmp \
    --ro-bind / / \
    "${SECRET_OPTS[@]}" \
    --bind "$WS" "$WS" \
    --bind /tmp/opencode /tmp/opencode \
    "${CONFIG_OPTS[@]}" \
    --chdir "$WS" \
    -- opencode "$@"
