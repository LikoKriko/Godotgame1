# Sistema de animaciones de Aren: estado actual

**Rama:** `test/animation-system-v1`. **Base anterior de autoría:** `1520151`.
Trabajar en esta rama; no integrar en `main` sin autorización. Rutas relativas
a la raíz del proyecto Godot 4; leer las instrucciones `AGENTS.md` aplicables.

## Arquitectura y archivos principales

Generación parametrizada, perfiles JSON y recursos versionados; muestreo de
ciclos, mezcla de poses y contactos, IK de longitudes fijas y correctivos de
rodilla. Rig nativo de 66 huesos; conservar modelos, binds, materiales y fuentes.

- Modelo: `assets/characters/prototype_3d/composite/model.scn`.
  Rig: `data/animation/characters/survivor_native.tres`.
  Enlace: `scripts/animation/characters/native_survivor.gd`;
  herramientas compartidas: `scripts/animation/shared/`.
- Variante actual: `assets/characters/prototype_3d/generated/aren_run_balanced_v1/aren.tscn`
  y `assets/characters/prototype_3d/generated/aren_run_balanced_v1/profile.json`.
- Evaluación: `scripts/animation/authoring/aren_run_balanced_actor.gd`,
  `scripts/animation/authoring/aren_run_balanced_sampler.gd`;
  tobillos: `scripts/animation/authoring/aren_run_foot.gd` y
  `scripts/animation/authoring/aren_run_left_foot.gd`.
- Transiciones: `scripts/animation/authoring/aren_transition_actor.gd`.
- Generador de la variante: `tools/animation/generate_aren_run_balanced.gd`.
  Generador base: `tools/animation/generate_aren.gd`; solicitudes de vocabulario
  acotado: `scripts/animation/authoring/aren_request.gd`.
- Revisión: `scenes/prototype_3d/aren_authoring_review.tscn`,
  `scripts/animation/authoring/aren_review.gd` y
  `scripts/animation/authoring/aren_review_pose.gd`: cuatro cámaras, una evaluación
  de pose compartida; `actors[0]` mantiene el estado de simulación.

## Disponible y uso

`idle`, `walk`, `run`; estados `normal`, `cautious`, `tired`. Transiciones:
`idle_to_walk`, `idle_to_run`, `walk_to_run`, `run_to_walk`, `walk_to_idle`,
`run_to_idle`, con anticipación, aceleración/frenada y contactos compartidos.
La variante actual aplica a ambos pies los mismos parámetros de recuperación,
con medio ciclo de desfase; hereda zancada, cadencia, velocidad, torso y brazos.
Las versiones anteriores siguen seleccionables sin sobrescribir sus recursos.

Abrir la escena de revisión con **F6**, elegir **Carrera: pies coordinados**,
estado y ciclo/transición. **Ver antes / Ver después** alterna con la variante
del pie derecho; **Encadenadas**, **Reiniciar**, pausa y velocidad permiten revisar
secuencias desde frente, lateral, espalda y tres cuartos.

API del actor: `set_style(estado)`, `reset_motion(gait, fase)`,
`request_transition(nombre)`, `advance_transition(delta)`, `seek_cycle(clip, segundos)`.
El anfitrión aplica `distance_m` como avance sobre +Z; subpasos internos ≤1/120 s.
Regenerar solo en un directorio nuevo, preservando las referencias `source_hashes`:

```sh
godot --headless --path . --script tools/animation/generate_aren_run_balanced.gd -- --output res://assets/characters/prototype_3d/generated/aren_run_balanced_custom
```

## Completado, pendiente y próximo objetivo

Implementados: generación por parámetros/solicitudes acotadas, tres ciclos y
estados, transiciones encadenables/interrumpibles, apoyos en plano y comparación.
La última corrección izquierda se publicó **sin pruebas, importación ni revisión
visual por petición del usuario**: validar ciclo y transiciones antes de aprobarla.
`tests/aren_run_refined.gd` cubre la variante previa; falta ampliar la cobertura
a `aren_run_balanced_v1`. No hay generación universal de movimientos desde texto.

