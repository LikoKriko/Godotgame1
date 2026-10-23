# Aren: contexto vigente de animaciones

Rama exclusiva: **`test/animation-system-v1`**. No modificar `main`.
Base de la integración jugable: **`2a106af1`**, aprobado visualmente por el usuario, sobre la limpieza del visor `5e93839`
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
| 8 | **Recepción Blender aprobada visualmente (`2a106af1`) e integrada en `aren_terrain_test.tscn`.** Reutiliza los clips para 3–<8 m y adapta compresión/recuperación a velocidad vertical física; conserva entradas y salidas de locomoción en los tres estados. Las recepciones bajas se mantienen. Caída extrema ≥8 m en revisión independiente, solo visor y pendiente de aprobación visual. No se integra en `main`. |
| 9 | En curso: corregida la entrada de locomoción a caída automática desde el primer tick sin apoyo. El reloj visual se independiza de la confirmación física; contactos Blender precalculados al cargar y reutilizados al reiniciar. Resto de transiciones pendiente. |
| 10 | Pendiente; alcance y aprobación no documentados. Confirmar el plan antes de implementarlo. |

Conservar los aterrizajes aprobados de **0,55 y 1,50 m**. La familia nueva abarca
**3 a menos de 8 m**, 1,8 s de recepción a 3 m y hasta casi 2,4 s, progresivamente
más pesada a mayor impacto. Dos extremos editables: `aren_landing_3m.blend` y
`aren_landing_heavy.blend`; comandos y límites en ANIMATION_BLENDER_PILOT.md. **Desde 8 m el desplome completo es exclusivo del visor; su integración jugable sigue pendiente.**

## Piloto Blender reutilizable (`60a4056`)

El usuario estima una **mejora visual de al menos el 80 %** frente a la versión
procedural. Es una valoración subjetiva suya, no una medición técnica ni una
aprobación de integración o de todas las alturas. El cambio de metodología sí
está aprobado. El piloto original cubre solo **3 m, normal y entrada desde reposo**. La
corrección actual amplía alturas a **3–<8 m** mediante dos clips completos
creados en Blender. La prueba jugable reutiliza esas poses completas para los
tres estados y entradas desde reposo, caminata y carrera; conserva las fuentes
aprobadas de locomoción al entrar y salir.

- Carpeta: `assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/`.
  Contiene `authoring/aren_landing_3m.blend`, `authoring/reference_pose.json`,
  exportación `landing_3m.glb` y clip nativo `landing_3m.res`.
- Poses completas, rig original y controles IK externos. La acción activa
  `Aren_ContactAbsorption_WholePoses` conserva la referencia visible y añade
  compresión solo en 48–60; las acciones previas siguen inactivas. El exportador genera
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
  **Blender · recepción 3–<8 m**. Comparación **Anterior (absorción previa) /
  Actual (absorción reforzada)** al mismo instante, conservando pausa; velocidades 1,0× y
  0,25×, fases, reinicio y vistas frontal/lateral/trasera/diagonal. Las fuentes
  históricas están fuera del catálogo, conservadas en disco. La próxima prueba
  debe sustituir la actual y su pareja, sin acumular variantes ni presentarse
  como definitiva. La referencia anterior conserva los dos clips de la familia de `4217d0f`; los históricos procedurales
  permanecen sin modificar y fuera del catálogo.
- `scenes/prototype_3d/aren_turn_review.tscn`: comparación de giros existente.
- `scenes/prototype_3d/aren_terrain_test.tscn` (**F6**), actor
  `scenes/prototype_3d/aren_terrain_actor.tscn`: plano, terreno irregular y
  desniveles físicos. WASD, Mayús para correr, Espacio para saltar, 1/2/3 estados,
  4/5 camino/bosque, 6/7/8/9 plataformas de 0,55/1,50/3/8 m; **0** accede a
  una plataforma fija de **7 m**, independiente del selector −/+; R reinicia,
  botón derecho+ratón controla cámara. La escena activa `blender_landings=true`;
  el controlador compartido mantiene la integración desactivada por defecto.
  **−/+** cambia el borde Blender entre 3 y 7,9 m; **Mayús+4/5** crea un borde
  sobre tierra/bosque a esa altura; **Retroceso** retira esa plataforma para
  probar pérdida de apoyo desde reposo. Caminar/correr permite abandonar el
  borde normalmente. Los otros atajos conservan su comportamiento.
