# Enemigo1: Meshy Mossclaw Boar

Por petición del usuario, se elimina la reconstrucción procedural y se utiliza
el FBX adjunto **Meshy_AI_Mossclaw_Boar_1016001519_texture.fbx**. Se conserva una
copia original sin modificar en `entregables/enemigos/enemigo1/source/`.
La ilustración `entregables/enemigos/enemigo1_joven_3d.png` se mantiene como
referencia visual; ya no se proyecta sobre el personaje ni genera su volumen.

## Procedencia y fidelidad del archivo

[ZIP reducido vigente en la Release modelo-enemigo1](https://github.com/LikoKriko/Godotgame1/releases/download/modelo-enemigo1/enemigo1_3d.zip).
SHA-256 verificado al descargar:
`64e21cf1b8822e63a0913015a4b2ef29a6c6ca62831bf83eef4e5eadc938e5bc`.
`assets/enemies/first/meshy/source.json` registra URL, hashes del FBX/PNG,
versiones de herramientas y estadísticas de entrada/salida.

El FBX vigente tiene **3672 vértices de autoría y 7340 triángulos**. El recurso
nativo tiene **9212 vértices** por las separaciones de normales y UV. Antes
se cargaban 977782 triángulos y 518861 vértices de ejecución: la reducción de
triángulos es del **99,25 %**. Se utiliza la simplificación entregada por el
usuario; no se vuelve a decimar, remallar ni reconstruir el pelaje. La única
adaptación geométrica es escala uniforme a 32 unidades y centrado sobre suelo;
se mantiene la altura de **0,875 m**. El FBX denso anterior permanece como
fuente histórica, sin cargarse ni exportarse como alternativa de ejecución.
La postura **Postura de referencia** reproduce la geometría nueva.

Se conservan byte por byte los PNG del ZIP nuevo: color, normal, rugosidad,
metalicidad y el mapa combinado metálico/rugoso. Los cuatro mapas separados
se asignan al material; el combinado queda como fuente original. El material nativo de Godot usa esas UV y mapas, con nearest y
mipmaps. Se retiran `young_reference_mesh.gd` y los shaders propios
`young_skin.gdshader` / `young_outline.gdshader`. No hay geometría alternativa
ni reproyección de la referencia. Las capturas viejas de antes/después también
se retiran para no confundirlas con la entrega actual.

## Integración en el juego

El FBX no incluye esqueleto ni animaciones. Se añade un esqueleto con catorce huesos de base y una bisagra de cola
(quince en ejecución). La versión reducida recibe los pesos de la piel publicada en `1d58ff4`,
mediante interpolación baricéntrica del triángulo donante más próximo. Así
conserva la distribución animada de cabeza, patas, brazos, puños y cola; se
normalizan las cuatro influencias principales de cada vértice. La piel donante
procedía de difusión de calor y de la corrección de cola vigente. La animación del juego se adapta a esta ligadura; el archivo de Meshy no
aporta clips originales.
La primera asignación analítica de pesos se descartó tras detectar estiramientos
de mejillas al golpear; la versión publicada usa la ligadura por difusión.

`young_model.gd` carga directamente `mossclaw_skin.res`. La malla y el material
se comparten entre enemigos; los esqueletos son independientes. No se genera
geometría ni se calculan pesos al crear un enemigo. Se mantiene la altura de
**0,875 m**. Los anclajes de caderas, hombros, puños y cabeza se adaptan al FBX;
la zona de impacto del hocico sigue su punta real. Los brazos tienen segmentos
de 6,1 y 6,6 unidades de autoría; las patas, 4,3 y 4,4. Se conservan marcha
cuadrúpeda, golpes alternos, sentado, comida, aturdimiento y cadáver. Vida,
memoria, botín y alcance siguen iguales. El daño y los tiempos del nuevo
estado de boxeo se describen al final de este documento.

El recurso comprimido de geometría/pesos ocupa **248542 bytes** (unos 243 KiB),
frente a 24680554 bytes. Las texturas del ZIP nuevo ocupan más que las anteriores:
estas cifras se refieren exclusivamente a la malla nativa, no al conjunto de
archivos ni a su consumo total de memoria. No se ha medido el rendimiento en
el ordenador del usuario ni se afirma una mejora concreta de FPS. El FBX
original queda excluido de importación/exportación mediante `.gdignore`.

## Revisión

Abrir `scenes/prototype_3d/young_review.tscn` con F6. **Postura de referencia**
muestra el archivo en reposo de enlace; los cuatro botones permiten compararlo
con la lámina. El selector conserva las acciones y la alternancia de puños.
La revisión permite pausar y escoger una fase exacta para comprobar apoyos,
ambos puños y transiciones sobre el modelo importado actual.

![Modelo reducido en sus acciones](previews/young_reduced_review.png)

![Modelo reducido dentro del juego](previews/young_reduced_in_game.png)

Las siguientes comparativas son históricas, de la versión densa anterior:

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
mkdir -p /tmp/mossclaw-transfer
# Donante exacto previo a la reducción: conservar la ligadura vigente de 15 huesos.
git show 1d58ff4:assets/enemies/first/meshy/mossclaw_skin.res > /tmp/mossclaw-transfer/donor.res
godot --headless --path . --script tools/enemy/export_skin_transfer.gd -- /tmp/mossclaw-transfer/donor.res /tmp/mossclaw-transfer/skin
blender -b --python tools/enemy/transfer_meshy.py -- entregables/enemigos/enemigo1/source/Meshy_AI_Mossclaw_Boar_1016001519_texture.fbx /tmp/mossclaw-transfer/reduced.glb assets/enemies/first/meshy/rig_seeds.json /tmp/mossclaw-transfer/skin
godot --headless --editor --path . --import
godot --headless --path . --script tools/enemy/bind_meshy.gd -- /tmp/mossclaw-transfer/reduced.glb
cp /tmp/mossclaw-transfer/reduced.transfer.json assets/enemies/first/meshy/skin_transfer.json
# Comparación independiente sin esqueleto, usando el FBX original nuevo.
blender -b --python tools/meshy/convert_source.py -- entregables/enemigos/enemigo1/source/Meshy_AI_Mossclaw_Boar_1016001519_texture.fbx /tmp/mossclaw-transfer/source.glb
godot --headless --path . --script tools/meshy/verify_source.gd -- /tmp/mossclaw-transfer/source.glb res://assets/enemies/first/meshy/mossclaw_skin.res
godot --path . --script tools/enemy/review_reduced.gd -- /tmp/mossclaw-review
python tools/enemy/compose_reduced_review.py /tmp/mossclaw-review docs/previews/young_reduced_review.png
```

El exportador de piel guarda posiciones, triángulos, huesos y pesos donantes;
`transfer_meshy.py` conserva las posiciones/UV/topología nuevas y añade los
mismos quince nombres de huesos. `bind_meshy.gd` remapea los índices, normaliza
la escala, conserva la máscara de cola y genera tangentes para el mapa normal.
Lee procedencia y triángulos de `source.json`, sin fijar el número de caras
antiguo, y genera `anchors.gd` con el vértice real del hocico. No cambian clips,
anatomía, tiempos, daño ni comportamiento. Solo el anclaje del hocico sigue
ahora su punta visible nueva. Los usuarios del juego no necesitan Blender.

`skin_transfer.json` registra el donante SHA-256
`093e0ba122875ee045ca5bea3a7305edfdf566b9002fcc078cc3632d629ba17f`,
el máximo de distancia entre superficies (0,758 unidades de autoría) y su RMS
(0,281). La comparación independiente confirma todos los índices de triángulos,
posiciones, UV y normales dentro de la precisión de empaquetado de Godot.
Error máximo: posición 0,00094 unidades, UV 0,000022 y normales 0,00224.

## Comprobaciones

- `tests/prototype_3d_young_reference_mesh.gd`: original FBX y PNG por SHA-256,
  identidad de posiciones/UV del recurso, 7340 triángulos, proporciones,
  ligadura neutra, pesos, caché e independencia; deforma el modelo en todos
  los estados y ambas manos.
- `tests/prototype_3d_creature.gd`: altura, quince huesos, longitudes,
  zona de impacto sobre un vértice real del hocico, rutinas, combate y parry.
- `tests/prototype_3d_reference_models.gd`: piel ligada y acciones de ambos actores.
- `tests/prototype_3d_loot.gd`, `prototype_3d_saves.gd` y `prototype_3d.gd`:
  botín, persistencia e integración del juego.

Se revisan cuatro vistas de referencia, cuatro en cuadrupedia, seis acciones
con ambas manos y cuatro cámaras del mundo de prueba. Godot Linux/Compatibility;
no se valida Windows, audio físico ni rendimiento del equipo del usuario.

## Animaciones adaptadas al Meshy (15 de octubre de 2026)

Las quince acciones de `young_pose.gd` usan las proporciones de la ligadura
publicada en `d551f4c`. `bind_pose()` fija los puntos de enlace originales y
también alimenta el exportador; modificar un golpe no puede alterar el reposo.
No cambian el recurso `.res`, el FBX, posiciones, UV, topología, pesos ni PNG.

- Marcha y carrera cuadrúpedas con transferencia de peso, fases diferenciadas
  de manos y patas, elevación del talón y despeje de la suela real. El ciclo
  avanza según la velocidad alcanzada; el reposo respira de forma continua.
- Incorporación y bajada enlazadas con la guardia; puñetazos alternos con
  preparación, giro del torso, contrapeso y contacto en la mitad del segundo.
- Sentarse y levantarse transfieren los apoyos por separado. Descanso y
  alimentación tienen respiración, mirada y alcance alterno de los brazos.
- Aturdimiento y muerte parten de la pose que se interrumpe; recuperación
  y cadáver tienen finales continuos. El cadáver permanece inmóvil.

Las orientaciones completas de cada segmento siguen el plano de flexión y
conservan sus longitudes. Los puños acompañan al antebrazo. Se despejan los
apoyos teniendo en cuenta que la piel importada mezcla suela/pantorrilla y
piedra/antebrazo. Se mantienen las zonas de impacto del hocico y las manos.
No cambian vida, daño, alcance, botín ni tiempos de combate.

`prototype_3d_young_motion.gd` comprueba 15 acciones, ambas manos y 33 fases:
longitudes, piel deformada frente al suelo, continuidad de orientación,
enlaces entre estados, interrupciones y cadáver inmóvil. Se complementa con
la comprobación del FBX/PNG por SHA-256 de `young_reference_mesh`.


## Boxeo tras recibir daño (16 de octubre de 2026)

El primer daño no letal habilita una tirada inmediata del **50 %**; después
se comprueba cada **10 segundos** de juego. Recibir más golpes no reinicia el
reloj ni añade tiradas. Un éxito activa **20 segundos** de postura erguida:
no se extiende un estado activo en las comprobaciones intermedias. Al terminar
puede salir otra tirada en el siguiente límite de 10 segundos, incluido ese
mismo instante si coincide. Pausar congela ambos relojes; morir limpia el estado.

`boxing_rise` y `boxing_lower` enlazan la postura cuadrúpeda con la guardia.
`boxing_guard` coloca los puños de piedra junto a los lados de la cabeza,
con ángulo interior de codo de **110°** y antebrazos ascendentes; `boxing_walk`
permite perseguir manteniendo la guardia. El estado prevalece sobre sentarse
y comer; no elimina la percepción, el alcance ni los obstáculos existentes.
Un aturdimiento interrumpe el ataque y, al recuperarse, vuelve a la guardia si
quedan segundos del estado. Su reloj sigue avanzando durante el aturdimiento.

`hook` alterna los brazos: apertura, recorrido circular, acompañamiento del
torso y la cabeza, y vuelta a la guardia. Dura **1,2 segundos** frente al segundo
del golpe normal; el contacto ocurre en la mitad, a **0,6 segundos**, y entrega
**4 de daño base** al sistema existente de contacto/parry. No se repite el daño
dentro de un golpe. Si el estado termina antes del contacto, se cancela ese golpe.
Los ataques normales conservan 2 de daño y reciben un giro pequeño de torso y
cabeza más visible. Durante ambos ataques las raíces de cadera y las patas
permanecen estables; el torso tiene su transformación propia, con longitudes
óseas constantes y la misma piel continua. No cambian FBX, malla, pesos ni PNG.

El guardado conserva activación, temporizadores, brazo y variante de ataque.
Los archivos anteriores sin estos campos siguen cargando. Los cinco clips
nuevos están disponibles con etiquetas en español en la revisión F6.
`prototype_3d_enemy_boxing.gd` comprueba probabilidad, tiempos, daño, alternancia,
cancelación, codos, patas y separación de muestras de la piedra deformada frente
a la envolvente convexa de la cabeza. Se complementa con las comprobaciones
existentes de apoyos de piel, continuidad, combate, parry y guardado.


## Persecución y caída sobre la espalda (16 de octubre de 2026)

La persecución cuadrúpeda pasa de 0,26 a 0,36 s por ciclo, con mayor recorrido
anterior y posterior y ligera inclinación del torso. La persecución en guardia
pasa de 0,52 a 0,65 s y también amplía la zancada. No cambia la velocidad física,
la percepción ni los tiempos o el daño de los golpes.

`fall_motion.gd` comparte el orden de caída con el superviviente: apoyo de
rodillas, pérdida progresiva del equilibrio y apertura final de extremidades.
El enemigo conserva sus dos segundos de muerte y enlaza exactamente con un
cadáver inmóvil. Las entradas desde marcha, ataque, crochet y sentado capturan
la pose visible; los planos articulares se transportan para evitar inversiones.
La zona de interacción del botín abarca la nueva pose del cadáver.

La cola larga necesita una bisagra para apoyarse al lado del cuerpo sin hundirse
al reclinarse. `young_skin_weights.gd` redistribuye solo la influencia corporal
necesaria y añade el hueso 14, conservando los índices anteriores. El horneado
reproducible en `tools/enemy/bind_meshy.gd` incorpora esta corrección. El parche
`tools/enemy/bend_tail_weights.gd` conserva los buffers originales de geometría,
normales, tangentes, UV, índices y materiales; no cambia el FBX ni los PNG.
La pose neutra reproduce el modelo original. Pruebas de soporte, apertura,
interrupciones y continuidad: `tests/prototype_3d_falls.gd`.


## Validación de la versión reducida (16 de octubre de 2026)

Las pruebas de apoyo y caída adaptan el muestreo al número de vértices para
mantener unas 1000–2300 sondas, en vez de probar solo unas pocas al reducir la
malla. La regresión de boxeo comprueba ambos puños reales en todas las fases,
con la misma separación mínima respecto al casco convexo de la cabeza. La
transferencia conserva las animaciones publicadas, incluida la bisagra de cola
y la caída interrumpida desde marcha, golpe, crochet y postura sentada.
