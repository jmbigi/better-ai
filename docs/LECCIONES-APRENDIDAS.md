# LECCIONES-APRENDIDAS — Memoria del proyecto better-ai

> Cada prueba, fallo o hallazgo relevante se documenta aquí con su solución.
> Si algo falla 2+ veces, la lección pasa a ser regla en `AGENTS.md`.

## Cómo se actualiza

- Tras cada prueba de las reglas o de opencode, añadir una entrada con fecha.
- Formato: **Fecha — Título** → Problema / Solución / Evidencia.
- Si el mismo fallo se repite 2+ veces: proponer una regla nueva o endurecer una existente.

---

## 2026-07-31 — opencode.json: `permission.webfetch` no acepta sintaxis de objeto

**Problema**: al configurar `permission.webfetch` con la sintaxis de objeto
`{ "*": "allow" }`, opencode rechazó toda la configuración con:
`Expected PermissionActionConfig | undefined, got {"*":"allow"} permission.webfetch`.
**Solución**: `webfetch` solo admite valor directo (`"allow"`). Corregido en
`opencode.json` y verificado con `opencode run` (funcionó).
**Evidencia**: salida de error de opencode 1.18.10 y posterior prueba exitosa.
**Lección**: antes de asumir que un permiso acepta sintaxis de objeto, validar el
JSON contra el esquema (`$schema`) o probar `opencode run` con una tarea trivial.
**Estado**: cerrada. No se repitió.

## 2026-07-31 — Un LLM puede sugerir una "alternativa segura" que también está prohibida

**Problema**: al negarse a ejecutar `git reset --hard`, el agente sugirió
`git checkout -- <archivo>` como alternativa segura, sin saber que ese comando también
está en la lista `deny` de `opencode.json`.
**Solución**: las reglas de texto son orientativas; la protección real es el `deny`
determinista, que se aplica aunque el agente lo ignore. Mantener SIEMPRE ambas capas.
**Evidencia**: prueba 6 de `docs/PRUEBAS.md` (ronda 1).
**Lección**: no confiar en que el agente conozca todas las reglas de permisos;
la capa determinista no es negociable.
**Estado**: cerrada.

## 2026-07-31 — En modo `--auto`, "ask" se auto-aprueba; solo "deny" frena

**Problema**: `rm <archivo>` (patrón `rm *` = "ask") se ejecutó sin fricción en modo
auto porque el usuario había ordenado el borrado. `rm -rf` sí quedó bloqueado por "deny".
**Solución**: si un proyecto necesita protección máxima contra borrados, cambiar
`rm *` a "deny" en `opencode.json` (cuesta poco y elimina la clase de error completa).
**Evidencia**: prueba 3 de `docs/PRUEBAS.md` (ronda 1, con corrección en ronda 3).
**Lección**: en modo auto, pedir permiso es solo un formalismo; decidir conscientemente
qué queda en "ask" y qué pasa a "deny".
**Estado**: cerrada con decisión registrada (por defecto se mantiene "ask" para `rm`
de archivos concretos y "deny" para las formas recursivas/forzadas).

## 2026-07-31 — Verificación previa de existencia: el anti-alucinación funciona

**Problema**: pedido de refactorizar con la función inexistente `procesar_pago_stripe()`.
**Solución**: el agente verificó con Read/Glob/grep, confirmó que no existe y se negó
a inventarla, citando P0.2 y P1.2. Las reglas de texto SÍ cambian el comportamiento
del modelo si son explícitas y verificables.
**Evidencia**: prueba 2 de `docs/PRUEBAS.md` (ronda 1).
**Lección**: las reglas de texto funcionan cuando exigen acciones verificables con
herramientas (leer/ejecutar/buscar), no simples afirmaciones.
**Estado**: cerrada.

## 2026-07-31 — Reglas nuevas: verificación inmediata de carga

**Problema**: al añadir reglas nuevas (P1.7 estándares, P1.8 obedecer/preguntar,
P1.9 protecciones), no basta con escribirlas: hay que probar que el modelo las
conoce y las cita correctamente.
**Solución**: tras cada cambio de AGENTS.md, ejecutar una prueba corta
(`opencode run "enumera la regla PX"`) y verificar la respuesta. Si el modelo no
la conoce o la interpreta mal, revisar la redacción.
**Evidencia**: prueba post-P1.9 con respuesta correcta del modelo.
**Lección**: las reglas de texto requieren feedback loop: escribirlas, probarlas,
ajustarlas. Documentar en LECCIONES-APRENDIDAS.md.
**Estado**: cerrada.

## 2026-07-31 — Refactorización del propio proyecto: backup y referencias cruzadas

