# Aren: piloto de recepción mediante poses completas en Blender

Familia de recepción aislada de **3 a menos de 8 m, estado normal y entrada desde reposo**.
La base de comparación es la familia visible anterior al refuerzo de absorción
(`4217d0f`); los dos
extremos corregidos se editan en Blender y se mezclan como poses completas
según la velocidad vertical de impacto. Solo se carga
en `aren_authoring_review.tscn`; no sustituye clips aprobados ni se conecta a
`aren_terrain_test.tscn`. El visor conserva una única pareja Anterior / Actual. La fuente procedural
histórica sigue en disco y fuera del catálogo.

## Autoría y referencia

Se utiliza el FBX original `psnj1_3d_rigged.fbx`, con sus 66 huesos, jerarquía,
binds y longitudes. La normalización de altura/centrado es la misma del modelo
nativo de Godot; las manos conservan la proporción aprobada de 0,90.

La referencia de movimiento es la recepción acordada: apoyo delantero del pie
izquierdo, estabilización del antepié derecho con talón elevado, rodilla derecha
suspendida y palma complementaria. Se aplica flexión coordinada de cadera,
rodillas y tobillos, descenso del centro corporal, giro distribuido del torso
y transferencia del apoyo hacia los pies durante la incorporación. No se ha
utilizado mocap, vídeo convertido ni simulación dinámica de un cuerpo humano.

`authoring/reference_pose.json` conserva únicamente reposo y **una pose** de la
recepción de `545c705`, junto con el reposo del rig. No contiene una secuencia
procedural muestreada. Las otras poses, objetivos, trayectorias y tiempos se
han definido como decisiones completas de autoría para este piloto.

El archivo `authoring/aren_landing_3m.blend` contiene el rig original, malla,
materiales, marcadores de pose, controladores IK de manos/pies, polos de
codos/rodillas y cámaras. La acción editable activa es
`Aren_ContactAbsorption_WholePoses`. Las acciones de autoría anteriores se
conservan en el archivo como referencias inactivas.
El exportador genera `ArenLanding3m_Baked` sobre una copia evaluada, sin
reescribir la autoría editable.
Los controladores son objetos externos al esqueleto: no añaden huesos al rig.

| Fotograma a 60 FPS | Pose de cuerpo completo |
| --- | --- |
| 1 | Pérdida de apoyo / comienzo de preparación aérea |
| 17 | Preparación aérea coordinada |
| 37 | Postura previa al contacto |
| 48 | Impacto físico de los pies |
| 49–59 | Compresión reactiva coordinada; mínimo de pelvis en 54 (+100 ms a 3 m) |
| 60 | Enlace exacto con la absorción existente y apoyo de palma |
| 71 | Estabilización breve y transferencia de apoyo |
| 87 | Transferencia coordinada de apoyos y arco de retirada de palma |
| 104 | Incorporación, mano retirada y pie derecho recuperado |
| 156 | Equilibrio erguido recuperado |

El pie izquierdo se mantiene fijo hasta la recuperación del derecho. Los pasos
utilizan arcos en los controles de pie. La palma queda fija entre los
fotogramas 60 y 71. La rodilla derecha permanece suspendida; la mano izquierda
ayuda al equilibrio sin servir de apoyo.

## Qué es automático y qué requiere autoría

- **Decisiones de autoría:** referencia, poses completas, posición de pelvis,
  distribución del torso, apoyos, objetivos de manos, planos de flexión y
  tiempos. Se han definido con la API de Blender y se pueden modificar
  visualmente en el `.blend`. El sistema no inventa una biomecánica válida.
- **Automático:** IK de extremidades en Blender, interpolación entre claves,
  horneado visual por fotograma, exportación glTF y conversión al formato de
  clips nativos existente. El ajuste de ejes se limita al mismo rig original;
  no amplía el retargeting a otros esqueletos.
- **En Godot:** el visor conserva la caída balística de la altura seleccionada. El clip
  se sincroniza con el contacto. La recepción dura 1,8 s a 3 m y crece
  suavemente hasta casi 2,4 s al aproximarse a 8 m. El mismo reloj escala
  absorción, contacto de palma, transferencia y recuperación. El solver y
  las envolventes de piel existentes fijan suelas y palma mientras hay apoyo;
  no generan de nuevo la pose corporal del clip.
- **Revisión visual:** sigue siendo necesaria para silueta, equilibrio,
  intersecciones y trayectorias. Los contactos y la longitud correcta de los
  huesos por sí solos no garantizan una animación natural.

## Editar y hornear sin perder cambios manuales

Abrir el `.blend`, editar las poses o sus controladores y guardar. Para volver
a hornear **esas ediciones**, sin regenerar la autoría:

```sh
blender -b assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/authoring/aren_landing_3m.blend \
  -t 4 --python tools/animation/author_aren_landing_blender.py -- --bake-only
godot --headless --path . --script tools/animation/import_aren_blender_landing.gd
```

`--bake-only` exporta una copia evaluada y deja intacto el archivo de autoría.
El comando sin esa opción **regenera y sobrescribe el piloto** con las ocho
poses iniciales definidas en el script; no debe utilizarse para conservar
ediciones visuales posteriores.

La exportación escribe `landing_3m.glb` con los 66 huesos y una piel mínima de
exportación, sin duplicar el modelo visible del juego. El importador verifica
el reposo del mismo rig, convierte las coordenadas y guarda `landing_3m.res`.
El muestreador nativo existente reproduce las pistas horneadas. La carpeta de
autoría tiene `.gdignore` para impedir la importación automática del `.blend`.

## Revisión