- Integración: `scripts/animation/terrain/aren_blender_landing.gd` reutiliza
  muestreador nativo, clips y solver de contactos del visor. Usa el impacto
  vertical previo a resolver la colisión, nunca velocidad vertical ya anulada.
  Adapta apoyos a las colisiones reales y conserva el rumbo durante absorción;
  devuelve movimiento y control al finalizar la recuperación.
- Pruebas existentes: `tests/aren_fall_entry_integration.gd` (pérdida de apoyo, continuidad y caché),
  `tests/aren_blender_landing_integration.gd` (caídas reales),
  `tests/aren_blender_landing_controls.gd` (saltos, estados y control), `tests/aren_landing_absorption.gd` (edición limitada al impacto),
  `tests/aren_blender_landing_family.gd` (alturas intermedias, contactos y separación),
  `tests/aren_blender_landing_pilot.gd` (clip, contactos,
  continuidad y catálogo), `tests/aren_air_integration.gd`,
  `tests/aren_locomotion_integration.gd`, `tests/aren_turn_review.gd`.
  Recepción procedural: `tests/aren_deep_landing.gd` y
  `tests/aren_landing_surface_clearance.gd`.
  Ejemplo: `godot --headless --path . --script tests/aren_blender_landing_pilot.gd`.
- **Probado previamente:** importación/render de Blender y Godot, rig nativo,
  contactos de palma/pies, rodilla suspendida, continuidad y controles del visor.
  La familia corregida añade comprobaciones de alturas intermedias y conserva
  la comparación y los controles del visor. La recepción y su compresión de `2a106af1` están aprobadas visualmente.
  La integración jugable añade cobertura de contactos físicos, terreno
  irregular, entradas y salidas, estados y respuesta a Espacio.

## Caída extrema ≥8 m: primera revisión

Nueva secuencia completa creada en Blender sobre el rig original, documentada
en [ANIMATION_EXTREME_BLENDER.md](ANIMATION_EXTREME_BLENDER.md). El visor permite
revisar cinco fases y los resultados de supervivencia/muerte; las recepciones
3–<8 m continúan disponibles. La acción extrema corregida conserva la base
`9dcd03ed`: arcos de brazos más cerrados y una incorporación iniciada por la
pierna derecha, seguida por la izquierda, con giro coordinado de pelvis/torso.
La coordinación sobre `b91fb769` adelanta el apoyo izquierdo, amplía la separación
entre inicios de piernas a unos 0,20 s y recupera la alineación del torso con
la pelvis antes de soltar las manos; conserva duración, intensidad y fases previas.
Los huesos del antepié se han inspeccionado; sus canales y pesos permanecen
intactos. **Sin integración jugable hasta aprobación visual.**
La plataforma de 8 m conserva su recuperación provisional.

## Transición de locomoción a caída automática

La mezcla hacia la postura aérea usa `air_time` desde el primer tick sin
apoyo, conservando la duración `BODY_RELEASE` existente. El detector mantiene
`GRACE`/`MIN_DROP` para clasificar caídas sin reaccionar a pequeños escalones;
su reloj de confirmación no retiene la última pose de locomoción. La llamada
del visor conserva su reloj anterior. No se cambian clips, impulso ni recepción.

La escena prepara los datos inmutables de piel/contactos Blender durante
`_ready`, y `reset_at` reutiliza esa caché del mismo rig. Así el primer tick
aéreo no construye esos datos al abandonar una plataforma. El reloj visual
no altera gravedad, velocidad horizontal, orientación ni el contacto físico
que inicia la recepción.

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

La aprobación visual permite la integración en la escena de pruebas. Las
fases siguientes y la integración en `main` requieren instrucciones propias.
No cambiar los aterrizajes bajos ni reabrir locomoción/salto aprobados.
Problemas históricos: cuatro discrepancias de procedencia de herramientas en
metadatos de `aren_walk_torso_v2` detectadas por `tests/aren_torso_coordination.gd`;
no regenerar clips aprobados para silenciar hashes. Plataformas móviles pendientes.

Limitación anterior conservada: discontinuidad de contacto del salto normal
en la pendiente de 15° detectada por `aren_air_integration.gd`; no se modifica
la animación aprobada del salto para ocultar esa incidencia.
