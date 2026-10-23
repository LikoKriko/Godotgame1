# Aren: contexto vigente de animaciones

Rama exclusiva: **`test/animation-system-v1`**. No modificar `main`.
Base de la integración jugable: **`2a106af1`**, aprobado visualmente por el usuario, sobre la limpieza del visor `5e93839`
y el piloto `60a4056`. Obtener el último commit con `git log -1 --oneline`. Leer los `AGENTS.md` aplicables antes de editar.

## Punto de continuación

Último commit funcional publicado: **`1b210062`**. Incluye el `.blend` editable,
GLB/clip nativo, tiempos, herramientas, actor y pruebas de la incorporación nueva.
El commit de cierre documental se obtiene con `git log -1 --oneline`; comprobar
la publicación con `git ls-remote origin refs/heads/test/animation-system-v1`.
Al iniciar este cierre no había cambios locales ni trabajo funcional sin publicar.
Las versiones anteriores se conservan; **la Fase 1 continúa abierta**.

La recepción de `2a106af1` tiene aprobación visual; la incorporación extrema
de `1b210062` **solo tiene validación técnica y sigue pendiente de aprobación
visual del usuario**. Revisarla primero en el visor. No trasladarla a la escena
jugable ni integrar en `main` sin la autorización correspondiente.

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

## Incorporación extrema en revisión

La quinta fase dispone de un clip Blender nuevo e independiente de **6,25 s**,
con 12 poses completas y únicamente boca abajo/Idle como estados heredados.
El visor permite **Anterior / Nueva**; la anterior conserva sus ocho segundos.
Se emplea un apoyo intermedio de rodillas antes de adelantar el pie derecho,
para dejar espacio al muslo con las proporciones nativas de Aren. Las cuatro
primeras fases, muerte, otras animaciones y escena jugable se conservan.
**Pendiente de aprobación visual.** Fuente, referencias CMU, apoyos y comandos
en [ANIMATION_EXTREME_BLENDER.md](ANIMATION_EXTREME_BLENDER.md).

## Fase 1: implementación, pruebas y aprobación

| Paso | Estado al cierre |
| --- | --- |
| 1–4 | Base terrestre implementada: reposo, caminata, carrera, giros y transiciones. Aprobada como conjunto previo al cierre del paso 5; no consta aquí el desglose original por número (el visor histórico identifica giros como paso 3). |
| 5 | Locomoción y adaptación al terreno aprobadas visualmente; cierre funcional `651b81a`. Tres estados: normal, cauteloso y cansado. Conservar poses y rendimiento. |
| 6 | Salto voluntario aprobado visualmente en `343af25`, integrado en pruebas en `019a52b`. Reducción del 60 % de preparación **ya aplicada** en `2bc9e89`: 0,50 → 0,20 s, mismas poses; impulso 0,105 s. Visor y física comparten tiempos; despegue tras 0,305 s, sujeto al tick físico. No repetir la reducción. |
| 7 | Caída automática implementada e integrada en `019a52b`, conservada en el catálogo aprobado. Distingue salto y pérdida de apoyo; recuperación provisional por altura. No equivale a aprobar el aterrizaje nuevo del paso 8. |
| 8 | **Recepción Blender aprobada visualmente (`2a106af1`) e integrada en `aren_terrain_test.tscn`.** Reutiliza los clips para 3–<8 m y adapta compresión/recuperación a velocidad vertical física; conserva entradas y salidas de locomoción en los tres estados. Las recepciones bajas se mantienen. Caída extrema ≥8 m en revisión independiente, solo visor y pendiente de aprobación visual. No se integra en `main`. |
| 9 | En curso: corregida la entrada de locomoción a caída automática desde el primer tick sin apoyo. El reloj visual se independiza de la confirmación física; contactos Blender precalculados al cargar y reutilizados al reiniciar. Resto de transiciones pendiente. |
| 10 | Pendiente: validación general de la Fase 1 y revisión antes de integrar en `main`. La integración requiere aprobación expresa; la fase no está terminada. |

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

