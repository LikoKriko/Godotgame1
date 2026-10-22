# Aren: contexto vigente de animaciones

Rama exclusiva: **`test/animation-system-v1`**. No modificar `main`.
Base de esta iteración: **`a2b9751`**, sobre la limpieza del visor `5e93839`
y el piloto `60a4056`. Obtener el último commit con `git log -1 --oneline`. Leer los `AGENTS.md` aplicables antes de editar.

## Metodología aprobada y arquitectura

**Blender es la herramienta principal aprobada para crear y corregir
animaciones mediante poses completas coordinadas.** Godot conserva física,
transiciones, sincronización y contactos/IK. No seguir construyendo movimientos
nuevos como curvas independientes de articulaciones. Las animaciones antiguas
podrán exportarse y hornearse para corregirlas en Blender cuando sea viable;
no rehacer automáticamente las versiones que funcionan bien ni sustituir clips
aprobados sin revisión.

- Herramientas verificadas en esta iteración: Blender 4.3.2 y Godot 4.7.2.
  La imagen también conserva Godot 4.6.3; usar el ejecutable 4.7.2 para repetir
  estas comprobaciones.
- Fuente original: `entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx`.
  Modelo Godot: `assets/characters/prototype_3d/composite/model.scn`.
  Rig nativo de **66 huesos**, perfil `data/animation/characters/survivor_native.tres`,
  enlace `scripts/animation/characters/native_survivor.gd`. Conservar jerarquía,
  binds, longitudes, materiales y proporciones aprobadas.
- Locomoción aprobada: `assets/characters/prototype_3d/generated/aren_run_balanced_v1/`;
  actores y muestreadores en `scripts/animation/authoring/`, utilidades de rig
  en `scripts/animation/shared/`. Los sistemas procedurales siguen funcionando.
- `scripts/animation/terrain/`: `aren_motion_driver.gd` comparte locomoción;
  `aren_air_motion.gd` controla salto/caída; `aren_fall_response.gd` clasifica
  pérdida de apoyo físico; `aren_terrain_actor.gd` resuelve pelvis y pies.
  `terrain_foot_support.gd` valida suelas; `terrain_step.gd` conserva escalones
  de hasta 26 cm. Flujo: física/contacto real → fase/pose → contactos e IK.
- Detalles del sistema existente: [ANIMATION_SYSTEMS.md](ANIMATION_SYSTEMS.md).

## Fase 1: implementación, pruebas y aprobación

| Paso | Estado al cierre |
| --- | --- |
| 1–4 | Base terrestre implementada: reposo, caminata, carrera, giros y transiciones. Aprobada como conjunto previo al cierre del paso 5; no consta aquí el desglose original por número (el visor histórico identifica giros como paso 3). |
| 5 | Locomoción y adaptación al terreno aprobadas visualmente; cierre funcional `651b81a`. Tres estados: normal, cauteloso y cansado. Conservar poses y rendimiento. |
| 6 | Salto voluntario aprobado visualmente en `343af25`, integrado en pruebas en `019a52b`. Reducción del 60 % de preparación **ya aplicada** en `2bc9e89`: 0,50 → 0,20 s, mismas poses; impulso 0,105 s. Visor y física comparten tiempos; despegue tras 0,305 s, sujeto al tick físico. No repetir la reducción. |
| 7 | Caída automática implementada e integrada en `019a52b`, conservada en el catálogo aprobado. Distingue salto y pérdida de apoyo; recuperación provisional por altura. No equivale a aprobar el aterrizaje nuevo del paso 8. |
| 8 | **Pendiente de finalizar.** Piloto Blender de 3 m disponible solo en el visor, con valoración visual positiva del usuario; familia Blender corregida 3–<8 m disponible solo en el visor, con mezcla continua por velocidad de impacto. Falta aprobación visual, entradas/estados adicionales y posterior integración jugable. |
| 9 | Pendiente; alcance y aprobación no documentados. Confirmar el plan antes de implementarlo. |
| 10 | Pendiente; alcance y aprobación no documentados. Confirmar el plan antes de implementarlo. |

Conservar los aterrizajes aprobados de **0,55 y 1,50 m**. La familia nueva abarca
**3 a menos de 8 m**, 1,8 s de recepción a 3 m y hasta casi 2,4 s, progresivamente
más pesada a mayor impacto. Dos extremos editables: `aren_landing_3m.blend` y
`aren_landing_heavy.blend`; comandos y límites en ANIMATION_BLENDER_PILOT.md. **Desde 8 m el desplome completo sigue sin implementar.**

## Piloto Blender reutilizable (`60a4056`)

El usuario estima una **mejora visual de al menos el 80 %** frente a la versión
procedural. Es una valoración subjetiva suya, no una medición técnica ni una
aprobación de integración o de todas las alturas. El cambio de metodología sí
está aprobado. El piloto original cubre solo **3 m, normal y entrada desde reposo**. La
corrección actual amplía alturas a **3–<8 m** mediante dos clips completos
creados en Blender; aún mantiene estado normal y entrada desde reposo.

- Carpeta: `assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/`.
  Contiene `authoring/aren_landing_3m.blend`, `authoring/reference_pose.json`,
  exportación `landing_3m.glb` y clip nativo `landing_3m.res`.
