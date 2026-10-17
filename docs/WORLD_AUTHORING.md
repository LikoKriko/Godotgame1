# Modelado de mundo mediante recetas

Una receta describe una parte del mundo en metros mediante primitivas
combinables y modelos existentes. Puede editarse en el Inspector de Godot o
prepararse como recurso `.tres` a partir de las indicaciones de diseño.
`data/world/recipes/initial_relief.tres` es la receta que usa la zona inicial.

## Piezas disponibles

- `path_profile.gd`: origen, curvas, anchura interior/exterior y extremos de un
  camino. La máscara de CPU y los parámetros del shader comparten estos datos.
- `ramp_feature.gd`: pendiente en grados, longitud, comienzo y transición lateral
  alrededor del camino. La dirección longitudinal de esta primitiva es Z negativa.
- `mound_feature.gd`: centro, radio y altura de una montaña suave. Una altura
  negativa permite una depresión.
- `bumps_feature.gd`: amplitud y frecuencias de pequeños baches dentro del camino.
- `scene_stamp.gd`: escena existente, coordenadas, giro, escala y huella de apoyo.
  Sirve para piezas estáticas del entorno; no crea reglas de IA o inventarios.

`terrain_recipe.gd` suma las alturas de sus primitivas, suaviza el borde del
recinto y declara el paso de la retícula y el margen de apoyo. Los modelos
instanciados conservan sus recursos originales. Sus identificadores deben ser
únicos dentro de la receta; el constructor comprueba su huella girada, escalada
y ampliada antes de crear la escena. El terreno bajo los modelos recibe una
base plana con margen del 5 % del diámetro y transición suave.

## Texturas y biomas

`data/world/terrain/temperate.tres` combina un `TerrainProfile` con el perfil de
población `data/world/biomes/temperate.tres`. Los cuatro canales mantienen el
contrato de los shaders: claro 1, oscuro 1, claro 2 y textura Path. Se reutilizan
los PNG entregados, con su muestreo pixelado, sin reconstruirlos ni recolorearlos.

Para otro bioma, crear copias de ambos recursos y asignar sus texturas,
proporciones y reglas de densidad/población. `biome_definition.gd` permite
ajustar árboles, rocas, plantas y el despeje de caminos sin cambiar el generador.
`world.gd` expone `terrain_configuration` para asignar el perfil de terreno de
la escena; vacío conserva el perfil actual. Los tamaños y presupuestos de
streaming del juego siguen fijados por el controlador del mundo.

El selector automático entre varios biomas geográficos no se añade a la
partida actual: cada controlador de terreno usa su perfil. Cambiar la población
activa también cambia la distribución procedural de ese perfil; los perfiles de
mundos publicados deben conservar sus reglas o acompañarse de una migración.
El perfil vigente mantiene los IDs y reglas de las partidas actuales.

## Construir una parte reutilizable

Desde el proyecto, usando el ejecutable de Godot:

```sh
godot --headless --path . --script res://tools/world/build_terrain_part.gd -- \
  --recipe res://data/world/recipes/initial_relief.tres \
  --terrain res://data/world/terrain/temperate.tres \
  --output user://terrain_part.tscn
```

El resultado es una escena nueva con mallas por partes de hasta 28 m, materiales,
colisiones y modelos declarados. No sobrescribe escenas existentes. La
herramienta limita una parte a 512 m por lado y rechaza reservas de historia,
modelos fuera del recinto, IDs repetidos y parámetros inválidos. Las coordenadas
son las de la receta; no trasladar la raíz de la escena sin adaptar también
los orígenes del camino. Los resultados de revisión quedan fuera del repositorio.

La herramienta exporta partes para autoría y revisión. No inserta todas sus
escenas en el mundo ni genera sus 40,96 km² por adelantado. Para el runtime se
consume la misma función de altura con `terrain_chunks.gd`; las mallas, apoyos y
colisiones de la zona inicial ya usan este sistema. `initial_relief.gd` conserva
su API como entrada compatible para el código existente.

## APIs para otros generadores

- `terrain_surface.gd`: `build_mesh(rect, height_callable, grid)` y `normal_at`.
  La función de altura recibe X/Z globales; origen de la malla en el centro del
  rectángulo. Mallas adyacentes comparten la altura y las normales de su borde.
- `terrain_support.gd`: `build(records, height, radius, bounds, margin, blend)`
  y `sample(point, original_height, index, blend)`. El índice usa celdas de 8 m;
  las bases solapadas comparten altura. Debe usarse el mismo `blend` al construir
  y al consultar. El generador valida antes las reservas y la huella completa.
- `world_random.gd`: `chunk_seed(seed, cell, channel)`. El canal vacío conserva
  el stream existente; nombres distintos separan futuros generadores sin
  consumir sorteos de árboles o recursos ya publicados.
- `terrain_sampler.gd`: `copy_for_worker()` copia también los recursos externos
  de configuración. No editar perfiles compartidos mientras trabaja un hilo;
  para modificarlos, usar `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)`.

Estas primitivas forman superficies de altura única. Cuevas, túneles y salientes
requieren escenas 3D propias y su integración de colisión; no se simulan como
agujeros en un campo de alturas.