- `scenes/prototype_3d/aren_authoring_review.tscn` (**F6**): conserva el catálogo
  aprobado de locomoción, salto, caída automática y acceso a giros, y la revisión
  de **Blender · recepción 3–<8 m** con su comparación de absorción. La entrega
  actual se revisa en **Blender · caída extrema ≥8 m → Previsualizar: sobrevive
  → Comparar: Nueva**; **Anterior** conserva la incorporación de ocho segundos.
  Usar **Secuencia completa**, pausa/barra temporal, velocidades **1× / 0,25×**
  y vistas frontal/lateral/trasera/diagonal. Se conservan los clips históricos
  en disco; no añadir más versiones al catálogo.
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

## Caída extrema ≥8 m: visor

Nueva secuencia completa creada en Blender sobre el rig original, documentada
en [ANIMATION_EXTREME_BLENDER.md](ANIMATION_EXTREME_BLENDER.md). El visor permite
revisar cinco fases y los resultados de supervivencia/muerte; las recepciones
3–<8 m continúan disponibles. La primera fase de brazos se ha recreado desde
cero en Blender sobre `fc492dc8`: circunducción generada por los hombros,
codos pasivos de 20° ±1,2° y muñecas sin giro independiente. Solo se ajusta
un enlace breve de brazos al inicio de la inclinación; el resto del cuerpo
y las cuatro fases anteriores a la incorporación conservan sus poses y tiempos.
La quinta fase ofrece **Anterior / Nueva**. Anterior conserva la fuente de
`f87bdc13`, sus ocho segundos y el clip completo de 10,4 s. Nueva utiliza un
clip independiente de **6,25 s**, con 12 poses completas recién diseñadas;
solo hereda boca abajo e Idle. No reutiliza curvas, poses ni trayectorias de
la incorporación anterior. Sus apoyos intermedios de rodillas permiten elevar
el tronco antes de plantar el pie derecho (3,85 s) y adelantar la izquierda
(4,95 s). El cierre al Idle ocupa 0,45 s. El reloj completo termina en 8,65 s.
El IK lee los apoyos de su propio `timing.json`; la retirada de manos ya está
horneada y no se vuelve a mezclar hacia el apoyo anterior. La variante de
muerte y las cuatro primeras fases conservan sus clips y tiempos originales.
Los huesos del antepié se han inspeccionado; rig, pesos y carrera permanecen
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

## Validación, límites y próximos trabajos

La entrega actual corrige la incorporación mediante 12 poses nuevas, apoyos
intermedios de rodillas, entrada secuencial de pies y retirada de palmas sin
una segunda mezcla hacia el contacto anterior. Conserva las cuatro fases
previas, muerte, rig/pesos y el enlace exacto al Idle aprobado. Las fuentes
procedurales anteriores permanecen en Git; no hay una versión local adicional
pendiente de rescatar ni se deben reconstruir por referencias históricas.

Comprobaciones reproducibles y comandos en
[ANIMATION_EXTREME_BLENDER.md](ANIMATION_EXTREME_BLENDER.md): piel en todos los
fotogramas Blender, continuidad/contactos/colisión y controles en Godot a 1×
y 0,25×, y catálogo del visor. Se repitieron durante el cierre y todas pasaron,
sin regresiones detectadas en ese alcance. Las pruebas técnicas superadas no aprueban la
biomecánica visual ni sustituyen la validación jugable posterior de la caída extrema.

Siguiente acción: revisión visual de **Nueva** frente a **Anterior**. Tras la
aprobación, integrar la caída extrema mediante los sistemas vigentes de daño,
salud, física e IK y comprobar supervivencia/muerte en la escena jugable.
Después, completar las transiciones restantes del paso 9 y la validación del
paso 10. La reducción del salto ya está aplicada; no repetirla. Conservar las
recepciones bajas, la familia 3–<8 m y la locomoción aprobadas.

Incidencias previas aún abiertas: discontinuidad de contacto del salto normal
en pendiente de 15° (`aren_air_integration.gd`) y cuatro discrepancias de
procedencia en metadatos de `aren_walk_torso_v2`
(`aren_torso_coordination.gd`). No regenerar clips aprobados para ocultarlas.
Las plataformas móviles siguen pendientes. Estas incidencias no se han
corregido ni vuelto a certificar durante el cierre documental.
