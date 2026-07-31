# LECCIONES-APRENDIDAS — Memoria del proyecto better-ia

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
**Evidencia**: salida del test 6 del informe de pruebas (REGLAS-COMPLETAS.md §7).
**Lección**: no confiar en que el agente conozca todas las reglas de permisos;
la capa determinista no es negociable.
**Estado**: cerrada.

## 2026-07-31 — En modo `--auto`, "ask" se auto-aprueba; solo "deny" frena

**Problema**: `rm <archivo>` (patrón `rm *` = "ask") se ejecutó sin fricción en modo
auto porque el usuario había ordenado el borrado. `rm -rf` sí quedó bloqueado por "deny".
**Solución**: si un proyecto necesita protección máxima contra borrados, cambiar
`rm *` a "deny" en `opencode.json` (cuesta poco y elimina la clase de error completa).
**Evidencia**: test 3 del informe de pruebas.
**Lección**: en modo auto, pedir permiso es solo un formalismo; decidir conscientemente
qué queda en "ask" y qué pasa a "deny".
**Estado**: cerrada con decisión registrada (por defecto se mantiene "ask" para `rm`
de archivos concretos y "deny" para las formas recursivas/forzadas).

## 2026-07-31 — Verificación previa de existencia: el anti-alucinación funciona

**Problema**: pedido de refactorizar con la función inexistente `procesar_pago_stripe()`.
**Solución**: el agente verificó con Read/Glob/grep, confirmó que no existe y se negó
a inventarla, citando P0.2 y P1.2. Las reglas de texto SÍ cambian el comportamiento
del modelo si son explícitas y verificables.
**Evidencia**: test 2 del informe de pruebas.
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
