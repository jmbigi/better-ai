#!/usr/bin/env python3
"""Matriz de pruebas de seguridad para better-ai.

Ejecuta los tests de seguridad existentes de forma consolidada y genera un
reporte JSON/TXT. Los tests que requieren el runtime de opencode (red-team de
denies y prompt injection) se marcan como opcionales y se omiten en modo
--offline.

Uso:
    python3 scripts/safety-test-matrix.py [--offline] [--out /tmp/reporte.json]
    python3 scripts/safety-test-matrix.py list
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
REPORT_DIR = Path("/tmp")
DEFAULT_TIMEOUT = 300

# Cada test: (nombre, comando, requiere_runtime, descripción)
TESTS = [
    (
        "fuzz-denies",
        ["python3", "scripts/fuzz-denies.py"],
        False,
        "Fuzzing de evasion de patrones deny de opencode.json/kilo.json",
    ),
    (
        "check-shell-pipes",
        ["python3", "scripts/check-shell-pipes.py"],
        False,
        "Deteccion de pipes y subcomandos destructivos",
    ),
    (
        "test-analyze-shell",
        ["python3", "scripts/test-analyze-shell.py"],
        False,
        "Tests unitarios del analizador semantico de shell",
    ),
    (
        "test-fuzz-denies",
        ["python3", "scripts/test-fuzz-denies.py"],
        False,
        "Tests unitarios del fuzzer de denies",
    ),
    (
        "detect-system-prompt-leak",
        ["python3", "scripts/detect-system-prompt-leak.py", "--help"],
        False,
        "Detector de system prompt leakage operativo (py_compile + --help)",
    ),
    (
        "redteam-prompt-injection-help",
        ["python3", "scripts/redteam-prompt-injection.py", "--help"],
        False,
        "Red-team de prompt injection operativo (py_compile + --help)",
    ),
    (
        "probar-denies",
        ["bash", "scripts/probar-denies.sh"],
        True,
        "Red-team de los 154 deny contra el matcher REAL de opencode (requiere opencode)",
    ),
    (
        "redteam-prompt-injection",
        ["python3", "scripts/redteam-prompt-injection.py"],
        True,
        "Red-team de prompt injection contra un modelo opencode (requiere opencode + API)",
    ),
]


def run_test(name, command, requires_runtime, offline, timeout):
    """Ejecuta un test y devuelve un dict con resultado."""
    if requires_runtime and offline:
        return {
            "name": name,
            "status": "SKIP",
            "duration_ms": 0,
            "stdout": "",
            "stderr": "",
            "requires_runtime": True,
            "reason": "omitted in --offline mode",
        }

    start = time.time()
    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        duration = int((time.time() - start) * 1000)
        ok = result.returncode == 0
        return {
            "name": name,
            "status": "PASS" if ok else "FAIL",
            "duration_ms": duration,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "requires_runtime": requires_runtime,
        }
    except subprocess.TimeoutExpired as exc:
        duration = int((time.time() - start) * 1000)
        return {
            "name": name,
            "status": "FAIL",
            "duration_ms": duration,
            "returncode": None,
            "stdout": exc.stdout or "",
            "stderr": exc.stderr or "",
            "requires_runtime": requires_runtime,
            "reason": f"timeout after {timeout}s",
        }
    except Exception as exc:  # noqa: BLE001 - reportamos cualquier error de ejecucion
        duration = int((time.time() - start) * 1000)
        return {
            "name": name,
            "status": "FAIL",
            "duration_ms": duration,
            "returncode": None,
            "stdout": "",
            "stderr": str(exc),
            "requires_runtime": requires_runtime,
            "reason": "execution error",
        }


def list_tests():
    print("Tests disponibles:")
    for name, command, requires_runtime, description in TESTS:
        flag = " (requiere runtime opencode)" if requires_runtime else ""
        print(f"  - {name}{flag}")
        print(f"    {description}")
        print(f"    comando: {' '.join(command)}")


def main():
    parser = argparse.ArgumentParser(
        description="Matriz de pruebas de seguridad de better-ai"
    )
    parser.add_argument(
        "--offline",
        action="store_true",
        help="Omitir tests que requieren el runtime de opencode",
    )
    parser.add_argument(
        "--out",
        type=str,
        default=None,
        help="Ruta del reporte JSON (default: /tmp/better-ai-safety-matrix-<timestamp>.json)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help=f"Timeout por test en segundos (default: {DEFAULT_TIMEOUT})",
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=["list"],
        help="Subcomando: list muestra los tests disponibles",
    )
    args = parser.parse_args()

    if args.command == "list":
        list_tests()
        return 0

    offline = args.offline or not shutil_which("opencode")
    if offline and not args.offline:
        print("[INFO] opencode no encontrado en PATH; activando modo --offline automaticamente")

    results = []
    overall_start = time.time()

    for name, command, requires_runtime, description in TESTS:
        print(f"[RUN] {name} ... ", end="", flush=True)
        result = run_test(name, command, requires_runtime, offline, args.timeout)
        results.append(result)
        print(result["status"])
        if result["status"] == "FAIL":
            # Imprimir breve diagnostico para facilitar depuracion
            if result.get("stderr"):
                err = result["stderr"].strip().splitlines()[0][:200]
                print(f"      -> {err}")

    overall_duration = int((time.time() - overall_start) * 1000)

    passed = sum(1 for r in results if r["status"] == "PASS")
    failed = sum(1 for r in results if r["status"] == "FAIL")
    skipped = sum(1 for r in results if r["status"] == "SKIP")

    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "offline": offline,
        "overall": {
            "total": len(results),
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "duration_ms": overall_duration,
        },
        "results": results,
    }

    out_path = args.out
    if out_path is None:
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        out_path = REPORT_DIR / f"better-ai-safety-matrix-{ts}.json"
    else:
        out_path = Path(out_path)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print()
    print(f"Resultado: {passed} PASS, {failed} FAIL, {skipped} SKIP ({len(results)} total)")
    print(f"Reporte: {out_path}")

    return 1 if failed > 0 else 0


def shutil_which(cmd):
    """Implementacion ligera de shutil.which sin importar shutil al cargar."""
    for path in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(path) / cmd
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    return None


if __name__ == "__main__":
    sys.exit(main())
