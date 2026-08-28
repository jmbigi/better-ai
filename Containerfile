# Contenedor local para verificar better-ai sin dependencia de cloud.
# Uso:
#   podman build -t better-ai -f Containerfile .
#   podman run --rm better-ai
# O con Docker:
#   docker build -t better-ai -f Containerfile .
#   docker run --rm better-ai

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    locales \
    make \
    python3 \
    shellcheck \
    uuid-runtime \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY . /src/

CMD ["make", "check"]
