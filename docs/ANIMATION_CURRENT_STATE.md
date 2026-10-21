# Aren: estado actual del sistema de animaciones

**Fase 1, paso 5: revisión y optimización de locomoción completadas y aprobadas.**
Rama exclusiva: `test/animation-system-v1`. Último commit funcional publicado
al cierre: `651b81a97a0dfe652d3f6af09b38bd2c90e330a9`
(`Cache rig branches for identical Aren pose transforms`). El cierre posterior
es únicamente documental. No integrar en `main` sin autorización expresa.

## Arquitectura y herramientas

Sistema provisional de Godot 4, aislado del juego principal. Conservar las
animaciones, perfiles, rig, binds, materiales e identificadores aprobados.
Leer los `AGENTS.md` aplicables antes de editar; reutilizar los sistemas existentes.

- Modelo: `assets/characters/prototype_3d/composite/model.scn`.
  Rig nativo de 66 huesos: `data/animation/characters/survivor_native.tres`.
  Enlace: `scripts/animation/characters/native_survivor.gd`;
  utilidades compartidas: `scripts/animation/shared/`.
- Variante aprobada: `assets/characters/prototype_3d/generated/aren_run_balanced_v1/`
  (`aren.tscn`, `profile.json`). Herramientas de autoría en `tools/animation/`
  y `scripts/animation/authoring/`; evaluación mediante
  `aren_run_balanced_actor.gd`, `aren_run_balanced_sampler.gd` y
  `aren_transition_actor.gd` de este último directorio.
- En `scripts/animation/terrain/`, `aren_motion_driver.gd` comparte movimiento
  entre visor y escena jugable, reutilizando
  `scripts/prototype_3d/movement_response.gd`; `aren_turn_response.gd` adapta
  los giros. `aren_terrain_test.gd` gestiona física, cámara, entradas y HUD.
- `aren_terrain_actor.gd` resuelve pelvis, contactos e IK de longitudes fijas;
  `terrain_foot_support.gd` valida las suelas; `terrain_cycle_sampler.gd`
  reutiliza muestras; `terrain_test_patch.gd` construye los terrenos;
  `terrain_step.gd` valida escalones de hasta 26 cm. Cápsula de 1,65 m,
  radio de 22 cm y pendiente máxima de 42°.
- Evaluación: movimiento y colisiones → desplazamiento real → fase y pose
  aprobada → referencia corporal y pelvis → IK y suelas. Las correcciones
  parten de la pose fuente, sin acumularse entre fotogramas.

## Animaciones, estados y transiciones

- Reposo, caminata y carrera en `normal`, `cautious` y `tired`
  (normal, cauteloso y cansado), conservando sus diferencias de estilo y ritmo.
- Seis transiciones entre reposo, caminata y carrera, encadenables e
  interrumpibles. Se seleccionan por intención de movimiento; los cambios
  rápidos no dependen de alcanzar una velocidad nominal exacta.
- Aceleración, frenada, locomoción relativa a cámara y fase sincronizada con
  el desplazamiento físico real. El cambio de estado mezcla durante 0,3 s
  conservando la fase.
- Giros ágiles por el arco más corto, con diferencias angulares en [-π, π],
  sin vueltas acumuladas. Límites de 300°/s caminando y 360°/s corriendo,
  ajustados por estado. Los giros moderados conservan movimiento; las
  inversiones coordinan frenada breve, apoyo y recuperación sin pausa impuesta.
- Inclinación proporcional al giro y la velocidad, limitada a 2,5° caminando
  y 4° corriendo, distribuida entre pelvis y columna. Girar solo la cámara
  mantiene el comportamiento aprobado.
- Pies apoyados anclados en mundo; durante la transferencia siguen la dirección
  real, hasta 35° respecto al cuerpo. IK con límites anatómicos, superficies
  transitables y compensación de pelvis, conservando la oscilación natural.

## Escenas y validación

