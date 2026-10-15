# Enemigo1: Meshy Mossclaw Boar

Por petición del usuario, se elimina la reconstrucción procedural y se utiliza
el FBX adjunto **Meshy_AI_Mossclaw_Boar_1015190139_texture.fbx**. Se conserva una
copia original sin modificar en `entregables/enemigos/enemigo1/source/`.
La ilustración `entregables/enemigos/enemigo1_joven_3d.png` se mantiene como
referencia visual; ya no se proyecta sobre el personaje ni genera su volumen.

## Procedencia y fidelidad del archivo

[ZIP original en la Release modelo-enemigo1](https://github.com/LikoKriko/Godotgame1/releases/download/modelo-enemigo1/Meshy_AI_Mossclaw_Boar_1015190139_texture_fbx.zip).
Su SHA-256 coincide con el proporcionado por el usuario:
`f0af7cc7091dfa1c6219a23b6c609e695a1a7dae90206889fab21802ed4c3655`.
`assets/enemies/first/meshy/source.json` registra URL, hashes del FBX/PNG,
versiones de herramientas y estadísticas de entrada/salida.

El FBX tiene **488891 vértices de autoría y 977782 triángulos**. La conversión
mantiene todos los triángulos; el recurso de Godot tiene **518861 vértices**
por las separaciones necesarias de normales y UV. No se decima, remalla,
reconstruye el pelaje ni modifican las proporciones. Se aplica una sola escala
uniforme y una traslación para centrarlo y colocar los pies sobre el suelo.
La postura **Postura de referencia** reproduce la geometría suministrada.

Se conservan byte por byte los cuatro PNG originales: color, normal, rugosidad
y metalicidad. El material nativo de Godot usa esas UV y mapas, con nearest y
mipmaps. Se retiran `young_reference_mesh.gd` y los shaders propios
`young_skin.gdshader` / `young_outline.gdshader`. No hay geometría alternativa
ni reproyección de la referencia. Las capturas viejas de antes/después también
se retiran para no confundirlas con la entrega actual.

## Integración en el juego

El FBX no incluye esqueleto ni animaciones. Se añade un esqueleto de catorce
huesos y pesos por difusión de calor de Blender; se conservan y normalizan las
cuatro influencias principales de cada vértice. Esto es una adaptación para
las acciones provisionales del juego, no animaciones originales de Meshy.
La primera asignación analítica de pesos se descartó tras detectar estiramientos
de mejillas al golpear; la versión publicada usa la ligadura por difusión.

`young_model.gd` carga directamente `mossclaw_skin.res`. La malla y el material
se comparten entre enemigos; los esqueletos son independientes. No se genera
geometría ni se calculan pesos al crear un enemigo. Se mantiene la altura de
**0,875 m**. Los anclajes de caderas, hombros, puños y cabeza se adaptan al FBX;
la zona de impacto del hocico sigue su punta real. Los brazos tienen segmentos
de 6,1 y 6,6 unidades de autoría; las patas, 4,3 y 4,4. Se conservan marcha
cuadrúpeda, golpes alternos, sentado, comida, aturdimiento y cadáver. Vida,
daño, memoria, botín, alcance y tiempos de acciones siguen iguales.

El recurso comprimido ocupa unos 23 MiB, además de los cuatro PNG. Su detalle
es elevado: **977782 triángulos por enemigo**, sin LOD añadido. No se ha medido
el rendimiento en el ordenador del usuario ni se afirma una mejora de FPS.
El FBX original queda excluido de la importación por `.gdignore`; el recurso
nativo es el que usa el juego.

## Revisión

Abrir `scenes/prototype_3d/young_review.tscn` con F6. **Postura de referencia**
muestra el archivo en reposo de enlace; los cuatro botones permiten compararlo
con la lámina. El selector conserva las acciones y la alternancia de puños.
Las animaciones siguen siendo provisionales, conforme a la instrucción previa
del usuario de rehacerlas después de integrar el modelo.

![Referencia y modelo Meshy importado](previews/young_reference_comparison.png)

![Referencia y postura cuadrúpeda](previews/young_quadruped_comparison.png)

![Modelo Meshy dentro del juego](previews/young_meshy_in_game.png)

Las comparativas igualan la altura visible sin deformar las imágenes. Los
laterales se capturan a ±68° aproximados, con iluminación de revisión; la
partida cambia luz y sombras. Son renders del modelo real, no retoques de la
referencia. Se verifica identidad con el FBX proporcionado, no una equivalencia
artística porcentual entre ese FBX y la ilustración.

## Conversión reproducible

Herramientas usadas: Blender **4.3.2**, Godot **4.7.2**. Ejecutar desde el proyecto
con las rutas absolutas adecuadas para los archivos intermedios:

```sh
godot --headless --path . --script tools/enemy/export_meshy_bind.gd -- /tmp/rig_seeds.json
blender --background --python tools/enemy/convert_meshy.py -- \
  entregables/enemigos/enemigo1/source/Meshy_AI_Mossclaw_Boar_1015190139_texture.fbx \
  /tmp/mossclaw.glb /tmp/rig_seeds.json
godot --headless --path . --script tools/enemy/bind_meshy.gd -- /tmp/mossclaw.glb
```

El conversor exporta la malla sin remallar, añade el rig y calcula los pesos.
El enlazador remapea los nombres de huesos al orden del juego, normaliza la
escala, conserva posición/UV/topología, genera tangentes para el mapa normal,
instala los cuatro PNG y guarda el recurso comprimido. Los pesos y materiales
se preparan una vez; los usuarios del juego no necesitan Blender.

## Comprobaciones

- `tests/prototype_3d_young_reference_mesh.gd`: original FBX y PNG por SHA-256,
  identidad de posiciones/UV del recurso, 977782 triángulos, proporciones,
  ligadura neutra, pesos, caché e independencia; deforma el modelo en todos
  los estados y ambas manos.
- `tests/prototype_3d_creature.gd`: altura, catorce huesos, longitudes,
  zona de impacto sobre un vértice real del hocico, rutinas, combate y parry.
- `tests/prototype_3d_reference_models.gd`: piel ligada y acciones de ambos actores.
- `tests/prototype_3d_loot.gd`, `prototype_3d_saves.gd` y `prototype_3d.gd`:
  botín, persistencia e integración del juego.

Se revisan cuatro vistas de referencia, cuatro en cuadrupedia, seis acciones
con ambas manos y cuatro cámaras del mundo de prueba. Godot Linux/Compatibility;
no se valida Windows, audio físico ni rendimiento del equipo del usuario.
