# DAY ZERO — Instrucciones globales para agentes

## Proyecto vigente

Day Zero es un juego 3D de supervivencia y exploración en Godot 4.
La rama de integración es `main`. El runtime 2D se ha retirado.
No restaurar código 2D obsoleto; conservar los recursos compartidos
vigentes según `docs/SHARED_RESOURCES.md`.

## Preparación y seguridad

Antes de editar, inspeccionar Git y sincronizar la rama correspondiente.
Conservar trabajo de otros departamentos, fuentes originales, IDs
persistentes, escenas, rigs, binds y compatibilidad de guardado.
Preferir cambios acotados y reversibles. No reemplazar sistemas
funcionales cuando una solución reutilizable ya exista.
Si falta definir un criterio artístico o de comportamiento, proponer
opciones al usuario; resolver autónomamente detalles técnicos definidos.

## Lectura selectiva de documentación

Leer las instrucciones aplicables y documentación del subsistema
implicado, NO todos los documentos por defecto. Empezar por rutas,
símbolos y funciones relevantes; ampliar contexto ante dependencias
reales o riesgos de integración.
Usar `docs/TASK_ROUTING.md` como mapa de contexto mínimo, no como lista de lectura.
Referencias: `docs/REUSABLE_SYSTEMS.md`, `docs/PROTOTYPE_3D.md`,
`docs/SHARED_RESOURCES.md`, `docs/MESHY_ASSETS.md`,
`docs/ANIMATION_SYSTEMS.md`, `docs/FIXED_STORY_ZONES.md`.
Consultar documentos visuales, de criaturas y render solo si aplican.
Las reglas especializadas vinculadas son obligatorias dentro de su ámbito;
las instrucciones locales complementan estas reglas, sin contradecirlas.
Ante discrepancias documentales, conservar ambas referencias temporalmente,
señalar el conflicto y aplicar la opción más segura hasta resolverlo.

## Dirección visual global

Estilo 3D de fantasía estilizada con acabado pintado. Sunny Sprout
(`assets/enemies/third/sprout/`) es referencia de tratamiento.
Preservar anatomía, identidad y siluetas aprobadas. No imponer pixel
art del runtime retirado. Reglas detalladas de materiales, contornos
y excepciones de interfaz: `docs/VISUAL_STYLE.md`.

## Animaciones y modelos

Reutilizar rigs y perfiles nativos existentes, más herramientas
compartidas de `scripts/animation/shared/` y el sistema documentado
en `docs/ANIMATION_SYSTEMS.md`. Respetar binds, longitudes,
anclajes, contactos, IK, continuidad y anatomía completa.
No sobrescribir fuentes ni clips existentes sin autorización.

## Mundo, contenido y mecánicas

Los generadores deben respetar zonas reservadas completas usando
`story_zone_catalog.gd` y `data/world/story_zones.json`, sin alterar
IDs persistentes. Para iluminación consultar `data/rendering/` y
los apartados de iluminación de `docs/PROTOTYPE_3D.md`.
Las herramientas no básicas requieren mesa de fabricación y
validación real de desbloqueos, además de su presentación en UI.
Consultar perfiles y documentación específica antes de actuar.

## Git, autorización y publicación

El departamento de animación está autorizado a hacer commit y push
al `main` para entregas de animación solicitadas dentro de su alcance,
tras actualizar remoto, resolver conflictos sin perder trabajo ajeno
y ejecutar las comprobaciones pertinentes. Este permiso no se
extiende por defecto a otros departamentos ni a cambios de alcance
diferente. Respetar credenciales, protecciones y permisos técnicos.
Actualizar también los parámetros documentados cuando corresponda.
Si Git falla al conectar con el proxy desde la ejecución aislada,
reintentar con ejecución autorizada (`sandbox_permissions: "require_escalated"`)
solo cuando esté disponible y permitido. Mantener el proxy configurado y TLS
verificado; ese error de conectividad no implica falta de autorización de GitHub.

## Documentación y validación

Actualizar documentación técnica únicamente cuando cambien valores
o comportamientos. No añadir registros de cambios de departamentos,
informes de tareas o pruebas, métricas comparativas, tiempos de trabajo,
capturas temporales ni galerías a Git; no recrear `WORK_TIMES.md`.
Las verificaciones y temporales quedan locales; las imágenes generadas de
`docs/previews` están excluidas de Git.
Validar primero el componente modificado y después sus integraciones
relevantes. Informar de pruebas no ejecutadas sin inventar resultados.
Evitar imprimir archivos completos, logs enormes o reanalizar sin
motivo configuraciones ya conocidas.
