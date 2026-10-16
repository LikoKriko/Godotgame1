# Optimización por distancia y orientación

Primera optimización del prototipo 3D, 16 de octubre de 2026. Una unidad del
mundo equivale a un metro. Se modifica la representación de texturas y mallas;
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
no se sustituyen. Los grupos MultiMesh se reparten por calidad sin modificar
sus buffers originales, transformaciones, colores ni datos personalizados.

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

El mapa actual es menor que ese umbral; la suspensión se verifica con actores
colocados expresamente a mayor distancia. No se amplía el terreno ni se aplica
la optimización adicional de detener cálculos de cadáveres inmóviles.

## Verificación

Godot 4.7.2, pruebas `tests/prototype_3d_distance_optimization.gd` y
`tests/prototype_3d_quality_resources.gd`: umbrales, recuperación temporal,
suspensión/reanudación y guardado de acciones, geometría e índices, piel,
formas de mezcla, materiales y restauración al 100 %. El renderizador headless
no expone los buffers MultiMesh; sus comprobaciones específicas se ejecutan
también con Compatibility/OpenGL nativo.

Regresión adicional: guardado, población, hitboxes, separación de criaturas,
rutinas, gestos faciales, botín, caídas e integración. Capturas nativas con la
misma cámara confirman cambios de detalle y restauración idéntica del fotograma
al recuperar el 100 %. No se ha medido una mejora de FPS en el PC del usuario ni
validado un ejecutable de Windows.
