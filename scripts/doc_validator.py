#!/usr/bin/env python3
"""Valida requisitos versionados y sus referencias en el código del proyecto."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REQUIREMENT_ID = re.compile(r"^REQ-[0-9]{3,}$")
REFERENCE = re.compile(r"\bREQ-[0-9]{3,}\b")
REQUIRED_FIELDS = {
    "id",
    "titulo",
    "estado",
    "prioridad",
    "version",
    "fecha_creacion",
}
VALID_STATES = {"Draft", "Aprobado", "Implementado", "Deprecado"}
VALID_PRIORITIES = {"MUST", "SHOULD", "COULD"}
CODE_SUFFIXES = {
    ".c",
    ".cc",
    ".cpp",
    ".go",
    ".java",
    ".js",
    ".jsx",
    ".php",
    ".py",
    ".rb",
    ".rs",
    ".sh",
    ".swift",
    ".ts",
    ".tsx",
}
EXCLUDED_DIRECTORIES = {".git", ".docs", ".venv", "node_modules", "venv"}


def parse_frontmatter(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise ValueError("falta el frontmatter YAML inicial")

    try:
        end = lines.index("---", 1)
    except ValueError as error:
        raise ValueError("falta el cierre del frontmatter YAML") from error

    fields: dict[str, str] = {}
    for line in lines[1:end]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line or line.startswith((" ", "\t")):
            raise ValueError(f"campo YAML invalido: {line!r}")
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if not key or not value:
            raise ValueError(f"campo YAML vacio: {line!r}")
        fields[key] = value
    return fields


def requirement_files(root: Path) -> list[Path]:
    directory = root / ".docs" / "requirements"
    if not directory.is_dir():
        raise ValueError("no existe .docs/requirements")
    return sorted(path for path in directory.glob("REQ-*.md") if path.is_file())


def collect_requirements(root: Path) -> tuple[dict[str, dict[str, str]], list[str]]:
    requirements: dict[str, dict[str, str]] = {}
    errors: list[str] = []
    for path in requirement_files(root):
        expected_id = path.stem
        if not REQUIREMENT_ID.fullmatch(expected_id):
            errors.append(f"{path}: nombre de archivo invalido")
            continue
        try:
            fields = parse_frontmatter(path)
        except ValueError as error:
            errors.append(f"{path}: {error}")
            continue
        missing = REQUIRED_FIELDS - fields.keys()
        if missing:
            errors.append(f"{path}: faltan campos {sorted(missing)}")
        if fields.get("id") != expected_id:
            errors.append(f"{path}: id no coincide con el nombre del archivo")
        if fields.get("estado") not in VALID_STATES:
            errors.append(f"{path}: estado invalido")
        if fields.get("prioridad") not in VALID_PRIORITIES:
            errors.append(f"{path}: prioridad invalida")
        requirements[expected_id] = fields
    if not requirements:
        errors.append("no hay archivos REQ-XXX.md")
    return requirements, errors


def source_files(root: Path):
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in CODE_SUFFIXES:
            continue
        if any(part in EXCLUDED_DIRECTORIES for part in path.parts):
            continue
        yield path


def validate_references(root: Path, requirements: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []
    for path in source_files(root):
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for reference in REFERENCE.findall(line):
                if reference not in requirements:
                    errors.append(f"{path}:{line_number}: requisito inexistente {reference}")
                elif requirements[reference].get("estado") == "Deprecado":
                    errors.append(f"{path}:{line_number}: requisito deprecado {reference}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        requirements, errors = collect_requirements(root)
    except ValueError as error:
        print(f"FALLO: {error}")
        return 1
    errors.extend(validate_references(root, requirements))
    if errors:
        for error in errors:
            print(f"FALLO: {error}")
        return 1
    print(f"OK: {len(requirements)} requisitos validos; referencias de codigo coherentes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