- Nueve poses completas en la corrección actual (ocho en el piloto), rig original y controles IK externos; acciones editables
  `ArenLanding3m_EightWholePoses` (nombre histórico); el exportador genera
  `ArenLanding3m_Baked` sobre una copia evaluada.
  Referencia anatómica acordada, sin mocap: pie izquierdo adelantado y rodilla
  hacia delante, antepié derecho estabilizador, rodilla derecha suspendida a
  3–5 cm, pelvis equilibrada, columna curvada y palma complementaria.
- Autoría: `tools/animation/author_aren_landing_blender.py`.
  Importación: `tools/animation/import_aren_blender_landing.gd`.
  Reproducción/contactos: `scripts/animation/authoring/aren_blender_landing_actor.gd`
  y `aren_blender_landing_contacts.gd`; reutilizan el rig y los solvers actuales.
- Procedimiento: editar poses/controladores en el `.blend`, revisar visualmente,
  guardar, hornear/exportar con `--bake-only`, importar el clip y comparar en
  Godot. **Sin `--bake-only` se sobrescribe la autoría con las poses iniciales.**
  Comandos exactos, fotogramas y límites en [ANIMATION_BLENDER_PILOT.md](ANIMATION_BLENDER_PILOT.md).
- Automático: IK, interpolación, horneado visual y conversión del mismo rig.
  Requieren autoría: referencia, poses, equilibrio, trayectorias y tiempos.
  Requieren revisión: silueta, intersecciones y continuidad. No hay retargeting
  general ni generación automática de biomecánica válida.

## Visores, escena jugable y comprobaciones

- `scenes/prototype_3d/aren_authoring_review.tscn` (**F6**): limpieza publicada
  en `5e93839`. Categorías **Animaciones aprobadas** (locomoción, salto, caída
  automática y acceso a giros) y **Animación en desarrollo**, con un único
  **Blender · recepción 3–<8 m**. Comparación **Anterior (piloto Blender) /
  Actual (Blender corregido)** al mismo instante, conservando pausa; velocidades 1,0× y
  0,25×, fases, reinicio y vistas frontal/lateral/trasera/diagonal. Las fuentes
  históricas están fuera del catálogo, conservadas en disco. La próxima prueba
  debe sustituir la actual y su pareja, sin acumular variantes ni presentarse
  como definitiva. La referencia anterior conserva el clip del piloto; los históricos procedurales
  permanecen sin modificar y fuera del catálogo.
- `scenes/prototype_3d/aren_turn_review.tscn`: comparación de giros existente.
- `scenes/prototype_3d/aren_terrain_test.tscn` (**F6**), actor
  `scenes/prototype_3d/aren_terrain_actor.tscn`: plano, terreno irregular y
  desniveles físicos. WASD, Mayús para correr, Espacio para saltar, 1/2/3 estados,
  4/5 camino/bosque, 6/7/8/9 plataformas de 0,55/1,50/3/8 m; R reinicia,
  botón derecho+ratón controla cámara. El piloto no está integrado;
  `deep_landing_enabled=false` en `aren_air_motion.gd`.
- Pruebas existentes: `tests/aren_blender_landing_family.gd` (alturas intermedias, contactos y separación),
  `tests/aren_blender_landing_pilot.gd` (clip, contactos,
  continuidad y catálogo), `tests/aren_air_integration.gd`,
  `tests/aren_locomotion_integration.gd`, `tests/aren_turn_review.gd`.
  Recepción procedural: `tests/aren_deep_landing.gd` y
  `tests/aren_landing_surface_clearance.gd`.
  Ejemplo: `godot --headless --path . --script tests/aren_blender_landing_pilot.gd`.
- **Probado previamente:** importación/render de Blender y Godot, rig nativo,
  contactos de palma/pies, rodilla suspendida, continuidad y controles del visor.
  La familia corregida añade comprobaciones de alturas intermedias y conserva
  la comparación y los controles del visor. La aprobación artística sigue pendiente.
  **Pendiente:** validación visual definitiva y pruebas jugables de la nueva
  recepción en alturas intermedias, terreno real y locomoción de entrada/salida.

## Trabajo local conservado y siguientes acciones

El traspaso anterior documentó correcciones procedurales **locales, sin
publicar ni aprobar como versión final**, anteriores al piloto. El checkout
sincronizado estaba limpio; estas fuentes no se modifican ni se recrean:

- `scripts/animation/authoring/aren_kneeling_landing_pose.gd`:
  preparación aérea coordinada, polos de rodilla y recuperación de manos.
- `scripts/animation/authoring/aren_landing_actor.gd` y `aren_landing_pose.gd`:
  conexión de esa preparación, continuidad de salida y objetivos de retirada.
- `scripts/animation/authoring/aren_review.gd`: etiquetas/referencia procedural.
- `tests/aren_deep_landing.gd` y `tests/aren_landing_surface_clearance.gd`:
  comprobaciones asociadas. La documentación extensa local se consolida aquí.

Prioridad: terminar la recepción en Blender y revisar la comparación; adaptar
continuamente a 3–<8 m y a las entradas/estados necesarios; integrar solo tras
aprobación visual y validar contactos, continuidad y rendimiento en terreno real.
No cambiar los aterrizajes bajos ni reabrir locomoción/salto aprobados.
Problemas históricos: cuatro discrepancias de procedencia de herramientas en
metadatos de `aren_walk_torso_v2` detectadas por `tests/aren_torso_coordination.gd`;
no regenerar clips aprobados para silenciar hashes. Plataformas móviles pendientes.
