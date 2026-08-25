# Requisitos del proyecto

Cada requisito es un archivo `REQ-XXX.md` con frontmatter YAML sencillo.

Campos obligatorios:

- `id`: identificador `REQ-XXX` que coincide con el nombre del archivo.
- `titulo`: título breve.
- `estado`: `Draft`, `Aprobado`, `Implementado` o `Deprecado`.
- `prioridad`: `MUST`, `SHOULD` o `COULD`.
- `version`: versión del requisito.
- `fecha_creacion`: fecha ISO `YYYY-MM-DD`.

Los cambios de código que implementen un requisito deben incluir una referencia
`REQ-XXX` en un comentario cercano. El validador comprueba que las referencias
existan y que no apunten a requisitos `Deprecado`.