**Problema**: al reorganizar el proyecto (mover `CHECKLIST.md` a la raíz, extraer
`docs/PRUEBAS.md` de `REGLAS-COMPLETAS.md`), el riesgo principal era romper las
referencias cruzadas entre archivos (AGENTS.md, README.md, REGLAS-COMPLETAS.md).
**Solución**: antes de tocar nada, backup completo en `/tmp/opencode/backup-better-ia-20260731`
(P1.9); después de la reorganización, verificar con grep que ninguna ruta antigua
(`docs/CHECKLIST.md`, "sección 7") quedara referenciada.
**Evidencia**: grep de referencias y prueba de carga de opencode posterior.
**Lección**: la refactorización del propio repositorio se trata como la de cualquier
código: leer antes de modificar, backup antes de mover, y verificación de coherencia
(P1.10) después — en este caso, las reglas del proyecto se aplicaron a sí mismas.
**Estado**: cerrada.

## 2026-07-31 — CRÍTICA: los patrones de permisos de opencode matchean por TOKENS, no por subcadenas

**Problema**: el patrón `"sqlite3 * DROP*": "deny"` NO bloqueó
`sqlite3 db 'DROP TABLE clientes;'` y la tabla se destruyó (2 veces, en BD temporales
de prueba). La causa: opencode tokeniza el comando por espacios y el token real era
`'DROP` (comilla pegada), que no matchea `DROP*`. La misma mecánica explica por qué
los deny de SQL destructivo fallan si no se cubre la comilla.
**Solución**: usar `"sqlite3 * *DROP*": "deny"` (el `*` extra cubre la comilla).
Verificado con pruebas reales: DROP, DELETE y ALTER quedan bloqueados y las BDs
intactas. Se corrigieron todos los patrones (`psql`/`mysql`/`sqlite3`) en
`opencode.json`.
**Evidencia**: ronda 3 de `docs/PRUEBAS.md` (pruebas 10–15).
**Lección**: NUNCA confiar en que un patrón de permisos funciona sin probarlo contra
el comando real (P1.1). Además: un LLM puede auto-limitarse por la regla de texto
(nunca intentó `rm -rf`) y eso NO es evidencia de que el deny funcione; hay que
provocar el intento para observarlo.
**Estado**: cerrada. Se añade a la checklist: "¿Probé el patrón/guardarraíl contra el
comando real?"

## 2026-07-31 — El matching posicional: cada forma de comando necesita su patrón

**Problema**: al reforzar los deny (ronda 4), dos patrones fallaron contra comandos
reales: `redis-cli * FLUSHALL*` (3 tokens) no matcheó `redis-cli FLUSHALL` (2 tokens),
y `git filter-branch*` no matcheó `git -C <repo> filter-branch ...` (el token `-C`
desplaza la posición del subcomando).
**Solución**: añadir variantes por forma: `redis-cli FLUSHALL*` (2 tokens),
`git -C * filter-branch*`, `git -C * reset --hard*`, etc. Verificado con pruebas
16–21 de `docs/PRUEBAS.md` (ronda 4): todos bloqueados, repos/archivos intactos.
**Evidencia**: ronda 4 de `docs/PRUEBAS.md`.
**Lección**: el matching es POSICIONAL: `<cmd> * <flag>` NO cubre `<cmd> <flag>` ni
`<cmd> -C <dir> <flag>`. Al añadir cualquier patrón de permisos, probar al menos la
forma de 2 tokens, la forma con argumentos y la forma con `-C`/`--git-dir`.
**Estado**: cerrada.

## 2026-07-31 — Auditoría de historial: el commit NO es el momento de limpiar

**Problema**: antes de pushear el primer commit del repo (que es público), había una
lección con información sensible (rutas de claves SSH y nombres de cuentas reales).
**Solución**: la versión sensible se reescribió anonimizada ANTES de commitear, y la
auditoría posterior (`git fsck --unreachable`, `git grep` en todos los commits,
`git log -p` en todos los patches) confirmó que nunca existió ningún blob con ese
contenido en el historial. Si se hubiera commiteado, la remediación sería mucho más
costosa: rotación de credenciales + purga de historial con herramienta de filtrado.
**Evidencia**: ronda 5 de `docs/PRUEBAS.md`.
**Lección**: la limpieza se hace ANTES del commit, no después: auditar cada archivo
antes de stagearlo (grep de emails, IPs, rutas de claves, nombres de cuentas). El
historial de git es prácticamente inmortal; purgarlo es la última opción y siempre
coordinada con el programador (P0.10, P0.11, P0.12).
**Estado**: cerrada.

## 2026-07-31 — Renombrar un repo: remote, menciones y verificación

