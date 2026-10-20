# Contexto mínimo por tarea

Leer primero el [AGENTS.md raíz](../AGENTS.md) y cualquier AGENTS.md local que
corresponda al archivo editado. Elegir **solo la fila de la tarea** y el apartado
relevante del documento; ampliar la lectura cuando aparezca una dependencia real.
Este índice no obliga a abrir todas sus referencias.

| Tarea | Leer primero | Rutas de entrada | Comprobar según el cambio |
| --- | --- | --- | --- |
| Columna, carrera, pelvis o manos del superviviente | [ANIMATION_SYSTEMS: Personajes](ANIMATION_SYSTEMS.md#personajes) y su apartado de movimiento | `data/animation/characters/survivor_native.tres`, `scripts/animation/characters/native_survivor.gd`, `scripts/animation/characters/gait_parameters.gd` | Pose, transición, apoyos, piel y anclajes; `tests/native_survivor_model.gd` o prueba específica de marcha |
| Adaptar un clip o rig | [ANIMATION_SYSTEMS: Núcleo compartido](ANIMATION_SYSTEMS.md#núcleo-compartido) | `scripts/animation/shared/`, `tools/animation/retarget_clip.gd` | Categoría, ejes, binds, duración y contactos; `tests/reusable_animation_systems.gd` |
| Importar o adaptar criatura | [MESHY_ASSETS](MESHY_ASSETS.md#personajes-y-criaturas) y [enemigo1](YOUNG_3D.md) o [enemigo3](ENEMY3_3D.md) | `data/animation/enemies/`, manifiesto `source.json` de la especie y su controlador | Fuentes, huesos, texturas, estados y guardado; `tests/prototype_3d_creature.gd` o prueba de especie |
| Arma, agarre, estela o armadura | [WEAPON_ANIMATIONS_3D](WEAPON_ANIMATIONS_3D.md#orientación-y-oclusión) y [MESHY_ASSETS: Objetos](MESHY_ASSETS.md#objetos) | `scripts/prototype_3d/held_profiles.gd`, `scripts/prototype_3d/tool_aim.gd`, anclajes del objeto | Alcance, cuatro fases, oclusión y cobertura; `tests/prototype_3d_equipment.gd` o prueba específica |
| Árbol procedural | [TREES_3D](TREES_3D.md), [FIXED_STORY_ZONES: Exclusión](FIXED_STORY_ZONES.md#exclusión-de-la-generación) | `data/world/trees/twisted_oak.json`, `scripts/prototype_3d/tree_model.gd` | Huella completa, IDs, tala y carga; `tests/prototype_3d_trees.gd` |
| Terreno, bioma o población del mundo | [WORLD_AUTHORING](WORLD_AUTHORING.md) y [FIXED_STORY_ZONES](FIXED_STORY_ZONES.md#exclusión-de-la-generación) | `data/world/recipes/`, `data/world/biomes/`, `data/world/terrain/` | Determinismo, reservas y contratos; `tests/reusable_world_systems.gd`, ampliando a streaming si cambia la carga |
| Zonas narrativas | [FIXED_STORY_ZONES](FIXED_STORY_ZONES.md#editar-y-añadir-lugares) | `data/world/story_zones.json`, `scripts/prototype_3d/story_zone_catalog.gd` | Huellas, márgenes, IDs y reconstrucción; `tests/prototype_3d_story_zones.gd` |
| Luz ambiental, cielo o sombras | [PROTOTYPE_3D: Iluminación](PROTOTYPE_3D.md#dirección-de-iluminación-y-ambiente) y solo el perfil afectado | `data/rendering/`, `scripts/rendering/` | Transiciones, coste, estilo y desactivación de pruebas; `tests/prototype_3d_lighting_finish.gd` o `tests/prototype_3d_shadow_trial.gd`; render real si cambia un shader |
| Receta o requisito de mesa | [REUSABLE_SYSTEMS: Fabricación](REUSABLE_SYSTEMS.md#fabricación-y-desbloqueos) | `scripts/workshop.gd`, `scripts/inventory.gd`, `scripts/creation_page.gd` | Mesa, `basic_tool`, desbloqueos y backend; `tests/workbench_station_rules.gd` |
| Material, textura, icono o HUD | [VISUAL_STYLE](VISUAL_STYLE.md) y [MESHY_ASSETS](MESHY_ASSETS.md) si hay modelo | Manifiesto del recurso, `scripts/prototype_3d/hud.gd`, `assets/ui/hud/` | Fuentes, UV, estilo, proporciones y clics; `tests/prototype_3d_meshy_assets.gd` o `tests/prototype_3d_native_ui.gd` según el caso |
| Audio | Apartado de sonido de [PROTOTYPE_3D](PROTOTYPE_3D.md) | `scripts/audio/player_walk.gd`, `assets/audio/characters/` | Inicio/parada, fades y buses; `tests/player_walk_audio.gd` |
| Distancia y simulación de criaturas | [DISTANCE_OPTIMIZATION](DISTANCE_OPTIMIZATION.md), ficha de especie | `scripts/prototype_3d/distance_optimization.gd`, `scripts/prototype_3d/young_enemy.gd`, `scripts/prototype_3d/sprout_enemy.gd` | Distinguir LOD visual de simulación, suspensión y persistencia; `tests/prototype_3d_distance_optimization.gd` |
| Integración o guardado | [PROTOTYPE_3D: Partidas](PROTOTYPE_3D.md#partidas) y documentos de los sistemas modificados | `scripts/prototype_3d/save_game.gd`, `scripts/prototype_3d/world.gd` | Conflictos, IDs y carga; `tests/prototype_3d_saves.gd` solo si hay cambios de persistencia |
| Migración documental | Regla de documentación del AGENTS.md y documento afectado | Índice, enlaces y reglas locales aplicables | Cobertura de reglas, enlaces, rutas y `git diff --check`; Godot si es proporcionado; no ejecutar toda la suite por cambiar texto |

## Flujo de lectura y ejecución acotado

1. Reutilizar la copia de trabajo persistente; inspeccionar `git status --short`
   y diferencias antes de sincronizar. No clonar de nuevo por costumbre; si el
   entorno es efímero, preparar la copia necesaria sin volcar todo el repositorio.
2. Localizar antes de leer: `rg --files scripts/animation data/animation`,
   `rg -n 'símbolo' ruta/del/archivo` y `git diff -- ruta/del/archivo`.
   Leer fragmentos alrededor de coincidencias, no archivos completos por defecto.
3. Reutilizar perfiles estables de IDs, jerarquía, ejes y fuentes en los manifiestos
   y `data/animation/`. Actualizarlos cuando cambie el recurso; no regenerarlos por
   cada ajuste pequeño. Para variaciones, usar los parámetros y herramientas
   existentes (`gait_parameters.gd`, `bake_controls.gd`, perfiles de mundo o render)
   antes de proponer edición masiva o un script nuevo. Crear automatización
   parametrizada adicional solo cuando forme parte del encargo funcional.
4. Escalonar las verificaciones: validación estática específica → prueba del
   subsistema → importación Godot cuando cambien recursos o dependencias →
   integraciones relevantes. Reservar la suite general para cambios transversales
   que la justifiquen; integrar no obliga a repetir pruebas sin cambios nuevos.
5. Limitar la salida de terminal. Guardar logs completos y mediciones solo en
   temporales locales, y mostrar resultado, errores y fragmentos útiles. No volcar
   FBX, escenas, datos binarios ni grandes archivos JSON: resumir metadatos.
6. Mantener una sesión por tarea coherente. Cerrar con rutas, comprobaciones,
   pendientes y último commit. Si el contexto es excesivo, continuar en otra sesión
   con ese resumen y los módulos pertinentes. No atribuir un ahorro concreto de
   tokens a esta estructura sin una medición independiente.

## Comandos de comprobación

Desde la raíz, usar el ejecutable de Godot disponible en el entorno; `godot`
representa aquí Godot 4 compatible con el proyecto:

```sh
git diff --check
godot --headless --path . --script res://tests/reusable_animation_systems.gd
# Solo si procede importar recursos:
godot --headless --editor --path . --import --quit
```

Cambiar la prueba por la de la fila correspondiente. Las pruebas nativas de
interfaz y ALT requieren una pantalla y captura de ratón; no confundir su falta
de soporte en modo headless con un fallo del juego. No cambiar físicas, calidad
ni expectativas de una prueba para forzar un resultado. Informar de comprobaciones
no ejecutadas y límites del entorno. La autorización de publicación sigue siendo
la del AGENTS.md raíz y la solicitud vigente del usuario.

## Plantilla de tarea

> Tarea: [objetivo y resultado observable]. Subsistema: [área]. Consulta solo
> AGENTS.md y el módulo relevante de este índice; amplía ante dependencias reales.
> Reutiliza herramientas y perfiles existentes. Cambia los archivos mínimos;
> prueba [casos]; conserva rigs e IDs. Publica únicamente dentro de las
> autorizaciones actuales. Devuelve un resumen breve y resultado de comprobaciones.
