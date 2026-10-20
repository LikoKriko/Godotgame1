# Aren: estado actual del sistema de animaciones

**Rama de trabajo:** `test/animation-system-v1`. Sistema provisional aislado del
juego principal; no integrar en `main`. La estabilización de locomoción está
terminada y aprobada. Conservar animaciones, perfiles, rig, binds y materiales
aprobados; aplicar las adaptaciones mediante los sistemas reutilizables existentes.

## Funcionalidades completadas

- Reposo, caminata, carrera y transiciones encadenables e interrumpibles en
  los estados `normal`, `cautious` y `tired`.
- Locomoción relativa a cámara, aceleración, frenada, cambios de dirección y
  sincronización de fase y mezcla con el desplazamiento físico real.
- Adaptación de pelvis y piernas a pendientes, baches y desniveles mediante
  IK de longitudes fijas, anclajes de apoyo en mundo y comprobación de suela.
- Correcciones del temblor y discontinuidades corporales completadas;
  se conserva la oscilación natural de las animaciones.
- Correcciones de apoyos IK cerca de bordes completadas: selección de superficies
  transitables, límites anatómicos y transferencia continua de los pies.
- Optimización de FPS al correr completada, conservando animación e IK:
  cachés por evaluación y consultas de suela con descarte conservador y atajos
  de plano; barrido detallado cuando lo requiere la geometría.
- Escena jugable con plano, rampas, baches, escalones, camino irregular y terreno
  forestal, mediante geometría básica con colisiones, sin texturas ni decoración.
  El visor de comparación se conserva independiente.

## Arquitectura y archivos principales

Rutas relativas al proyecto Godot 4. Leer los `AGENTS.md` aplicables antes de editar.

- Modelo: `assets/characters/prototype_3d/composite/model.scn`.
  Rig nativo de 66 huesos: `data/animation/characters/survivor_native.tres`.
  Enlace: `scripts/animation/characters/native_survivor.gd`;
  utilidades: `scripts/animation/shared/`.
- Variante aprobada: `assets/characters/prototype_3d/generated/aren_run_balanced_v1/`
  (`aren.tscn`, `profile.json`). Evaluación base en
  `scripts/animation/authoring/aren_run_balanced_actor.gd`,
  `aren_run_balanced_sampler.gd` y `aren_transition_actor.gd` del mismo directorio.
- `scripts/animation/terrain/aren_terrain_test.gd`: controlador físico, cámara,
  entradas y HUD; reutiliza `scripts/prototype_3d/movement_response.gd`.
  Cápsula de 1,65 m de altura y 22 cm de radio, pendiente máxima de 42°.
- En `scripts/animation/terrain/`: `terrain_step.gd` valida escalones de hasta
  26 cm; `aren_terrain_actor.gd` resuelve contactos, pelvis e IK;
  `terrain_foot_support.gd` comprueba la suela; `terrain_cycle_sampler.gd`
  reutiliza muestras idénticas; `terrain_test_patch.gd` construye los terrenos.
- Orden de evaluación: movimiento y colisiones → desplazamiento real → fase y
  pose aprobada → referencia visual y pelvis → IK y comprobación de suela.
  Las correcciones se calculan desde la pose fuente, sin acumularse entre
  fotogramas. Los anclajes estables se conservan; se suavizan las transferencias
  y la corrección añadida. Cambiar de estado conserva fase y mezcla durante 0,3 s.

## Escenas de prueba y uso

- **Jugable:** abrir `scenes/prototype_3d/aren_terrain_test.tscn` y pulsar **F6**.
  WASD: movimiento; Mayús: correr; botón derecho y ratón: cámara;
  1/2/3: normal/cauteloso/cansado; R: inicio; 4/5: camino irregular/terreno forestal.
  HUD: velocidad real, error de apoyo, FPS y coste CPU de evaluación.
  Actor reutilizado: `scenes/prototype_3d/aren_terrain_actor.tscn`.
- **Visor:** abrir `scenes/prototype_3d/aren_authoring_review.tscn` con **F6**;
  seleccionar **Carrera: pies coordinados**, estado y ciclo/transición.
  Ofrece cuatro vistas, comparación antes/después, secuencias, pausa y velocidad.

## Limitaciones y siguiente tarea

- Alcance actual: locomoción terrestre sobre colisiones estáticas; sin saltos,
  combate ni seguimiento de plataformas móviles. No hay generación universal
  de movimientos desde texto.
- El entorno de validación usa renderizado por software; sus FPS no representan
  el rendimiento de una GPU física.
- **Siguiente tarea — paso 3: corregir la orientación de los pies y suavizar los
  giros bruscos**, especialmente al cambiar de dirección durante caminata y
  carrera, conservando los apoyos, la estabilidad y las animaciones aprobadas.
