#!/usr/bin/env python3
"""Colector de métricas de consumo para opencode (P0.19, P1.30).

Uso:
    cost-tracker.py start
    cost-tracker.py log --model MODEL --tokens-in N --tokens-out N --latency-ms N [--call-type TYPE]
    cost-tracker.py report
    cost-tracker.py status

Registra cada llamada en JSONL bajo /tmp/opencode/cost-tracker-YYYY-MM-DD.jsonl
y reporta uso acumulado, coste estimado y umbrales configurables.
"""

from __future__ import annotations

import argparse
import json
import os
import statistics
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_LOG_DIR = Path(os.environ.get("OPENCODE_COST_LOG_DIR", "/tmp/opencode"))
DEFAULT_LOG_DIR.mkdir(parents=True, exist_ok=True)

LOG_FILE = DEFAULT_LOG_DIR / f"cost-tracker-{datetime.now(timezone.utc).strftime('%Y-%m-%d')}.jsonl"

PRICING = {
    "opencode/deepseek-v4-flash-free": (0.0, 0.0),
    "opencode-go/deepseek-v4-flash": (0.14, 0.28),
    "deepseek/deepseek-chat": (0.14, 0.28),
    "kilo-auto/free": (0.0, 0.0),
    "kilo-auto/efficient": (0.14, 0.28),
}

THRESHOLDS = {
    "tokens": 1_000_000,
    "cost_usd": 5.0,
    "time_min": 30,
}


def load_entries() -> list[dict]:
    if not LOG_FILE.exists():
        return []
    entries = []
    with open(LOG_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return entries


def estimate_cost(model: str, tokens_in: int, tokens_out: int) -> float:
    pin, pout = PRICING.get(model, (0.14, 0.28))
    return (tokens_in / 1_000_000 * pin) + (tokens_out / 1_000_000 * pout)


def cmd_start(args: argparse.Namespace) -> int:
    session_id = os.environ.get("SESSION_ID") or f"ct_{int(time.time())}"
    entry = {
        "event": "session_start",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "session_id": session_id,
        "thresholds": THRESHOLDS,
    }
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")
    print(f"[OK] Sesion iniciada: {session_id}")
    print(f"[INFO] Log: {LOG_FILE}")
    return 0


def cmd_log(args: argparse.Namespace) -> int:
    if args.tokens_in < 0 or args.tokens_out < 0 or args.latency_ms < 0:
        print("[FALLO] tokens y latencia deben ser >= 0", file=sys.stderr)
        return 1
    cost = estimate_cost(args.model, args.tokens_in, args.tokens_out)
    entry = {
        "event": "model_call",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "model": args.model,
        "tokens_in": args.tokens_in,
        "tokens_out": args.tokens_out,
        "cost_usd": round(cost, 6),
        "latency_ms": args.latency_ms,
        "call_type": args.call_type or "chat",
    }
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")
    print(f"[OK] Llamada registrada: {args.model} | in={args.tokens_in} out={args.tokens_out} cost=${cost:.6f}")
    return 0


def _summarize(entries: list[dict]) -> dict:
    calls = [e for e in entries if e.get("event") == "model_call"]
    starts = [e for e in entries if e.get("event") == "session_start"]
    total_in = sum(c.get("tokens_in", 0) for c in calls)
    total_out = sum(c.get("tokens_out", 0) for c in calls)
    total_tokens = total_in + total_out
    total_cost = sum(c.get("cost_usd", 0) for c in calls)
    latencies = [c.get("latency_ms", 0) for c in calls]
    models: dict[str, int] = {}
    for c in calls:
        models[c.get("model", "unknown")] = models.get(c.get("model", "unknown"), 0) + 1
    session_start = datetime.fromisoformat(starts[0]["timestamp"]) if starts else None
    elapsed_min = (time.time() - session_start.timestamp()) / 60 if session_start else 0.0
    return {
        "calls": len(calls),
        "tokens_in": total_in,
        "tokens_out": total_out,
        "total_tokens": total_tokens,
        "total_cost_usd": total_cost,
        "latencies": latencies,
        "models": models,
        "elapsed_min": elapsed_min,
    }


def _format_report(summary: dict) -> str:
    lines = []
    lines.append("=== COST TRACKER REPORT ===")
    lines.append(f"Llamadas: {summary['calls']}")
    lines.append(f"Tokens: {summary['tokens_in']:,} in + {summary['tokens_out']:,} out = {summary['total_tokens']:,} total")
    lines.append(f"Coste estimado: ${summary['total_cost_usd']:.6f} USD")
    if summary["latencies"]:
        lines.append(
            f"Latencia: p50={statistics.median(summary['latencies']):.0f}ms "
            f"p95={percentile(summary['latencies'], 95):.0f}ms "
            f"max={max(summary['latencies']):.0f}ms"
        )
    if summary["models"]:
        lines.append(f"Modelos: {summary['models']}")
    lines.append(f"Tiempo transcurrido: {summary['elapsed_min']:.1f} min")

    tokens_pct = summary["total_tokens"] / THRESHOLDS["tokens"] * 100
    cost_pct = summary["total_cost_usd"] / THRESHOLDS["cost_usd"] * 100
    time_pct = summary["elapsed_min"] / THRESHOLDS["time_min"] * 100
    lines.append(f"Umbrales: tokens={tokens_pct:.1f}% cost={cost_pct:.1f}% time={time_pct:.1f}%")

    if any(p >= 100 for p in (tokens_pct, cost_pct, time_pct)):
        lines.append("🛑 BLOQUEADO: umbral maximo alcanzado. Requiere confirmacion explicita para continuar.")
    elif any(p >= 80 for p in (tokens_pct, cost_pct, time_pct)):
        lines.append("⚠️ WARNING: umbral >= 80%. Considera reducir alcance o cambiar a modelo gratuito.")
    else:
        lines.append("✅ OK: dentro de umbrales.")
    return "\n".join(lines)


def percentile(data: list[float], pct: float) -> float:
    if not data:
        return 0.0
    s = sorted(data)
    k = (len(s) - 1) * pct / 100
    f = int(k)
    c = min(f + 1, len(s) - 1)
    if f == c:
        return s[f]
    return s[f] + (s[c] - s[f]) * (k - f)


def cmd_report(args: argparse.Namespace) -> int:
    entries = load_entries()
    if not entries:
        print("[INFO] No hay entradas registradas aun.")
        return 0
    summary = _summarize(entries)
    print(_format_report(summary))
    return 0


def cmd_status(args: argparse.Namespace) -> int:
    return cmd_report(args)


def main() -> int:
    parser = argparse.ArgumentParser(description="Rastrea tokens, coste y latencia de sesiones de IA")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("start", help="inicia una sesion de tracking")

    p_log = sub.add_parser("log", help="registra una llamada al modelo")
    p_log.add_argument("--model", required=True)
    p_log.add_argument("--tokens-in", type=int, required=True)
    p_log.add_argument("--tokens-out", type=int, required=True)
    p_log.add_argument("--latency-ms", type=int, required=True)
    p_log.add_argument("--call-type", default="chat")

    sub.add_parser("report", help="muestra reporte acumulado")
    sub.add_parser("status", help="alias de report")

    args = parser.parse_args()
    if args.command == "start":
        return cmd_start(args)
    if args.command == "log":
        return cmd_log(args)
    if args.command in ("report", "status"):
        return cmd_report(args)
    return 1


if __name__ == "__main__":
    sys.exit(main())
