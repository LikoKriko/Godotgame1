# Optimización por distancia y orientación

Una unidad del mundo equivale a un metro. Se modifica la representación de texturas y mallas;
las colisiones, hitboxes y reglas del combate conservan sus dimensiones.

## Presupuesto visual

La distancia se mide desde el personaje hasta el centro del objeto. En grupos
de vegetación se calcula por instancia, no desde el origen del grupo completo.

| Distancia | Calidad objetivo | Reducción acumulada |
| --- | --- | --- |
| Menos de 30 m | 100 % | 0 % |
| Desde 30 m | 95 % | 5 % |
| Desde 40 m | 90 % | 10 % |
| Desde 50 m | 80 % | 20 % |
| Desde 65 m | 65 % | 35 % |
| Desde 75 m | 45 % | 55 % |
| Desde 90 m | 35 % | 65 % |

Los escalones se aplican y revierten al cruzar cada distancia. Además, los
objetos a 50 m o más en el semiespacio contrario a la dirección de la cámara
tienen un máximo del 50 %. Se toma el menor de ambos presupuestos; las
reducciones no se suman. Al girar la cámara hacia ellos, recuperan diez puntos
por cada 0,1 segundos, hasta el límite que corresponda a su distancia actual.
Se utiliza la orientación real de la cámara de apuntado, incluido su cabeceo.

`distance_quality.gd` contiene estos umbrales. `distance_optimization.gd`
actualiza el mundo cada 0,1 segundos y registra también los objetos creados
posteriormente. Interfaz y visores de inventario quedan fuera del recorrido.

## Texturas y geometría

Las texturas del mundo usan mipmaps y un sesgo de muestreo calculado como
`-log2(calidad/100)`. Esto expresa una escala de resolución lineal, sin cambiar
los PNG originales ni crear copias de texturas en cada escalón. Los materiales
originales se recuperan al 100 %; se conservan los parámetros de iluminación
del terreno cuando cambian durante un nivel reducido.

Las mallas usan LOD nativos de Godot/meshoptimizer, preparados en un hilo
secundario y compartidos entre instancias. Cada presupuesto selecciona el
número de triángulos disponible más cercano: la reducción geométrica es
discreta y no garantiza exactamente ese porcentaje de polígonos. Mientras se
prepara un recurso se conserva su malla original. Se mantienen UV, materiales,
pesos de piel, formas de mezcla y sus valores activos. Los FBX y recursos fuente
no se sustituyen. Los grupos MultiMesh generales se reparten por calidad sin
modificar sus buffers originales, transformaciones, colores ni datos personalizados.

El césped conserva sus siete hojas triangulares por grupo y agrupa la geometría
de cada parcela en una superficie. Su shader aplica el presupuesto de textura
por grupo, con el mismo historial de distancia, orientación y recuperación,
sin recorrer cada instancia desde GDScript. Las variantes de LOD mantienen
sus índices independientes y el cambio de una malla no invalida las demás.

Los mipmaps y la caché de LOD consumen memoria adicional; esta implementación
busca reducir el trabajo de representación y no promete ahorro global de RAM.

## Enemigos desde 150 metros

Se libera el nodo visual con su esqueleto y se suspenden la simulación física y
las colisiones del enemigo. Un actor ligero conserva posición, velocidad,
acción, fase, temporizadores, inventario y pose facial. Al volver a menos de
150 m se reconstruye su representación y continúa la acción suspendida. Los
recursos fuente compartidos pueden seguir en caché: no se descarga toda su
memoria de recursos. El guardado admite actores lejanos y vuelve a suspenderlos
al cargar si corresponde.

El mundo ampliado se describe en [WORLD_STREAMING.md](WORLD_STREAMING.md).
La suspensión a 150 m se mantiene con cualquiera de los tres radios de
generación. La optimización adicional de cadáveres inmóviles sigue aplazada.
