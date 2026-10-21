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
  Los parches conservan un índice de sus triángulos de colisión para consultar
  la suela sin lanzar un rayo por vértice. Se comprueba primero el volumen del
  pie contra la física: esta vía solo se usa sobre un único parche estático,
  sin rotación, que cubra el pie completo. Examina todos los vértices de piel
  articulados mediante datos compactos precalculados. Mezcla los pesos de piel
  en espacio del modelo y aplica después la transformación del personaje una
  sola vez, conservando la coincidencia con la malla incluso en bordes de escalón;
  mantiene normales, margen de suela y validación de superficies transitables.
  Si coinciden cajas, consulta
  sus volúmenes y transformaciones completos, eligiendo la primera superficie
  de cada rayo antes de validar el apoyo. La anticipación de bordes reutiliza
  los vértices compactos sin reconstruir una rejilla de piel. Huecos, mezclas
  de geometrías y consultas truncadas conservan el barrido detallado existente.
- `aren_motion_driver.gd` comparte el movimiento entre el visor de giros y la
  escena provisional. `aren_turn_response.gd` adapta `movement_response.gd`
  sin cambiar el controlador global. Conserva sus envolventes de arranque,
  frenada al soltar y peso de carrera; los cambios de dirección no activan
  `reverse_brake` ni `reverse_hold`, ni reinician el arranque desde reposo.
  El rumbo y cada diferencia angular se normalizan a [-π, π]; cada muestra
  avanza por el arco más corto, sin sobrepasar el objetivo ni acumular vueltas.
  Solo un 180° exacto conserva el sentido del último giro como desempate.
  La velocidad angular máxima es 300°/s en marcha y 360°/s en carrera, dividida
  por el factor temporal del estado, con aceleración de 3600°/s² y respuesta
  de 24/s. El factor de apoyo queda entre 0,8 y 1, evitando esperas prolongadas.
  Hasta 45° conserva la velocidad; entre 45° y 180° reduce progresivamente
  hasta un objetivo mínimo del 30 % en marcha o 20 % en carrera. La reducción
  tarda como máximo 0,10 s y la recuperación 0,18 s, multiplicadas por el factor
  temporal del estado; nunca impone una parada ni una pausa de giro.
  La inclinación acompaña velocidad y velocidad angular con resorte continuo,
  limitada a 2,5° en marcha y 4° en carrera, atenuada por el estado y el ángulo
  pendiente del giro. La pelvis recibe el 25 %; la columna añade 25/30/20 %
  y los hombros acompañan su orientación acumulada. Se aplica antes de resolver
  contactos, conservando los anclajes y las longitudes de IK, sin cambiar el
  control de giro ni el movimiento relativo a cámara.
  Los pies en transferencia se orientan al desplazamiento real, con un máximo
  de 35° respecto al cuerpo. Los clips, rig y solver permanecen intactos.
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
- **Paso 3, comparación de giros:** botón **Paso 3: comparar giros** en ese
  visor o F6 en `scenes/prototype_3d/aren_turn_review.tscn`. Izquierda: respuesta
  anterior; derecha: corrección. Vistas tres cuartos y superior sincronizadas;
  controles de estado, caminata/carrera, 45°/90°/135°/180°, giros consecutivos,
  giro suave, cámara móvil,
  suelo irregular, pausa, reinicio y velocidad. Reutiliza el escenario del visor,
  los contactos y el terreno existentes; no ejecuta la escena jugable.

## Limitaciones y siguiente tarea

- Alcance actual: locomoción terrestre sobre colisiones estáticas; sin saltos,
  combate ni seguimiento de plataformas móviles. No hay generación universal
  de movimientos desde texto.
- El entorno de validación usa renderizado por software; sus FPS no representan
  el rendimiento de una GPU física.
- **Paso 3 en revisión visual:** corrección de giros y orientación de los pies
  preparada en el visor, con respuesta ágil y conservación de velocidad en giros.
  Las correcciones de rendimiento sobre terreno irregular e inclinación lateral
  se aplican también a la escena jugable provisional. Sin aprobación final de
  integración; conservar el aislamiento respecto a `main`.
