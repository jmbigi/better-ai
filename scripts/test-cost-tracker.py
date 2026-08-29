#!/usr/bin/env python3
"""Tests funcionales del skill cost-tracker (P0.19, P1.30).

Verifica start, log, report y umbrales usando un directorio temporal para no
contaminar logs del usuario.
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

SKILL = Path(__file__).parent.parent / ".opencode/skills/cost-tracker/cost-tracker.py"


def run(args: list[str], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SKILL)] + args,
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )


def test_start_and_report() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "OPENCODE_COST_LOG_DIR": tmp}
        r1 = run(["start"], env=env)
        assert r1.returncode == 0, r1.stderr
        r2 = run(["report"], env=env)
        assert r2.returncode == 0, r2.stderr
        assert "Llamadas: 0" in r2.stdout
        assert "OK: dentro de umbrales" in r2.stdout


def test_log_and_thresholds() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "OPENCODE_COST_LOG_DIR": tmp}
        run(["start"], env=env)
        r = run(
            [
                "log",
                "--model", "opencode/deepseek-v4-flash-free",
                "--tokens-in", "1000",
                "--tokens-out", "500",
                "--latency-ms", "1200",
            ],
            env=env,
        )
        assert r.returncode == 0, r.stderr
        report = run(["report"], env=env)
        assert report.returncode == 0, report.stderr
        assert "Llamadas: 1" in report.stdout
        assert "Tokens: 1,000 in + 500 out = 1,500 total" in report.stdout
        assert "dentro de umbrales" in report.stdout


def main() -> int:
    tests = [test_start_and_report, test_log_and_thresholds]
    passed = 0
    failed = 0
    for t in tests:
        try:
            t()
            print(f"[OK] {t.__name__}")
            passed += 1
        except AssertionError as exc:
            print(f"[FALLO] {t.__name__}: {exc}")
            failed += 1
    print(f"\n{passed} OK, {failed} FALLOS")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