Abrir `scenes/prototype_3d/aren_authoring_review.tscn` y ejecutar con F6. La fuente
**Blender · recepción 3–<8 m** ofrece las cuatro cámaras, pausa, reinicio,
velocidad y selección de fases existentes. **Anterior (absorción previa) / Actual (absorción reforzada)**
conserva altura, instante y pausa; el clip anterior es una
copia independiente de los dos extremos de la familia previa, reproducida con
el mismo reloj de impacto. Ambas opciones mezclan por la misma velocidad;
solo Actual añade la compresión. No se acumulan variantes
en el catálogo ni se modifican las fuentes procedurales históricas.

Las pruebas del piloto se ejecutan con:

```sh
godot --headless --path . --script tests/aren_blender_landing_pilot.gd
```

El método puede reutilizarse para otras acciones de Aren mediante nuevas poses
y clips independientes. La familia generaliza continuamente las alturas del intervalo mediante
velocidad vertical balística y mezcla de dos clips completos. No autoriza
integración jugable, estados cauteloso/cansado ni entradas desde caminar/correr;
no es un sistema automático de captura ni de validación biomecánica.

El selector principal separa **Animaciones aprobadas** (locomoción, salto,
caída automática y acceso al visor de giros) de **Animación en desarrollo**.
Esta última contiene únicamente la familia Blender de recepción 3–<8 m, pendiente de
aprobación. La comparación conserva el instante y la pausa en ambas direcciones;
los controles de velocidad ofrecen 1,0× y 0,25×. Las fuentes históricas siguen
en disco, fuera del catálogo visible. Una próxima corrección debe sustituir
la prueba en desarrollo y su pareja de comparación, sin añadir un historial.

## Extremos corregidos y reproducción

- `authoring/aren_landing_3m.blend`: conserva la secuencia visible previa y
  refuerza únicamente la absorción en 48–60. Las acciones editables anteriores
  siguen disponibles como referencias inactivas.
- `authoring/aren_landing_heavy.blend`: conserva la referencia visible del
  extremo de impactos altos y recibe la misma compresión breve sobre el mismo
  rig. La escala temporal por velocidad mantiene su recuperación más lenta;
  no representa un desplome desde 8 m.
- `landing_3m_previous.res` y `landing_heavy_previous.res`: familia anterior
  conservada para comparar exclusivamente el refuerzo de absorción. `landing_3m.res` y `landing_heavy.res` son los extremos actuales.
- `aren_blender_landing_motion.gd`: mezcla quíntica continua según velocidad de
  impacto entre los valores balísticos de 3 y 8 m. El visor ofrece alturas
  representativas hasta 7,9 m; el evaluador admite cualquier valor 3 ≤ h < 8.
  Contactos y poses comparten la escala temporal; Godot solo adapta los apoyos
  mediante el solver existente, sin recrear la animación corporal.

Para hornear el extremo pesado sin perder ediciones:

```sh
blender -b assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/authoring/aren_landing_heavy.blend \
  -t 4 --python tools/animation/author_aren_landing_blender.py -- --bake-only --output-stem landing_heavy
godot --headless --path . --script tools/animation/import_aren_blender_landing.gd -- --heavy
godot --headless --path . --script tests/aren_blender_landing_family.gd
```

`refine_aren_landing_blender.py` documenta la edición coordinada inicial sobre el
`.blend` del piloto; rechaza aplicarse de nuevo a una autoría ya corregida. Para
futuras correcciones se editan los `.blend` y se usa `--bake-only`. Conservar
los aterrizajes de 0,55 y 1,50 m, el rig, fuentes, binds y clips aprobados.
Las comprobaciones automáticas de contactos, longitudes y separación anatómica
se complementan con la revisión visual; no certifican todas las intersecciones
de la malla ni sustituyen la aprobación del usuario.

## Compresión de impacto aislada

La edición corporal queda limitada a los fotogramas **48–60**. El contacto
físico de los pies sigue en 48. La pelvis alcanza una compresión única en 54
y enlaza con la pose existente en 60, sin cambiar los tiempos de palma, pasos,
estabilización ni recuperación. Las rodillas y tobillos reaccionan mediante
IK de Blender contra los mismos objetivos; pelvis, columna, hombros y cabeza
acompañan con una pose completa. No hay escalado de huesos ni corrección corporal
procedural añadida en Godot. La duración de la familia y el zoom se conservan.

El exportador desactiva **Export all Armature Actions**
(`export_anim_single_armature=False`). Fusionar acciones históricas en
`ACTIVE_ACTIONS` podía sustituir silenciosamente las pistas recién horneadas.
Para preservar las poses que realmente mostraba el visor, la edición usa una
referencia de los clips nativos anteriores sobre el mismo rig; las acciones
editables previas permanecen inactivas, sin descartarse. No se reconstruye
movimiento fuera de la absorción.

Herramientas de esa edición inicial (no repetir sobre archivos ya corregidos):

```sh
godot --headless --path . --script tools/animation/export_aren_landing_reference.gd
blender -b assets/characters/prototype_3d/generated/aren_landing_blender_pilot_v1/authoring/aren_landing_3m.blend \
  -t 4 --python tools/animation/compress_aren_landing_blender.py -- --reference work/landing_absorption_reference/previous.json
# Para el extremo pesado, usar su .blend y previous_heavy.json.
```

Para futuras correcciones, editar la acción activa del `.blend` y utilizar los
comandos `--bake-only` anteriores. `tests/aren_landing_absorption.gd` comprueba
la conservación de poses fuera del tramo, duración, flexión reactiva, una sola
compresión, continuidad de objetivos y sincronización con contacto físico.
En el visor se puede desactivar **Detalle** para comparar a cámara fija y luego
reactivarlo para revisar con el zoom habitual. La integración jugable sigue
pendiente de aprobación visual.
