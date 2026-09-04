# Security Policy / Politica de seguridad

> Idioma (decision declarada): este archivo esta en ingles porque es la convencion
> esperada por auditorias de seguridad y por GitHub (SECURITY.md se muestra al
> abrir un advisory privado). Se incluye un resumen en español al final.

## Supported versions

better-ai es un ruleset de configuracion + scripts, no una libreria versionada
con releases. La rama `main` es la unica version soportada. Los reportes contra
estados antiguos del historial se aceptan pero pueden tener menor prioridad.

## Reporting a vulnerability (private channel)

**Please do NOT open a public issue for security vulnerabilities.**

1. **Preferred: GitHub private vulnerability reporting.**
   [PENDIENTE (manual step for the repo owner): enable "Private vulnerability
   reporting" in Settings > Code security and analysis. This cannot be enabled
   by contributors; until it is enabled, use the interim channel below.]
   See: <https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository>

2. **Interim channel (until private reporting is enabled).** Open a public
   issue that says ONLY that you have a security report (title:
   "Security report — request private channel"), with NO payload, NO details
   and NO affected files. A maintainer will contact you to arrange a private
   channel. Never include the vulnerability details in the public issue.

We follow coordinated vulnerability disclosure (CVD):
<https://github.blog/security/vulnerability-research/coordinated-vulnerability-disclosure-cvd-open-source-projects/>

Reference guide: <https://github.com/google/oss-vulnerability-guide>

## Response SLA

- **Acknowledgement:** within 72 hours of receipt.
- **Triage / severity assignment:** within 7 days.
- **Public disclosure:** coordinated with the reporter; default timeline is 90
  days after acknowledgement (may be shortened for actively exploited issues or
  extended by mutual agreement).

## Severity definitions (this project)

better-ai's threat model is an AI agent running with the user's permissions;
the "impact" of a vulnerability is what the agent is tricked into doing.

| Severity | Definition |
|---|---|
| **Critical** | Evasion of P0 `deny` patterns (or of `scripts/probar-denies.sh` coverage) enabling destructive execution: data loss (`rm -rf`), credential theft, production modification, system changes. |
| **High** | Evasion of any deterministic `deny` pattern in `opencode.json` / `kilo.json` (e.g., via wrapper variants, env-var tricks, encoding) that the fuzzer does not already cover, without confirmed destructive impact. |
| **Medium** | Bypass of text-level rules (AGENTS.md): techniques that make an agent systematically ignore P0/P1 rules without a technical bypass of the matcher (note: a single LLM "not following instructions" run is not a vulnerability — see out-of-scope below). |
| **Low** | Security-relevant documentation errors, misleading claims about coverage, or gaps in verification scripts that do not (yet) enable an evasion. |

## Scope

### In scope (is a vulnerability)

- Evasion of the bash `deny` matcher in `opencode.json` / `kilo.json` (regex
  bypass, encoding, wrapper commands, absolute-path variants).
- Bypass of the plugin/guard layer (`scripts/hooks/`, lefthook rules) or of
  `scripts/check-shell-pipes.py` / `scripts/fuzz-denies.py` logic.
- Sandbox escapes or weaknesses in `scripts/opencode-sandbox.sh` /
  `scripts/opencode-docker.sh` isolation.
- Prompt-injection techniques (LLM01/LLM07/LLM08) that reliably produce
  repeatable, reproducible exfiltration or policy override in the agent, with
  evidence.
- System prompt leakage (LLM07) beyond what `scripts/detect-system-prompt-leak.py`
  detects, with evidence.

### Out of scope (not a vulnerability)

- An LLM ignoring text rules (AGENTS.md) in an isolated run with no technical
  bypass: rules de texto no son frontera de seguridad (see AGENTS.md P0.13);
  only deterministic-layer bypasses count.
- Vulnerabilities in upstream tools (opencode, kilocode, Bun, models
  themselves) — report those to their projects; we only track interaction with
  our guardrails.
- Denial of service against the verification scripts by resource exhaustion.

## Red-team payload contributions (community)

We welcome red-team payloads for `scripts/redteam-prompt-injection.py` and
`scripts/probar-denies.sh`, mapped to the OWASP GenAI taxonomy
(LLM01 Prompt Injection, LLM07 System Prompt Leakage, LLM08 Excessive Agency,
+ ASI: Agentic Systems Initiative items where applicable). These are submitted
via **public issues** using the "Red-team payload" template
(`.github/ISSUE_TEMPLATE/redteam-payload.md`).

Per project rule P0.8, third-party payloads are untrusted input: **maintainers
will review every payload before executing it**, and the template requires the
contributor to confirm they tested it in their own environment. Do not include
secrets, personal data, or live credentials in payloads — use placeholders.

## Hall of fame

Reporters who report valid in-scope vulnerabilities (Critical/High) will be
credited here (with their consent) after coordinated disclosure.

| Reporter | Finding | Date |
|---|---|---|
| _(none yet)_ | | |

---

## Resumen en español

- Reporta vulnerabilidades por el canal PRIVADO (private vulnerability reporting
  de GitHub — pendiente activarlo en Settings, paso manual del dueno). Canal
  provisional hasta activarlo: abre un issue publico que diga SOLO que tienes
  un reporte de seguridad ("Security report — request private channel"), SIN
  payload ni detalles; un mantenedor te contactara por via privada.
- SLA: acuse en 72 h, divulgacion coordinada por defecto a 90 dias.
- Severidades: Critical = evasion de denies P0 con ejecucion destructiva;
  High = evasion de deny determinista; Medium = bypass de reglas de texto;
  Low = documentacion.
- En scope: evasion del matcher, bypass del plugin/guard, fallos del sandbox,
  prompt injection reproducible (LLM01/LLM07/LLM08). Fuera de scope: que un LLM
  ignore reglas de texto sin bypass tecnico.
- Payloads de red-team comunitarios: bienvenidos via issues con template;
  P0.8 — los mantenedores revisan antes de ejecutar.
