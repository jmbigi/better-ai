#!/usr/bin/env python3
"""Test de determinismo de inferencia (P0.1, P0.19, P1.1, P1.9).

Ejecuta el mismo prompt sintetico complejo N veces contra un modelo de opencode
y calcula el Exact Match Ratio (EMR). Falla si el EMR < 0.95 (varianza > 5%).

Uso:
    python3 scripts/test-determinism.py [--runs N] [--model provider/model]
                                       [--seed INT] [--out FILE] [--max-time SEC]

Reglas del proyecto aplicadas:
    - P0.1: si la API da error, FALLA EXPLICITO (nunca inventa EMR ni salta).
    - P0.19: limites de tiempo/coste; reporta estimacion de tokens/coste.
    - P1.19/P1.26: sin fallbacks silenciosos (sin try/except que traguen errores).
    - P1.21: herramienta aislada; el integrador decide su uso.

NOTA (26-08-2026): la ejecucion real esta PENDIENTE de servicio de modelos
disponible (ver docs/ARQUITECTURA-DETERMINISMO.md seccion 5).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

DEFAULT_MODEL = os.environ.get("TEST_DETERMINISM_MODEL", "opencode-go/deepseek-v4-flash")
DEFAULT_PROMPT = (
    "Analiza si este codigo tiene errores silenciosos y propone una correccion. "
    "Responde en exactamente 4 bullets: 1) diagnostico 2) correccion 3) test "
    "4) evidencia. Codigo: def f(x):\n    try:\n        return x / 2\n    except:\n        pass"
)
# Precios estimados USD por 1M tokens (tabla de cost-optimizer, aprox).
PRICING = {
    "opencode/deepseek-v4-flash-free": (0.00, 0.00),
    "opencode-go/deepseek-v4-flash": (0.14, 0.28),
    "deepseek/deepseek-chat": (0.14, 0.28),
    "kilo-auto/free": (0.00, 0.00),
    "kilo-auto/efficient": (0.14, 0.28),
}
EMR_THRESHOLD = 0.95
MAX_RUNS = 20
DEFAULT_MAX_TIME = 1800


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Test de determinismo (EMR) vs opencode")
    p.add_argument("--runs", type=int, default=10, help="ejecuciones (max 20)")
    p.add_argument("--model", default=DEFAULT_MODEL, help="modelo provider/model")
    p.add_argument("--seed", type=int, default=None, help="semilla fija (solo experimental, ver docs)")
    p.add_argument("--prompt", default=DEFAULT_PROMPT, help="prompt sintetico a repetir")
    p.add_argument("--out", default=None, help="ruta opcional para reporte JSONL")
    p.add_argument("--max-time", type=int, default=DEFAULT_MAX_TIME, help="limite global en segundos")
    p.add_argument("--cmd-timeout", type=int, default=120, help="timeout por ejecucion en segundos")
    args = p.parse_args()
    if args.runs < 1 or args.runs > MAX_RUNS:
        p.error(f"--runs debe estar entre 1 y {MAX_RUNS} (P0.19: limite de consumo)")
    if args.seed is not None and not (0 <= args.seed < 2**31):
        p.error("--seed fuera de rango")
    return args


def run_once(args: argparse.Namespace, attempts: list[dict], idx: int) -> dict:
    """Ejecuta un run de opencode y devuelve el texto del asistente o FALLA."""
    cmd = ["opencode", "run", "--auto", "-m", args.model, "--format", "json", args.prompt]
    if args.seed is not None:
        # seed NO se pasa por CLI (opencode 1.18.23 no tiene flag --seed; ver
        # docs/ARQUITECTURA-DETERMINISMO.md seccion 6). Aviso explícito, sin
        # silenciar: el EMR resultante refleja el sampling sin semilla fija.
        print(f"[AVISO] --seed={args.seed} ignorado en la llamada CLI (sin flag nativo); "
              "el EMR reporta el sampling por defecto del modelo.")
    started = time.time()
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=args.cmd_timeout,
            cwd=os.environ.get("BETTER_AI_ROOT", str(Path(__file__).resolve().parent.parent)),
        )
    except subprocess.TimeoutExpired:
        raise SystemExit(f"[FALLO] run {idx + 1}: excedio {args.cmd_timeout}s (P0.19)") from None

    elapsed = time.time() - started
    if proc.returncode != 0:
        err = next(
            (json.loads(l).get("error", {}).get("name", "?") for l in proc.stdout.splitlines() if l.strip()),
            "desconocido",
        )
        raise SystemExit(
            f"[FALLO] run {idx + 1}: opencode termino con rc={proc.returncode} "
            f"(tipo={err}). Error del servicio o limite de modelo: no se reporta EMR (P0.1/P1.19). "
            f"stderr: {proc.stderr[:300]}"
        )

    text = extract_assistant_text(proc.stdout)
    if text is None:
        raise SystemExit(
            f"[FALLO] run {idx + 1}: no se pudo extraer texto del asistente del JSON de eventos. "
            "Revisar formato; no se inventa resultado (P0.2). Salida cruda: " + proc.stdout[:300]
        )
    return {"idx": idx + 1, "text": text, "elapsed_s": round(elapsed, 2), "model": args.model}


def extract_assistant_text(stdout: str) -> str | None:
    """Extrae el ultimo texto del asistente de los eventos JSON de opencode.

    El formato del CLI puede incluir eventos 'message' (role assistant) o 'part'.
    Se busca tolerando ambas formas; si ninguna aparece, devuelve None.
    """
    candidates: list[str] = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        etype = ev.get("type")
        if etype == "message" and ev.get("role") == "assistant":
            content = ev.get("content")
            if isinstance(content, str):
                candidates.append(content)
            elif isinstance(content, list):
                for part in content:
                    if isinstance(part, dict) and part.get("type") == "text":
                        candidates.append(part.get("text", ""))
        elif etype == "part":
            part = ev.get("part", {})
            if part.get("type") == "text" and ev.get("state", {}).get("status") == "completed":
                candidates.append(part.get("text", ""))
    return candidates[-1].strip() if candidates else None


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().lower()


def estimate_cost(model: str, prompt: str, answers: list[str]) -> tuple[int, int, float]:
    """Tokens y coste ESTIMADOS (aprox 4 chars/token). Declarado como estimacion (P0.1)."""
    in_tokens = sum(len(prompt) // 4 for _ in answers)
    out_tokens = sum(len(a) // 4 for a in answers)
    price_in, price_out = PRICING.get(model, (0.14, 0.28))
    cost = (in_tokens / 1_000_000 * price_in) + (out_tokens / 1_000_000 * price_out)
    return in_tokens, out_tokens, round(cost, 5)


def main() -> None:
    args = parse_args()
    print(f"== Test de determinismo (EMR >= {EMR_THRESHOLD:.0%}) ==")
    print(f"Modelo: {args.model} | Runs: {args.runs} | Seed: {args.seed if args.seed is not None else 'defecto'}")
    print(f"Prompt ({len(args.prompt)} chars): {args.prompt[:80]}...")
    print()

    started = time.time()
    results: list[dict] = []
    for i in range(args.runs):
        if time.time() - started > args.max_time:
            raise SystemExit(f"[FALLO] limite global de {args.max_time}s excedido (P0.19)")
        results.append(run_once(args, results, i))

    normalized = [normalize(r["text"]) for r in results]
    emr = sum(1 for n in normalized if n == normalized[0]) / len(normalized)
    latencies = [r["elapsed_s"] for r in results]
    in_tok, out_tok, cost = estimate_cost(args.model, args.prompt, results and [r["text"] for r in results])

    print("== Resultados ==")
    for r in results:
        match = "=" if normalize(r["text"]) == normalized[0] else "!="
        print(f"  run {r['idx']:02d} [{match}] {r['text'][:70]!r} ({r['elapsed_s']}s)")
    print(f"\nEMR: {emr:.2%} (umbral {EMR_THRESHOLD:.0%}) | Latencia p50={statistics.median(latencies):.1f}s")
    print(f"Tokens estimados (P0.1: ESTIMACION): in={in_tok} out={out_tok} | coste~${cost} USD (P0.19)\n")

    report = {
        "model": args.model, "runs": args.runs, "emr": emr,
        "latency_p50": statistics.median(latencies), "cost_est_usd": cost,
        "threshold": EMR_THRESHOLD, "seed": args.seed,
    }
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"Reporte: {args.out}")

    if emr >= EMR_THRESHOLD:
        print(f"OK: determinismo verificado (EMR >= {EMR_THRESHOLD:.0%})")
        sys.exit(0)
    raise SystemExit(f"[FALLO] EMR {emr:.2%} < umbral {EMR_THRESHOLD:.0%}: varianza > 5%, no reproducible")


if __name__ == "__main__":
    main()
