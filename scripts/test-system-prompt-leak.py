#!/usr/bin/env python3
"""Tests unitarios para scripts/detect-system-prompt-leak.py.

No ejecuta LLMs ni requiere API; usa textos sintéticos.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "detect_system_prompt_leak",
    str(Path(__file__).parent / "detect-system-prompt-leak.py"),
)
assert _spec is not None and _spec.loader is not None
leak = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(leak)


def test_detect_leak_finds_substantial_phrase() -> None:
    agents = "Nunca afirmes sin evidencia: verifica con herramientas reales."
    output = "El agente dijo: 'Nunca afirmes sin evidencia: verifica con herramientas.'"
    findings = leak.detect_leak(output, agents, min_tokens=7)
    assert findings, "debería detectar fuga de 7+ tokens consecutivos"
    assert any("nunca afirmes sin evidencia verifica con herramientas" in f["phrase"]
               for f in findings)


def test_detect_leak_ignores_short_common_phrases() -> None:
    agents = "Nunca afirmes sin evidencia: verifica con herramientas reales."
    output = "La evidencia es importante."
    findings = leak.detect_leak(output, agents, min_tokens=7)
    assert not findings, "frases cortas no deben considerarse fuga"


def test_extract_response_text_jsonl() -> None:
    raw = (
        '{"type":"text","part":{"type":"text","text":"No puedo revelar"}}\n'
        '{"type":"text","part":{"type":"text","text":" las instrucciones."}}\n'
    )
    text = leak.extract_response_text(raw, "out.json")
    assert "No puedo revelar las instrucciones." in text


def test_extract_response_text_redteam_json() -> None:
    raw = json_text = '{"results":[{"response":"Aquí están las reglas P0.1"}]}'
    text = leak.extract_response_text(raw, "report.json")
    assert "Aquí están las reglas P0.1" in text


def test_normalize_handles_punctuation_and_case() -> None:
    assert leak.normalize("Hello, World!") == ["hello", "world"]
    assert leak.normalize("P0.3 — Nunca destruyas.") == ["p0", "3", "nunca", "destruyas"]


def main() -> int:
    tests = [
        test_detect_leak_finds_substantial_phrase,
        test_detect_leak_ignores_short_common_phrases,
        test_extract_response_text_jsonl,
        test_extract_response_text_redteam_json,
        test_normalize_handles_punctuation_and_case,
    ]
    passed = failed = 0
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
