# Políticas OPA/Rego de better-ai
# Prototipo de policy-as-code para reglas P0 críticas.
# Uso: opa test policies/  (o bash scripts/opa-check.sh)

package betterai.p0

import rego.v1

# Input esperado:
# {
#   "agent": "opencode|kilo|...",
#   "action": "bash|edit|read|...",
#   "command": "rm -rf /tmp/foo",
#   "env": { "ENV": "prod" }
# }

# Lista de patrones peligrosos que siempre se deniegan (P0.3, P0.4, P0.5, P0.8)
deny_patterns := [
    # Destrucción (P0.3)
    "rm -rf ",
    "rm -r ",
    "rm -f ",
    # Git destructivo (P0.3)
    "git reset --hard",
    "git clean ",
    "git checkout -- ",
    "git push --force",
    # BD destructiva (P0.4)
    "DROP ",
    "TRUNCATE ",
    # "DELETE FROM" se evalúa en la regla específica de BD (con/sin WHERE)
    "ALTER ",
    "migrate reset",
    "db:reset",
    "db:drop",
    # Sistema operativo (P0.5)
    "sudo ",
    "systemctl ",
    "service ",
    "reboot",
    "shutdown",
    "poweroff",
    "mkfs",
    "fdisk",
    "parted",
    # Ejecución peligrosa (P0.8)
    "eval ",
    "| bash",
    "| sh",
    "curl "
]

# Denegar si el comando contiene algún patrón peligroso.
deny contains reason if {
    some pattern in deny_patterns
    command_has_pattern(lower(input.command), lower(pattern))
    reason := sprintf("P0: comando contiene patron prohibido '%s'", [pattern])
}

command_has_pattern(command, pattern) if {
    indexof(command, pattern) != -1
}

# Denegar DELETE/UPDATE sin WHERE en BD (P0.4).
deny contains "P0: DELETE/UPDATE/ALTER sin WHERE en base de datos" if {
    regex.match(`(?i)^(mysql|psql|sqlite3).*\b(delete|update|alter)\b`, input.command)
    not regex.match(`(?i)\bwhere\b`, input.command)
}

# Denegar explícitamente producción (P0.4): si ENV=prod, denegar comandos de BD o deploy.
deny contains "P0: operacion en entorno de produccion" if {
    input.env.ENV == "prod"
    regex.match(`(?i)(drop|truncate|delete|alter|migrate|deploy|apply|destroy)`, input.command)
}

# Denegar lectura/escritura de secretos (P0.6, P0.9).
deny contains "P0: acceso a archivo de secretos o credenciales" if {
    input.action in ["read", "edit"]
    regex.match(`(?i)(\.env|id_rsa|id_ed25519|id_ecdsa|id_dsa|\.pem|\.aws|\.ssh|credentials)`, input.command)
}

# Permitir solo si no hay razones de denegación.
default allow := false

allow if {
    count(deny) == 0
}

# Resultado para consumidores: { "allow": true|false, "deny": [...] }
result := {
    "allow": allow,
    "deny": deny
}
