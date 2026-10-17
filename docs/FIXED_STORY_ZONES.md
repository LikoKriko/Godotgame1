# Zonas fijas dentro del mundo procedural

El catálogo `data/world/story_zones.json` define lugares independientes de la
semilla. Se precarga como recurso JSON para incluirlo también al exportar el
juego. El escenario que los rodea sigue siendo procedural. Las coordenadas
son metros del mundo 3D: X y Z son los ejes horizontales; Y es la altura.

## Maqueta disponible

| Parámetro | Valor |
| --- | --- |
| ID estable | `story_demo_01` |
| Centro X / Y / Z | 192 / 0 / −128 m |
| Recinto X / Z | 32 × 24 m |
| Margen de protección | 8 m por lado |
| Reserva completa | 48 × 40 m |
| Contenido | Cinco cajas y una base de color liso |

Está fuera del campamento original, hacia X positivo y Z negativo desde el
inicio. Las cajas representan un edificio, un anexo, una torre y dos pilares;
conservan posición, dimensiones y color entre semillas y al volver al lugar.
Las cajas son sólidas. La base es una superficie de maqueta sobre el suelo
plano existente, sin cambiar la elevación del terreno.

## Editar y añadir lugares

Cada entrada de `zones` contiene:

- `id`: identificador único con letras, números y guiones bajos, comenzando por
  letra o guion bajo. Mantenerlo estable al sustituir la maqueta por contenido.
- `position`: centro `[X, Y, Z]` en metros.
- `size`: tamaño horizontal `[ancho X, fondo Z]` del recinto.
- `buffer`: separación adicional que queda libre de generación.
- `floor_color`: color hexadecimal de la base.
- `boxes`: elementos con su propio `id`, `offset` `[X, Y, Z]` relativo al centro,
  `size` `[ancho, alto, fondo]` y `color` hexadecimal. El offset Y señala la base
  de cada caja, no su centro vertical. El ID `floor` está reservado para la base.

El catálogo se valida antes de utilizarlo: rechaza IDs repetidos, valores no
finitos, cajas fuera del recinto, zonas fuera de los límites del mapa y reservas
que se solapan. El límite es de 256 zonas, 128 cajas por zona, 512 m por eje de
recinto y 64 m de margen. La versión de esquema del catálogo es 1.

## Exclusión de la generación

`story_zone_catalog.gd` expone `intersects(Rect2)` y `allows(Vector2, radio)`
para que otros generadores consulten la misma reserva. Todos los rectángulos y
radios de esta API se expresan en metros; incluyen el margen del catálogo.

Los árboles, rocas, plantas y césped se filtran por su huella completa, con una
cota conservadora de la copa o del tamaño del elemento. Los charcos y
plataformas también comprueban su huella antes de crearse. La huella completa
del relieve inicial se valida contra las reservas; las casas antiguas no se
instancian.
El cálculo en segundo plano recibe el mismo catálogo que el hilo principal.
Las exclusiones no consumen ni reordenan sorteos: fuera de las reservas se
mantienen los IDs, posiciones, variantes y rendimientos de la misma semilla.

La maqueta cubre el suelo dentro del recinto. Los biomas y senderos del shader
siguen existiendo como fondo: esta base no rediseña caminos, ríos ni desniveles.
Un generador futuro de poblados o caminos debe consultar la API de reservas al
proponer la huella de cada elemento. No se añaden poblados aleatorios nuevos.

## Carga y guardado

`story_zone_stream.gd` conserva una sola instancia por ID, independiente del
chunk que contenga su centro. Se carga cuando cualquier parte de su reserva
entra en la ventana del jugador y se descarga al salir de la ventana más una
retención de 32 m. Cada zona se carga como unidad; sus cajas se crean una a una
dentro del presupuesto de generación de 1,5 ms por fotograma. La pantalla de
carga espera también las zonas cercanas. Se respetan las opciones de 100, 200 y
400 metros y el controlador gráfico de distancia existente.

Las posiciones de las zonas proceden del catálogo, no de sorteos ni de una copia
de toda la geometría en el guardado. Al continuar se reconstruye directamente
la zona de la posición guardada. El formato de partida permanece en versión 1.
Los recursos de partidas anteriores que ahora queden dentro de una reserva
siguen teniendo un ID válido para conservar su daño o agotamiento; se mantiene
su estado guardado, pero no reaparecen invadiendo la zona. Mesas y objetos
colocados por el jugador conservan su persistencia existente.

La maqueta no contiene todavía misiones, inventarios ni estados de historia.
