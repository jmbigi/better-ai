#!/usr/bin/env python3
"""Verifica que opencode.json y kilo.json esten alineados donde deben serlo."""
import json
import sys


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    oc = load("opencode.json")
    kc = load("kilo.json")

    errores = []

    # Permisos bash/edit/read deben ser identicos
    for seccion in ("bash", "edit", "read"):
        if oc["permission"][seccion] != kc["permission"][seccion]:
            errores.append(f"permission.{seccion} difiere entre opencode.json y kilo.json")

    # Politicas de proveedores: estructura deny-all + allow list
    for nombre, cfg in (("opencode.json", oc), ("kilo.json", kc)):
        policies = cfg.get("experimental", {}).get("policies", [])
        if not policies or policies[0] != {
            "effect": "deny",
            "action": "provider.use",
            "resource": "*",
        }:
            errores.append(f"{nombre}: falta deny-all en experimental.policies")

    if errores:
        print("[FALLO] Paridad de configuracion:")
        for e in errores:
            print(f"  - {e}")
        sys.exit(1)

    print("[OK] Paridad de configuracion OK")


if __name__ == "__main__":
    main()
