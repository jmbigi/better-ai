#!/usr/bin/env python3
"""Análisis estático de comandos shell para detectar patrones peligrosos.

Usa únicamente la stdlib de Python (shlex) para no añadir dependencias externas
(P0.18). Detecta:

- Pipes donde una fuente de red (curl/wget/fetch) alimenta un intérprete shell.
- Uso de eval/exec/source.
- Command substitution $(...) o `...` con descargadores dentro.

Limitaciones conocidas: no es un parser completo de Bash. Construcciones muy
retorcidas pueden escapar, pero cubre las variantes documentadas en P0.8.
"""

import shlex
from typing import List, Set

DOWNLOADERS = {"curl", "wget", "fetch"}
SHELL_NAMES = {"bash", "sh", "zsh", "ksh", "dash", "csh", "tcsh"}
EVAL_LIKE = {"eval", "exec", "source", "."}
SUDO = "sudo"


def tokenize(cmd: str) -> List[str]:
    """Tokeniza un comando shell respetando comillas y separadores."""
    lexer = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    return list(lexer)


def split_into_commands(tokens: List[str]) -> List[List[List[str]]]:
    """Divide tokens en comandos y cada comando en etapas de pipeline.

    Retorna una lista de comandos; cada comando es una lista de etapas;
    cada etapa es una lista de tokens.
    """
    commands: List[List[List[str]]] = []
    current_command: List[List[str]] = [[]]
    has_content = False

    for tok in tokens:
        if tok in (";", "&&", "||"):
            if has_content:
                commands.append(current_command)
            current_command = [[]]
            has_content = False
        elif tok == "|":
            current_command.append([])
            has_content = True
        else:
            current_command[-1].append(tok)
            has_content = True

    if has_content:
        commands.append(current_command)

    return commands


def _basename(token: str) -> str:
    """Devuelve el nombre base de una ruta, sin comillas."""
    # Quitar posibles comillas residuales (shlex posix ya las quita, pero por si acaso).
    token = token.strip("'\"")
    if "/" in token:
        return token.rsplit("/", 1)[-1]
    return token


def is_downloader(tokens: List[str], index: int = 0) -> bool:
    """True si el token en index es un descargador conocido."""
    if not tokens or index >= len(tokens):
        return False
    return _basename(tokens[index]) in DOWNLOADERS


def is_shell(tokens: List[str], index: int = 0) -> bool:
    """True si el token en index es un intérprete shell (o sudo + shell)."""
    if not tokens or index >= len(tokens):
        return False
    name = _basename(tokens[index])
    if name in SHELL_NAMES:
        return True
    if name == SUDO and index + 1 < len(tokens):
        return _basename(tokens[index + 1]) in SHELL_NAMES
    return False


def is_eval_like(tokens: List[str], index: int = 0) -> bool:
    """True si el token en index es eval/exec/source."""
    if not tokens or index >= len(tokens):
        return False
    return _basename(tokens[index]) in EVAL_LIKE


def _extract_substitution(token: str) -> List[str]:
    """Si el token es $(...) o `...`, devuelve el contenido interno."""
    inner: List[str] = []
    if token.startswith("$(") and token.endswith(")"):
        inner.append(token[2:-1])
    elif token.startswith("`") and token.endswith("`") and len(token) > 1:
        inner.append(token[1:-1])
    return inner


def analyze_stage(stage: List[str]) -> Set[str]:
    """Analiza una etapa de pipeline (sin pipes internos)."""
    findings: Set[str] = set()
    if not stage:
        return findings

    # eval / exec / source
    if is_eval_like(stage):
        findings.add(f"eval-like: {' '.join(stage[:4])}")

    # bash -c "$(curl ...)" (bypass común de los patterns de comodines)
    if is_shell(stage) and "-c" in stage:
        for tok in stage:
            for inner in _extract_substitution(tok):
                if any(dl in inner for dl in DOWNLOADERS):
                    findings.add(f"shell-c-with-downloader: {' '.join(stage[:4])}")

    # command substitution peligrosa dentro de la etapa (recursivo)
    for tok in stage:
        for inner in _extract_substitution(tok):
            findings.update(analyze(inner))

    return findings


def analyze_pipeline(stages: List[List[str]]) -> Set[str]:
    """Analiza un pipeline completo (varias etapas separadas por |)."""
    findings: Set[str] = set()
    if not stages:
        return findings

    # Detección de pipe peligroso: descargador -> shell
    if len(stages) >= 2:
        source = stages[0]
        sink = stages[-1]
        if is_downloader(source) and is_shell(sink):
            findings.add(
                f"dangerous-pipe: {' '.join(source[:4])} | ... | {' '.join(sink[:4])}"
            )

    # Analizar cada etapa por separado
    for stage in stages:
        findings.update(analyze_stage(stage))

    return findings


def analyze(cmd: str) -> List[str]:
    """Analiza un comando shell y devuelve la lista de hallazgos ordenada."""
    try:
        tokens = tokenize(cmd)
    except ValueError as exc:
        # Falla explícita: no tragamos errores de tokenización (P1.26).
        raise ValueError(f"No se pudo tokenizar el comando: {cmd!r}: {exc}") from exc

    commands = split_into_commands(tokens)
    findings: Set[str] = set()
    for pipeline in commands:
        findings.update(analyze_pipeline(pipeline))

    return sorted(findings)


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Uso: python3 scripts/analyze_shell.py '<comando shell>'", file=sys.stderr)
        sys.exit(1)

    result = analyze(sys.argv[1])
    if result:
        print("\n".join(result))
        sys.exit(1)
    sys.exit(0)
