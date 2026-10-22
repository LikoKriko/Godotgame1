# Aren: piloto de recepción mediante poses completas en Blender

Piloto aislado de **3 m, estado normal y entrada desde reposo**. Solo se carga
en `aren_authoring_review.tscn`; no sustituye clips aprobados ni se conecta a
`aren_terrain_test.tscn`. El visor conserva la fuente procedural existente.

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
materiales, ocho marcadores de pose, controladores IK de manos/pies, polos de
codos/rodillas y cámaras. La acción editable es
`ArenLanding3m_EightWholePoses`; `ArenLanding3m_Baked` conserva el horneado.
Los controladores son objetos externos al esqueleto: no añaden huesos al rig.

| Fotograma a 60 FPS | Pose de cuerpo completo |
| --- | --- |
| 1 | Pérdida de apoyo / comienzo de preparación aérea |
| 17 | Preparación aérea coordinada |
| 37 | Postura previa al contacto |
| 48 | Impacto físico de los pies |
| 60 | Absorción y apoyo de palma |
| 71 | Estabilización breve y transferencia de apoyo |
| 104 | Incorporación, mano retirada y pie derecho recuperado |
| 156 | Equilibrio erguido recuperado |

El pie izquierdo se mantiene fijo hasta la recuperación del derecho. Los pasos
utilizan arcos en los controles de pie. La palma queda fija entre los
fotogramas 60 y 71. La rodilla derecha permanece suspendida; la mano izquierda
ayuda al equilibrio sin servir de apoyo.

## Qué es automático y qué requiere autoría

- **Decisiones de autoría:** referencia, ocho poses, posición de pelvis,
  distribución del torso, apoyos, objetivos de manos, planos de flexión y
  tiempos. Se han definido con la API de Blender y se pueden modificar
  visualmente en el `.blend`. El sistema no inventa una biomecánica válida.
- **Automático:** IK de extremidades en Blender, interpolación entre claves,
  horneado visual por fotograma, exportación glTF y conversión al formato de
  clips nativos existente. El ajuste de ejes se limita al mismo rig original;
  no amplía el retargeting a otros esqueletos.
- **En Godot:** la física existente mantiene la caída balística de 3 m. El clip
  se sincroniza con el contacto, con 1,8 s de recepción posterior. El solver y
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
**Piloto Blender · recepción 3 m** ofrece las cuatro cámaras, pausa, reinicio,
velocidad y selección de fases existentes. **Anterior (procedural) / Actual (Blender)**
alterna las fuentes conservando el instante y la pausa. La comparación usa la
versión procedural presente en el checkout, incluyendo cambios locales
pendientes; no los reemplaza ni los publica automáticamente.

Las pruebas del piloto se ejecutan con:

```sh
godot --headless --path . --script tests/aren_blender_landing_pilot.gd
```

El método puede reutilizarse para otras acciones de Aren mediante nuevas poses
y clips independientes. Este piloto no generaliza alturas, estados, otras
criaturas ni un sistema automático de captura de movimiento.

El selector principal separa **Animaciones aprobadas** (locomoción, salto,
caída automática y acceso al visor de giros) de **Animación en desarrollo**.
Esta última contiene únicamente el piloto de recepción a 3 m, pendiente de
aprobación. La comparación conserva el instante y la pausa en ambas direcciones;
los controles de velocidad ofrecen 1,0× y 0,25×. Las fuentes históricas siguen
en disco, fuera del catálogo visible. Una próxima corrección debe sustituir
la prueba en desarrollo y su pareja de comparación, sin añadir un historial.
