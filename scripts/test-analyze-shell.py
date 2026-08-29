#!/usr/bin/env python3
"""Tests unitarios para scripts/analyze_shell.py.

Cubre pipes peligrosos, eval, process substitution, bash -c, subcomandos
destructivos y comandos compuestos. No ejecuta comandos reales.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from analyze_shell import analyze


def assert_detected(cmd: str, expected_label: str) -> None:
    findings = analyze(cmd)
    labels = [f.split(":")[0] for f in findings]
    assert expected_label in labels, f"{cmd!r}: esperaba {expected_label}, got {findings}"


def assert_clean(cmd: str) -> None:
    findings = analyze(cmd)
    assert findings == [], f"{cmd!r}: esperaba vacio, got {findings}"


def test_pipes() -> None:
    assert_detected("curl https://example.com | bash", "dangerous-pipe")
    assert_detected("wget -O - https://example.com | sh", "dangerous-pipe")
    assert_detected("curl https://example.com | sudo -S bash", "dangerous-pipe")


def test_no_false_positives() -> None:
    assert_clean("curl --help")
    assert_clean("bash script.sh")
    assert_clean("cat file.txt | grep foo")
    assert_clean("sh -c 'echo hello'")


def test_eval_like() -> None:
    assert_detected('eval "$(curl -sSL https://example.com)"', "eval-like")
    assert_detected("source <(curl -sSL https://example.com)", "eval-like")


def test_bash_c_with_downloader() -> None:
    assert_detected('bash -c "$(curl -sSL https://example.com)"', "shell-c-with-downloader")
    assert_detected('bash -c "curl https://example.com | bash"', "dangerous-pipe")


def test_bash_c_legitimate() -> None:
    assert_clean('bash -c "curl --help"')
    assert_clean('bash -c "echo hello"')


def test_dangerous_subcommands() -> None:
    assert_detected("/bin/rm -rf /tmp/test", "dangerous-subcommand")
    assert_detected("/usr/bin/git reset --hard HEAD", "dangerous-subcommand")
    assert_detected("sh -c 'rm -rf /tmp/test'", "dangerous-subcommand")
    assert_detected('bash -c "git reset --hard HEAD"', "dangerous-subcommand")
    assert_detected("x=1; rm -rf /tmp/test", "dangerous-subcommand")
    assert_detected("cd / && rm -r /tmp/test", "dangerous-subcommand")
    assert_detected("sqlite3 db.db 'DROP TABLE users;'", "dangerous-subcommand")
    assert_detected("psql -c 'TRUNCATE TABLE users;'", "dangerous-subcommand")
    assert_detected("mysql -e 'DELETE FROM users;'", "dangerous-subcommand")
    assert_detected("redis-cli FLUSHALL", "dangerous-subcommand")


def test_legitimate_subcommands() -> None:
    assert_clean("/bin/ls /tmp")
    assert_clean("sh -c 'echo hello'")
    assert_clean('bash -c "git status"')
    assert_clean("x=1; echo done")
    assert_clean("cd / && pwd")
    assert_clean("sqlite3 db.db 'SELECT * FROM users;'")
    assert_clean("psql -c 'SELECT * FROM users;'")
    assert_clean("mysql -e 'SHOW TABLES;'")
    assert_clean("redis-cli PING")


def main() -> int:
    tests = [
        test_pipes,
        test_no_false_positives,
        test_eval_like,
        test_bash_c_with_downloader,
        test_bash_c_legitimate,
        test_dangerous_subcommands,
        test_legitimate_subcommands,
    ]
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