- Jugable provisional: `scenes/prototype_3d/aren_terrain_test.tscn` (**F6**).
  Actor: `scenes/prototype_3d/aren_terrain_actor.tscn`.
  Incluye plano, rampas, baches, escalones de 5–25 cm, camino irregular y bosque.
  WASD mueve; Mayús corre; botón derecho y ratón controlan cámara;
  1/2/3 seleccionan estado; R reinicia; 4/5 llevan a camino/bosque.
  HUD con velocidad, error de apoyo, FPS y coste CPU de evaluación.
- Visor: `scenes/prototype_3d/aren_authoring_review.tscn`, opción
  **Carrera: pies coordinados**; cuatro vistas, comparación antes/después,
  estados, ciclos, transiciones, pausa y velocidad.
- Giros: `scenes/prototype_3d/aren_turn_review.tscn` o botón
  **Paso 3: comparar giros** del visor. Comparación de 45°/90°/135°/180°,
  cambios consecutivos, cámara fija/móvil y suelo irregular.
- Regresiones principales en `tests/`: `aren_locomotion_integration.gd`,
  `aren_turn_response.gd`, `aren_turn_review.gd`, `aren_stair_support.gd`,
  `aren_terrain_sampling.gd`, `aren_branch_cache.gd` y `aren_review_playback.gd`.
  Cubren transiciones e interrupciones, tres estados, cinco terrenos,
  escalones en distintas direcciones, apoyos, giros y equivalencia de poses.
  Ejemplo: `godot --headless --path . --fixed-fps 60 --script tests/aren_locomotion_integration.gd`.

## Correcciones y rendimiento integrados

- Apoyos estables en bordes y escalones, límites articulares y continuidad
  corporal. Las consultas de piel mezclan pesos en espacio del modelo y aplican
  una sola vez la transformación del personaje, manteniendo su coincidencia
  con la malla durante giros y desniveles.
- Consultas de suela con datos compactos precalculados, descarte conservador,
  consultas de planos, cajas e índices de triángulos estáticos; barrido detallado
  cuando la geometría lo requiere. Reutilización de muestras idénticas por
  evaluación, sin cuantizar el tiempo ni reducir la cadencia de contactos.
- `RigBinding` precalcula las ramas del esqueleto y las rotaciones reutilizan
  sus índices, conservando el orden y los resultados de las operaciones.
  Se mantienen animaciones, IK, sondeos necesarios y calidad de apoyos.
- Rendimiento comprobado por el usuario en i5-10400F, RTX 3060 y 16 GB RAM,
  ejecutando con F6 y monitor de 240 Hz: **160–180 FPS en suelo plano y
  140–160 FPS en terreno irregular**. Las mediciones con renderizado por
  software del entorno automatizado no son comparables a esta GPU.
- La escena provisional no aplica el límite de FPS del juego principal.
  F5 ejecuta otra escena; para comparar con ejecución independiente, mantener
  escena y resolución y comprobar V-Sync/límites del editor y del controlador.
  Ejemplo sin límite: `godot --path . --disable-vsync --max-fps 0 scenes/prototype_3d/aren_terrain_test.tscn`.

## Limitaciones pendientes y siguiente objetivo

- Alcance actual: locomoción terrestre sobre colisiones estáticas; plataformas
  móviles y locomoción aérea aún no implementadas en este sistema provisional.
  No existe generación universal de movimientos desde texto.
- Desfase histórico de hashes: `tests/aren_torso_coordination.gd` conserva
  cuatro discrepancias de procedencia de herramientas en los metadatos de
  `aren_walk_torso_v2`; no corresponden a fallos de poses o contactos.
  Conservar los hashes históricos y los clips aprobados; no regenerarlos para
  silenciar esa comprobación. Las demás regresiones del cierre pasan.
- **Siguiente objetivo: Fase 1, paso 6, crear la animación de salto voluntario
  de Aren**, con impulso, ascenso, fase aérea y descenso, reutilizando rig,
  herramientas y visor existentes. Caída, aterrizajes y sus transiciones se
  desarrollarán posteriormente. Presentar primero en el visor y validar en la
  escena jugable tras la aprobación visual; conservar el aislamiento de `main`.
