# Terreno procedural de Day Zero

El mapa de pruebas conserva su límite y sus árboles, rocas, plantas, charcos,
senderos y choza. El suelo utiliza exclusivamente `terreno_1_1.png` a
`terreno_1_4.png`, copiados desde entregables a los recursos importables.
`entregables/.gdignore` conserva los originales fuera de las importaciones de
Godot; los cuatro recursos gráficos del juego se importan una vez y se comparten.

## Arquitectura

- `scripts/terrain_profile.gd`: recurso con la configuración.
- `scripts/terrain_sampler.gd`: consulta determinista por coordenada global,
  semilla, tipo de suelo, mezcla y densidad de vegetación; no almacena el mundo.
- `scripts/terrain_chunks.gd`: ventanas de carga, descarga, caché y presupuesto
  por fotograma. Todos los chunks completos comparten una malla y cuatro texturas.
- `shaders/chunk_ground.gdshader`: ruido coherente a tres escalas y muestras
  superpuestas de las cuatro referencias con filtros nearest.
- `scripts/world_view.gd`: integra el renderizador con cámara, iluminación y
  objetos existentes; `test_world.gd` mantiene la distribución del mapa de pruebas.

El tipo normal predomina. Los umbrales se calibran mediante cuantiles para que
las proporciones configuradas correspondan aproximadamente a superficie, en
lugar de asumir una distribución uniforme del ruido. La semilla y las coordenadas
globales determinan cada muestra; cargar o descargar no modifica el suelo.

Las imágenes originales no se repiten mediante sus bordes. Las muestras parten
de anclas globales compartidas, con rotaciones, offsets y una deformación suave
comunes. Cada muestra usa el interior de la imagen. Sus pesos se extinguen antes
de cambiar de ancla; las divisiones de chunks no participan en este cálculo.
No se utiliza desenfoque espacial. Se conservan píxeles nearest, y las transiciones
mezclan únicamente sus colores en posiciones alineadas con el raster del mundo.

## Parámetros

| Parámetro | Valor inicial | Función |
| --- | --- | --- |
| `chunk_size` | 512 | Ancho y alto en unidades del mundo. |
| `chunks_per_frame` | 2 | Presupuesto de precarga progresiva. |
| `preload_chunks` | 1 | Anillo adicional alrededor de la cámara visible. |
| `retain_chunks` | 2 | Anillo retenido antes de descargar. |
| `cache_limit` | 96 | Máximo de chunks descargados conservados para reutilizar. |
| `pixel_step` | 1 | Tamaño del raster de muestreo en el mundo. |
| `region_scale` | 720 | Tamaño aproximado de las regiones orgánicas. |
| `transition_width` | 0,028 | Anchura de transición en el campo de ruido. |
| `texture_span` | 144 | Escala de las muestras superpuestas. |
| `proportions` | 67,5 / 10,5 / 12 / 10 % | Normal / oscuro / vegetación / tierra. |

Las proporciones se normalizan. `retain_chunks` debe ser igual o mayor que
`preload_chunks`. Subir precarga/caché mantiene más geometría; aumentar
`chunks_per_frame` permite preparar más deprisa las regiones próximas.
Los chunks que ya están visibles se activan de inmediato con geometría ligera,
incluso al teletransportar la cámara; el trabajo adicional se distribuye entre
fotogramas. No se crean bitmaps nuevos por chunk ni se vuelve a procesar el PNG.

## Consultas e integración

```gdscript
var kind: StringName = world.ground_sampler.type_at(position)
var weights: Vector4 = world.ground_sampler.weights_at(position)
var density: float = world.ground_sampler.vegetation_density(position)
```

`add_influence(id, type, rect, strength)` añade una máscara elíptica irregular para
suelo desnudo, estructuras u otros elementos. Repetir el ID actualiza esa máscara.
`refresh_influences()` actualiza los materiales de chunks ya creados. Las máscaras
se seleccionan por intersección del chunk, con un máximo de 32 influencias locales;
si se supera, se comunica un error. Las consultas y el shader comparten el hash,
las escalas y las fórmulas. Las bases del bosque generan manchas discretas de tierra,
las áreas despejadas conservan su suelo y los senderos actuales se integran con la
cuarta textura. La vegetación decorativa sigue evitando agua, caminos, bases y
plataformas; su agrupación usa también la densidad del nuevo terreno.

Las máscaras naturales del mapa se conservan al recolectar para que el suelo no
cambie al regresar o cargar una partida. La choza incorpora su propia zona desnuda.

Para un renderizador ilimitado independiente, no pasar `bounds` a `configure`:

```gdscript
var renderer = preload("res://scripts/terrain_chunks.gd").new()
add_child(renderer)
renderer.configure(seed, preload("res://scripts/terrain_profile.gd").new())
renderer.update_window(camera_center, viewport_size / camera.zoom, true)
# Repetir update_window cuando se actualice la cámara.
```

Esto no amplía la generación de objetos ni las colisiones del mapa de pruebas.

## Verificación

`tests/terrain_chunks.gd` comprueba determinismo, porcentajes, consultas, límites
antes/después de coordenadas negativas y positivas, descarga, presupuesto y caché.
`tests/terrain_render.gd` necesita renderizador real: compara cada píxel entre un
render dividido en chunks y otro con superficies grandes; también prueba el
regreso a zonas descargadas y la concordancia entre máscaras CPU/GPU. Incluye
coordenadas alejadas del mapa, sin límites de pruebas ni objetos.

```sh
godot --headless --path . --script tests/terrain_chunks.gd
godot --path . --rendering-method gl_compatibility --script tests/terrain_render.gd
```

La precarga se ha medido en el entorno de desarrollo con 100 desplazamientos:
mediana de 0,264 ms de CPU, percentil 95 de 0,329 ms y máximo de 0,938 ms, con
31 chunks activos, 96 en caché y cuatro texturas compartidas. Es una medición de
administración/carga de geometría, no una garantía de FPS ni una medida del coste
GPU del shader en otros equipos.