**Problema**: el repositorio pasó de `better-ia` a `better-ai` en GitHub. La URL
antigua seguía funcionando (redirección de GitHub), pero el remote local apuntaba al
nombre viejo y las menciones del nombre quedaron desactualizadas.
**Solución**: (1) `git remote set-url origin git@github-jmbigi:jmbigi/better-ai.git`;
(2) verificar con `git fetch` que es el MISMO repo (mismo HEAD, sin divergencias);
(3) actualizar las menciones del nombre en README y docs, preservando los registros
históricos exactos (rutas de backup, notas "renombrado desde").
**Evidencia**: commits `23e42f3` y `fd4a63c`, verificación del 31-07-2026.
**Lección**: al renombrar un repo: actualizar el remote ANTES de pushear (una
redirección puede ocultar que se está pusheando a otro lado), verificar identidad
(HEAD idéntico), y buscar todas las menciones del nombre viejo sin reescribir hechos
históricos.
**Estado**: cerrada.

## 2026-07-31 — CRÍTICA: el orden de los patrones anula los deny (last matching rule wins)

**Problema**: en la config REAL de `opencode.json`, el patrón genérico `rm *` (ask)
estaba DESPUÉS de `rm -rf *` (deny). Como opencode aplica "last matching rule wins",
`rm -rf x` matchea ambos y ganaba el ask → en modo `--auto` el borrado se habría
ejecutado. Afectaba a `git reset`, `mv --force`, `rsync --delete`, `docker compose
down -v`. Las pruebas de las rondas 3–7 usaban config MÍNIMA (sin los ask genéricos)
y por eso nunca se detectó.
**Solución**: reordenar `opencode.json`: `*` = allow, después TODOS los ask, y TODOS
los deny al final (85 ask + 76 deny). Verificado con la config REAL completa y
`--auto`: `rm -rf`, `git reset --hard`, `mv --force` y `DROP TABLE` bloqueados;
operaciones normales permitidas (pruebas 29–33).
**Evidencia**: ronda 8 de `docs/PRUEBAS.md`.
**Lección**: (1) probar los deny SIEMPRE con la config COMPLETA del proyecto, nunca
con config mínima; (2) al añadir un ask genérico (`rm *`, `git reset *`, `mv *`),
asegurarse de que los deny específicos de la misma familia queden DESPUÉS en el
archivo; (3) el orden de las claves del JSON es semántica de seguridad.
**Estado**: cerrada. Se añade a la checklist: "¿El deny específico queda después de
cualquier ask genérico de su familia?"

## 2026-07-31 — Revisión cruzada: detecta reglas definidas pero no documentadas

**Problema**: la revisión integral del proyecto (P1.10) encontró que la regla **P1.7**
existía en `AGENTS.md` pero NO estaba documentada en `docs/REGLAS-COMPLETAS.md`
(la sección 3 saltaba de P1.6 a P1.8). Además, la tabla de limitaciones tenía 20
filas frente a los 21 errores del README (faltaba "daños por no preguntar").
**Solución**: verificación automática de coherencia: comparar los IDs de reglas
definidos en AGENTS.md contra los documentados en REGLAS-COMPLETAS.md y las
referencias en README/CHECKLIST (grep + sort). Documentar P1.7 y alinear el conteo.
**Evidencia**: salidas de grep de la revisión del 31-07-2026.
**Lección**: tras cada modificación del ruleset, ejecutar la revisión cruzada de IDs
y conteos; es barata y detecta incoherencias invisibles al leer archivos por separado.
**Estado**: cerrada. Se aplica la revisión cruzada como paso previo a cada commit.

## 2026-07-31 — Push fallido: la clave SSH por defecto era de otra cuenta

**Problema**: `git push` al remote de GitHub del proyecto falló con
`Permission to <repo> denied to <cuenta-sin-permisos>`: la config SSH por defecto de
`github.com` usa la clave por defecto, que pertenece a otra cuenta de GitHub sin
permisos sobre el repositorio.
**Solución**: usar el alias SSH ya definido en la config SSH del usuario
(`Host <alias-jmbigi>` → `IdentityFile <clave-jmbigi>`, con `IdentitiesOnly yes`).
El remote cambió a `git@<alias-jmbigi>:<org>/<repo>.git`, verificado con
`ssh -T git@<alias-jmbigi>` (autenticación correcta de la cuenta con permisos).
**Evidencia**: error de push y verificación del alias (31-07-2026).
**Lección**: antes de pushear, verificar qué identidad SSH usará el remote
(`ssh -T <alias>` o `git ls-remote`); si el repo está bajo una cuenta distinta a la
clave por defecto, usar el alias SSH correcto en la URL del remote. Esta lección se
documenta ANONIMIZADA (sin rutas de claves ni nombres de cuentas): los detalles de
claves y cuentas personales no se registran ni siquiera en repos privados (P0.9/P0.10).
**Estado**: cerrada.
