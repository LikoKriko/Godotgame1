# Sistema de animaciones de Aren: estado actual

**Rama:** `test/animation-system-v1`. **Último commit funcional:** `1520151`.
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

**Próximo objetivo:** integrar las animaciones aprobadas en un entorno jugable
provisional, sin texturas, con pendientes, baches y apoyos dinámicos mediante IK.
La integración del controlador y la adaptación de pies/pelvis a colisiones,
normales del terreno y soportes móviles están pendientes; el evaluador actual
es de avance recto sobre plano. Consultar solo las secciones necesarias de
`docs/ANIMATION_SYSTEMS.md` al ampliar el sistema.
