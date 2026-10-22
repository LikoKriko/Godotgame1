# Aren: piloto de recepción mediante poses completas en Blender

Familia de recepción aislada de **3 a menos de 8 m, estado normal y entrada desde reposo**.
La base de comparación es el piloto Blender anterior (`60a4056`); los dos
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
materiales, nueve marcadores de pose, controladores IK de manos/pies, polos de
codos/rodillas y cámaras. La acción editable es
`ArenLanding3m_EightWholePoses` (nombre histórico, ahora con nueve poses).
El exportador genera `ArenLanding3m_Baked` sobre una copia evaluada, sin
reescribir la autoría editable.
Los controladores son objetos externos al esqueleto: no añaden huesos al rig.

| Fotograma a 60 FPS | Pose de cuerpo completo |
| --- | --- |
| 1 | Pérdida de apoyo / comienzo de preparación aérea |
| 17 | Preparación aérea coordinada |
| 37 | Postura previa al contacto |
| 48 | Impacto físico de los pies |
| 60 | Absorción y apoyo de palma |
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
velocidad y selección de fases existentes. **Anterior (piloto Blender) / Actual (Blender corregido)**
conserva altura, instante y pausa; el clip anterior es una
copia independiente del piloto previo, reproducida con el mismo reloj de
impacto. Solo Actual mezcla los extremos corregidos. No se acumulan variantes
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

- `authoring/aren_landing_3m.blend`: nueve poses coordinadas. Se abre el torso
  sobre la rodilla adelantada, se separa la mano libre del muslo y se define
  una pose completa de transferencia a fotograma 87.
- `authoring/aren_landing_heavy.blend`: extremo más pesado, con preparación y
  absorción propias sobre el mismo rig; no representa un desplome desde 8 m.
- `landing_3m_previous.res`: piloto anterior conservado para comparación, sin
  alterar sus pistas. `landing_3m.res` y `landing_heavy.res` son los extremos actuales.
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
