# Retirada del juego 2D y publicación del 3D en main

17 de octubre de 2026. `main` contiene el juego 3D y arranca desde
`scenes/prototype_3d/day_zero.tscn`. La rama `prototype/third-person-3d` se
sincroniza con esta entrega para que los departamentos partan del mismo código.
Los nombres `prototype_3d` de carpetas y pruebas se conservan para evitar una
renombración masiva de recursos Godot y enlaces entre departamentos.

## Retirado

Se retiran 2674 archivos, aproximadamente 246.6 MiB del árbol
actual. El historial de Git mantiene las versiones previas.

- Escenas `scenes/main.tscn`, `scenes/day_zero.tscn` y `scenes/hut_interior.tscn`.
- Controladores del juego, mundo, enemigos, combate, cursor y sombras 2D.
- Renderizado de terreno 2D y sus shaders.
- Atlas de animación del personaje en `assets/characters/complete/`, atlas del
  enemigo 2D y sus manifiestos, reproductores y exportadores.
- Sprites de edificios, árboles y arbolitos que el 3D ya no carga.
- Guardado, restauración y migraciones del formato exclusivo del juego 2D.
- Pruebas y documentación que solo describían el runtime 2D eliminado.
- Acceso de regreso al juego 2D y compatibilidad con su cursor autoload.

## Conservado porque lo usa el 3D

| Recursos | Motivo |
| --- | --- |
| `assets/items/` | Sprites originales, atlas y recortes necesarios para iconos de objetos; también los iconos 3D ya horneados. |
| `assets/ui/` excepto el cursor antiguo | Menú, HUD, inventario, marcos, botones y tipografía compartidos. |
| `assets/environment/burdock*.png`, `forest_details*` e imágenes de césped/rocas | Texturas, recortes y perfiles de recursos utilizados por los modelos, generador e iconos. |
| Cuatro `terreno_1_*.png`, máscaras `platform_*.png` y `tree_sizes.json` | Texturas de suelo, contornos físicos 3D de plataformas y dimensiones de los árboles del generador. |
| Inventario, progresión, recetas, nutrición, reloj y parry | Reglas del juego compartidas; no constituyen un runtime 2D. |
| Interfaz compartida de inventario y menú | El 3D aporta su retrato, mapa y opciones gráficas; se han eliminado los proveedores exclusivos del 2D. |
| `continuous_body_pose.gd`, generador por semilla y sampler | Matemática de animación, colocación y terreno usada por el 3D; emplear Vector2 para coordenadas del suelo no implica renderizado 2D. |
| `entregables/` | Originales de los departamentos y referencias artísticas; no son el juego 2D ejecutable. |

Todos los FBX, modelos, rigs y texturas originales Meshy del 3D permanecen
intactos. La validación de objetos del guardado 3D se ha trasladado desde el
archivo del guardado 2D sin cambiar sus reglas. El formato y la ruta de las
partidas 3D siguen siendo los mismos. No se borran partidas guardadas del equipo
del usuario. Las versiones 2D anteriores se pueden recuperar desde Git.

## Trabajo de los departamentos

Usar `main` como referencia de integración. Actualizar el checkout antes de
empezar y revisar los cambios remotos antes de subir una entrega. Si un chat
sigue usando `prototype/third-person-3d`, actualizarlo también: esta entrega
publica el mismo contenido en ambas ramas. Evitar recuperar escenas, atlas o
scripts eliminados al integrar ramas antiguas.

Los registros anteriores de `WORK_TIMES.md` y las secciones históricas de
migración pueden mencionar archivos del 2D ya retirados; son historia del
proyecto, no instrucciones para restaurarlos.

## Verificación de la entrega

Importación limpia en Godot 4.7.2. Comprobadas las dependencias de scripts,
escenas, shaders, pruebas y herramientas: ninguna referencia a los archivos
retirados. Los sprites de objetos y los recursos originales 3D se comparan
contra la entrega remota y permanecen sin modificaciones.

Superadas las suites de arranque, inventario/creación, interacciones, recursos,
campamento, mesas de trabajo, configuración de generación, calidad por distancia,
keyframes, guardados, streaming, reglas de fabricación y caché de iconos.
También pasan las 487975 comprobaciones del nuevo modelo/rig/caminata de
enemigo3 y las 17 de arrastre y clics del inventario con ratón nativo.

La prueba de menú y guardado nativos usa ahora el selector gráfico real para
elegir 100 m antes de generar el mundo: acota el trabajo del renderizador por
software y comprueba ese control. El valor predeterminado del juego continúa
en 200 m; la suite de streaming valida los distintos radios por separado.

La prueba nativa de menú, configuración y guardado/carga completa sus
12 comprobaciones sin errores con ese radio de 100 m.

Se incorpora la entrega posterior de enemigo3 desde K, tamaño 0,9 m y
patrulla de diez metros: 15101 comprobaciones de patrulla/menú/física y
47 del guardado actualizado superadas tras integrarla.
