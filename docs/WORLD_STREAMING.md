# Mundo procedural de 40,96 km²

El prototipo 3D usa un mundo de **6400 × 6400 metros** (40,96 km²), con
coordenadas X/Z entre −3200 y +3200. El suelo físico y las cuatro paredes del
límite son unas pocas formas compartidas; no se instancian recursos ni
superficies visibles para todo ese espacio al empezar.

## Ajuste gráfico

En **Configuración → Gráficos → Generación de mundo**:

| Opción | Distancia desde el personaje en cada dirección |
| --- | --- |
| 100 metros | Ventana menor |
| 200 metros (base) | Valor predeterminado |
| 400 metros | Ventana mayor |

Se guarda en `world_generation` dentro de la configuración del usuario y se
aplica durante la partida sin reiniciarla. Las configuraciones anteriores, o
con distancias no admitidas, usan 200 metros. No se cambia la resolución de la
pantalla. La opción también está disponible en el menú principal.

La ventana cubre los dos ejes alrededor del personaje: con 200 metros abarca
al menos 400 × 400 metros. Los bordes se redondean a chunks y se conserva una
corona de retención para evitar descargas y recargas al oscilar en un borde;
por eso puede permanecer algo más de terreno que la distancia nominal.

## Generación y descarga

- `stream_layout.gd`: semilla independiente por coordenada de chunk. La zona
  inicial conserva las posiciones, especies, edificios, charcos y elevaciones
  del generador existente. Fuera de ella se extienden sus árboles, rocas,
  plantas, césped, caminos y texturas a partir de la misma semilla y sampler.
  El orden en que se explora no modifica los resultados.
- `world_content.gd`: chunks de contenido de 32 metros, con prioridad a los más
  cercanos y presupuesto aproximado de 4 ms por fotograma para crear y liberar
  nodos. Una instancia individual no puede interrumpirse a mitad de su creación.
  No se calculan ni almacenan los 40000 chunks potenciales antes de explorar.
- `terrain_chunks.gd`: superficies de 28 metros (1024 unidades del sampler),
  hasta ocho activaciones progresivas por fotograma y caché de 16 chunks
  ocultos. El shader conserva coordenadas globales para evitar costuras. La
  posición del observador se actualiza en pasos de ocho metros con margen de
  cobertura; el contenido cambia de ventana al cruzar sus chunks de 32 metros.

La pantalla de carga espera únicamente la ventana inicial. Si se continúa una
partida lejana, se prepara directamente su ubicación guardada, sin instanciar
primero el campamento. Durante esa pantalla el mundo 3D está oculto y sus
niveles de detalle ya se preparan; la interfaz de carga sigue visible. Los
interiores cercanos conservan su streaming anterior.

## Persistencia

Los IDs originales del campamento permanecen intactos. Los recursos nuevos
usan IDs `w2:x:z:slot`. Al descargar un chunk, se conservan los cambios de salud,
incluyendo agotamiento completo; la disposición sin modificar se regenera
mediante la semilla. El guardado contiene cambios, no todos los objetos del
mundo ni un historial de chunks visitados.

Se valida cada ID y su salud contra su chunk generado, agrupando la validación
por chunk. Se admiten las tablas completas de recursos de guardados anteriores.
El formato sigue en versión 1; se amplían los límites de coordenadas y el
presupuesto de cambios. Mesas colocadas, objetos tirados y enemigos conservan
su guardado existente y su identidad.

## Integración con la optimización de distancia

Los objetos recién generados se registran automáticamente en el controlador de
[calidad por distancia](DISTANCE_OPTIMIZATION.md). Se conservan todos sus
umbrales y la recuperación gradual; los enemigos se suspenden desde 150 metros
con su estado. Las instancias de césped reciben su presupuesto individual.

Cuando desaparece el último usuario de una malla o material se libera también
su caché de variantes; los trabajos pendientes sin usuarios se descartan. La
simplificación geométrica se calcula en el hilo secundario y las mallas de
renderizado se crean en el hilo principal, evitando conflictos con la creación
y destrucción de nodos durante el streaming. La limpieza se difiere hasta que
el nodo ha terminado de salir del árbol.

## Comprobaciones

- `tests/prototype_3d_world_streaming.gd`: superficie total, cobertura local,
  semilla, posiciones originales, viajes de kilómetros, descarga real, los tres
  radios, vuelta a recursos dañados/agotados, guardado en disco y continuación
  en una posición remota. Comprueba además guardados anteriores y registro en
  el controlador de calidad.
- `tests/prototype_3d_generation_settings.gd`: valores admitidos, migración,
  persistencia real y selección de las tres opciones en el control gráfico.
- `tests/prototype_3d_distance_optimization.gd`: umbrales, recuperación,
  suspensión de enemigos y liberación de cachés sin usuarios. Los dos casos de
  buffers MultiMesh requieren renderizador nativo.
- Regresión de población, recursos derivados, guardado, terreno, interiores e
  integración del prototipo. Revisión gráfica de inicio, menú y una ubicación
  a X=2100/Z=−1800 con Compatibility/OpenGL.

Las distancias mayores exigen más memoria y trabajo de renderizado. Las
pruebas del entorno usan Linux y renderizado por software; no equivalen a una
medición de FPS ni a una prueba del ejecutable en el ordenador del usuario.


Las máscaras visuales de biomas y caminos se preparan ahora en una caché
asíncrona ligada a estos mismos chunks. La disposición y las consultas del
sampler permanecen como fuente de generación. Detalles y comparación visual
en [SHADING_ANIMATION_OPTIMIZATION.md](SHADING_ANIMATION_OPTIMIZATION.md).
