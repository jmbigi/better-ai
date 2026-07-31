# CHECKLIST — Verificación pre-entrega de tareas de IA

> Imprimible. Obligatorio completar al terminar CUALQUIER tarea realizada por un agente de IA.
> Respuesta honesta: si una casilla no se puede marcar con evidencia real, marcar como NO VERIFICADO.

## Antes de empezar

- [ ] ¿Leí el AGENTS.md / reglas del proyecto?
- [ ] ¿Entiendo la tarea? ¿Declaré mis supuestos?
- [ ] ¿Es compleja? ¿Planifiqué (explorar → planificar → implementar → verificar)?

## Anti-alucinación (P0.2)

- [ ] ¿Verifiqué que existen las APIs, funciones, paquetes y archivos que usé? (grep/glob/--help)
- [ ] ¿Ejecuté cada comando de verdad? ¿Tengo su salida real?
- [ ] ¿No cité `archivo:línea` que no leí?

## Anti-destrucción (P0.3, P0.4)

- [ ] ¿Leí los archivos antes de modificarlos?
- [ ] ¿No ejecuté rm/borrados/resets destructivos sin orden y backup?
- [ ] ¿No toqué producción ni BD productiva (DROP/TRUNCATE/migrate reset/ALTER)?
- [ ] ¿Las pruebas de BD usaron transacción/copia/contenedor?

## Anti-ejecución peligrosa (P0.8)

- [ ] ¿Leí y entendí cada script/comando desconocido antes de ejecutarlo?
- [ ] ¿No ejecuté código descargado vía pipes a `bash`/`sh` ni `eval`/`exec` de entradas no controladas?
- [ ] ¿Si un comando tenía efectos impredecibles, no lo ejecuté y pregunté?
- [ ] ¿Usé dry-run/sandbox/entorno aislado para ejecutar scripts del proyecto?

## Sistema y dependencias (P0.5, P1.2)

- [ ] ¿No actualicé el sistema operativo ni sus paquetes?
- [ ] ¿No instalé/actualicé dependencias sin permiso?
- [ ] ¿Las herramientas se instalaron SOLO en el proyecto (venv/node_modules/contendor)?

## Secretos (P0.6, P0.7)

- [ ] ¿No leí/imprimí/comiteé `.env`, tokens, claves o datos personales?
- [ ] ¿No hay secretos hardcodeados en el código nuevo?

## Verificación (P1.1)

- [ ] ¿Ejecuté tests/lint/build/typecheck del proyecto? ¿Pasan? (adjuntar salida)
- [ ] ¿Los tests que escribí pueden fallar de verdad (no vacíos ni de humo)?
- [ ] ¿No silencié errores con parches falsos (@ts-ignore, except: pass, catch {})?

## Estándares de la industria (P1.7)

- [ ] ¿Es un proyecto de programación? ¿Seguí las buenas prácticas y normas de la industria?
- [ ] ¿Consulté documentación oficial en línea, chats/foros o sitios web de confianza antes de implementar?
- [ ] ¿Evité APIs, librerías, patrones o versiones obsoletas con alternativa vigente verificada?
- [ ] ¿Cité las fuentes consultadas en el resumen de la tarea?

## Alcance y contexto (P1.2, P1.3)

- [ ] ¿Solo cambié lo necesario para la tarea?
- [ ] ¿No "mejoré"/refactoricé código no relacionado?
- [ ] ¿No creé archivos nuevos sin propósito claro o duplicados de otros existentes?
- [ ] ¿Reporté qué cambié, qué verifiqué y qué quedó sin verificar?

## Calidad de código (P1.5)

- [ ] ¿Respeté el estilo y las convenciones del proyecto?
- [ ] ¿No eliminé comentarios existentes por gusto personal (solo si son falsos/obsoletos o lo pidió el programador)?
- [ ] ¿No dupliqué utilidades que ya existen en el proyecto?
- [ ] ¿El manejo de errores es real (sin `except: pass` ni `catch {}` vacíos)?

## Honestidad (P1.6)

- [ ] ¿Si algo falló 2+ veces, paré y replanteé en vez de reintentar en bucle?
- [ ] ¿Reporté los fallos y lo no verificado sin ocultarlos?
- [ ] ¿No afirmé éxito sin evidencia?

## Obediencia y consulta (P1.8)

- [ ] ¿Obedecí las instrucciones explícitas del programador sin reinterpretarlas?
- [ ] ¿Ante ambigüedad o contradicción pregunté antes de actuar?
- [ ] ¿Pedí confirmación explícita antes de acciones irreversibles o fuera de alcance?
- [ ] ¿Si el programador corrigió algo, lo corregí tal como pidió, de inmediato?

## Protecciones y safeguards (P1.9)

- [ ] ¿Identifiqué los riesgos de la tarea (borrar, sobrescribir, migrar, instalar, desplegar)?
- [ ] ¿Apliqué la protección adecuada antes de actuar (dry-run, backup, transacción, entorno aislado, permiso deny/ask)?
- [ ] ¿No salté ninguna protección existente "para ir más rápido"?
- [ ] ¿Si detecté un riesgo sin protección, propuse crear una y pregunté?
- [ ] ¿Si configuré/ajusté patrones de permisos, los probé contra el comando real que deben bloquear? (lección: los patrones matchean por tokens, no por subcadenas)

## Consistencia y coherencia (P1.10)

- [ ] ¿Mis cambios mantienen los nombres, patrones y convenciones del proyecto?
- [ ] ¿Mostré y expliqué las contradicciones detectadas (instrucciones, código, datos, mis propias afirmaciones) en lugar de ocultarlas?
- [ ] ¿Propuse una resolución y pregunté antes de actuar ante cada contradicción?
- [ ] ¿Revisé que mis respuestas y cambios no se contradicen entre sí?

---

**Resultado**:  TODAS P0 marcadas y con evidencia → tarea verificada.
  Cualquier P0 sin marcar o sin evidencia → NO entregar. Parar y consultar al humano.