## Prueba jugable de terreno (aislada)

Abrir `scenes/prototype_3d/aren_terrain_test.tscn` y pulsar **F6**. No cambia
la escena principal ni el visor `aren_authoring_review.tscn`.

- WASD: movimiento relativo a cámara; Mayús: carrera; botón derecho y ratón:
  orientar cámara; 1/2/3: normal/cauteloso/cansado; R: volver al inicio.
- Centro: plano, subida de 15°, plataforma y bajada de 15°. Izquierda: baches
  suaves. Derecha: pequeños desniveles de 5 a 25 cm. Geometría básica sin texturas.
- `scenes/prototype_3d/aren_terrain_actor.tscn` hereda la variante coordinada;
  `scripts/animation/terrain/aren_terrain_actor.gd` añade contactos con colisiones,
  sondeos de talón/centro/punta y envolvente de suela nativa, normales, pelvis
  filtrada e IK nativa sin escalado
  de piernas. Anclajes de apoyo en mundo, también al girar; fase y mezcla usan
  el desplazamiento medido después de `move_and_slide`, incluso al bloquearse.
- `aren_terrain_test.gd` reutiliza `movement_response.gd` para aceleración,
  frenada, dirección y reversión; conserva las seis recetas como preparación
  corporal. `terrain_step.gd` permite superar obstáculos de hasta 26 cm,
  comprobando espacio para la cápsula y el techo. Cambiar de estado conserva
  la fase y mezcla las poses locales, conservando longitudes, durante 0,3 s
  antes de resolver los apoyos; la velocidad de destino también se filtra.
  `terrain_foot_support.gd` cachea puntos de la malla skinned en espacio del
  tobillo para comprobar la suela completa, con margen inicial de 6 mm.
  Una rejilla dinámica de 3 mm de puntos skinned comprueba colisiones después
  de IK, una vez por fotograma físico, y permite
  corrección vertical del tobillo (margen de 3 mm) sin mover el anclaje horizontal.
  Los tres estados se precargan al abrir la escena. La orientación usa el límite
  de giro del controlador existente. Clips y perfiles aprobados son de solo lectura.
- La pelvis calcula alcance para apoyos y anticipa el siguiente aterrizaje
  con poses frontales cacheadas; el pie en recuperación elevado no determina
  la altura corporal. El alcance del pie en vuelo se acota con la
  IK existente. La compresión y su recuperación usan un resorte amortiguado
  de frecuencia 18 y límite de 0,75 m/s, con el subpaso físico real. Se filtra
  únicamente la corrección añadida, sin filtrar las curvas de oscilación corporal.
  La mezcla de marchas filtra los impulsos de velocidad de colisión (frecuencia
  24). La fase usa distancia física y zancada efectiva de esa misma mezcla,
  con límite de 3 ciclos/s para arranques de amplitud casi nula. La distancia
  acumulada sigue siendo la recorrida realmente.
  Los apoyos imposibles al girar se liberan hasta el siguiente ciclo; el vuelo
  conserva el desfase de apoyo y lo desvanece con `smooth5`, como en el visor.
- La altura visual sigue la altura real de la cápsula con un resorte de frecuencia
  25; modelo y cámara comparten esa referencia. No se resta la subida solicitada
  por `terrain_step.gd`: el ajuste usa la altura real tras colisiones y floor snap.
  Las mezclas conservan las poses y pies anteriores a IK de terreno, y mantienen
  la compresión y su velocidad entre estados para evitar sumas o reinicios.
- El HUD muestra velocidad medida, error de apoyo, FPS y coste CPU de evaluación.
  Los sondeos usan la capa física 1, excluyen el controlador y aceptan normales
  hasta 42°. Alcance de sondeo: 0,65 m arriba y 0,85 m abajo del tobillo.

Alcance provisional: locomoción terrestre sobre colisiones estáticas. No incorpora
saltos, combate ni seguimiento de plataformas móviles. Revisar también la
naturalidad visual en Godot con F6 antes de integrar en el juego principal.
