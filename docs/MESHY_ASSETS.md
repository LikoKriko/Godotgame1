# Personaje y botella Meshy aportados por el usuario

El superviviente y la botella del prototipo 3D utilizan los FBX de las Releases `modelo_personaje3d` y `modelo_botella_3d`. Sus URL, SHA-256 de ZIP/FBX/PNG y rutas del original están en los respectivos `source.json`:

- `assets/characters/prototype_3d/meshy/`: superviviente optimizado, 20.878 triángulos originales, 22.132 vértices en Godot tras las separaciones de UV; altura uniforme de 64 unidades, convertida a 1,75 m por el jugador y el retrato.
- `assets/items/prototype_3d/bottle_meshy/`: botella de madera y cuerda, 883.250 triángulos originales y 472.027 vértices en Godot. El origen está en el cuello que sujeta la palma; la boca está en `(0, 2.8, 0)`. Se comparte el mismo recurso entre mano y suelo, con la misma escala física en mano y suelo (unos 28,4 cm de alto).

Las mallas visibles no se remallan ni diezman: se utilizan las versiones reducidas entregadas por el usuario. El pulido de piel del superviviente modifica solo normales/tangentes de sombreado y añade una máscara por vértice; conserva posiciones, UV e índices. Se conservan las cuatro texturas originales, con albedo, normales, metal y rugosidad, y muestreo nearest con mipmaps. Los FBX originales quedan en `entregables/.../source/`, con `.gdignore` para evitar su importación y exportación duplicadas. El juego carga recursos nativos comprimidos; no necesita Blender ni los ZIP al ejecutarse. No se ha añadido LOD: estos recursos conservan toda la densidad de los archivos recibidos.

## Ligadura y poses

El FBX del superviviente no contiene esqueleto ni clips. La versión reducida hereda la piel animada de 24 huesos de `4b5a50d`, mediante interpolación baricéntrica del triángulo donante más próximo. La ligadura histórica original se calculó por difusión de calor sobre una copia auxiliar; no se repite ese cálculo al sustituir la malla optimizada.

Se mantienen cuatro controles de tela y cuatro collares de volumen de codos y rodillas, con un máximo de cuatro influencias normalizadas por vértice. Los collares conservan volumen al flexionar; los controles de tela afectan únicamente al pantalón oscuro importado. El recurso es compartido e inmutable, mientras que cada actor y el retrato tienen su propio esqueleto y Skin.

La anatomía del prototipo 3D se ajusta a la nueva malla: caderas a 31 unidades, hombros a `(±6.2, 48, 1.3)` y muslo/tibia de 14,5 unidades. La matemática de animación compartida permanece como fuente de tiempos e IK; el runtime y los exportadores 2D se han retirado. La recogida baja el cuerpo hasta alcanzar el contacto; el deslizamiento adapta la pierna extendida; las herramientas recuperan alrededor del pecho y la armadura se refita con sus huecos de brazos. La armadura vigente procede del FBX Leafwoven Tunic del usuario y añade ligadura para acompañar torso, hombros y piernas; la adaptación procedural anterior fue retirada. Las manos mantienen los agarres y la botella se alinea con los labios del nuevo personaje.

La flecha tensada se orienta desde la posición real de la mano hasta el objetivo, conservando la precisión a corta y larga distancia tras el cambio de hombros.

La botella es opaca: vacío, medio y lleno comparten malla e icono. El contenido de cada botella sigue siendo un estado independiente de 0–500 ml; beber, rellenar, guardar y recoger conservan esa información. El horneado futuro de iconos utiliza el render del nuevo modelo.

## Regeneración

Usar Godot **4.7.2**. Los comandos se ejecutan desde la raíz del repositorio, con rutas temporales fuera de los assets exportables. Primero importar los PNG con el editor.

```bash
godot --headless --editor --path . --import
mkdir -p /tmp/survivor-transfer
git show 4b5a50d:assets/characters/prototype_3d/meshy/survivor_skin.res > /tmp/survivor-transfer/donor.res
godot --headless --path . --script tools/enemy/export_skin_transfer.gd -- /tmp/survivor-transfer/donor.res /tmp/survivor-transfer/skin
godot --headless --path . --script tools/meshy/export_survivor_transfer.gd -- /tmp/survivor-transfer/joints.json
blender -b -t 2 --python tools/meshy/transfer_survivor.py -- entregables/personajes/personaje1/source/Meshy_AI_Wild_Wanderer_1016142901_texture.fbx /tmp/survivor-transfer/rigged.glb /tmp/survivor-transfer/joints.json /tmp/survivor-transfer/skin
godot --headless --path . --script tools/meshy/bind_human.gd -- /tmp/survivor-transfer/rigged.glb transferred
cp /tmp/survivor-transfer/rigged.transfer.json assets/characters/prototype_3d/meshy/skin_transfer.json
# La armadura vigente se prepara con prepare_wearables.gd; ver la sección de equipo.
blender -b -t 2 --python tools/meshy/convert_source.py -- entregables/objetos/botella/source/bottle.fbx /tmp/bottle.glb
godot --headless --path . --script tools/meshy/bake_bottle.gd -- /tmp/bottle.glb
```

`rig_seeds.json` conserva la definición usada en la importación actual. Si cambian articulaciones o longitudes, regenerar tanto los pesos como el recurso nativo.

Para la comparación independiente, exportar también el FBX humano sin rig:

```bash
blender -b -t 2 --python tools/meshy/convert_source.py -- entregables/personajes/personaje1/source/Meshy_AI_Wild_Wanderer_1016142901_texture.fbx /tmp/human_original.glb
godot --headless --path . --script tools/meshy/verify_source.gd -- /tmp/human_original.glb res://assets/characters/prototype_3d/meshy/survivor_skin.res
godot --headless --path . --script tools/meshy/verify_source.gd -- /tmp/bottle.glb res://assets/items/prototype_3d/bottle_meshy/bottle.res
```

La comparación comprueba todos los índices de triángulos, posiciones, UV y normales. Tolera únicamente la precisión del empaquetado de Godot: error observado del personaje de 0,001042 unidades de autor (~0,029 mm a escala real), UV de 0,000022 y normal de 0,00519; en la botella, posiciones y UV coinciden exactamente y las normales difieren como máximo 0,00013.

Con servidor gráfico, generar vistas e iconos:

```bash
godot --path . --rendering-method gl_compatibility --script tools/meshy/review_survivor.gd -- /tmp/human_original.glb
godot --path . --rendering-method gl_compatibility --script tools/meshy/preview_bottle.gd
```

Vistas en `docs/previews/survivor_meshy_comparison.png`, `survivor_meshy_actions.png` y `bottle_meshy.png`. La primera lámina compara el FBX original sin rig con el actor real en reposo bajo la misma iluminación y las mismas cuatro cámaras.

## Validación

`tests/prototype_3d_meshy_assets.gd` comprueba procedencia, PNG originales, topología, materiales, recursos compartidos, independencia de poses y contacto de la botella. Sustituye las antiguas pruebas de proyección fotográfica de brazos, cuero cabelludo procedural y UV frontal/trasera; esos sistemas se han retirado del personaje 3D. `prototype_3d_human_deformation.gd` mantiene las comprobaciones de volumen de articulaciones, límites, longitudes y continuidad sobre la malla importada. Las otras pruebas de animación, agarres, contactos, recogida, inventario y persistencia se ejecutan sobre el nuevo modelo.

Cierre validado con Godot 4.7.2: importación, comparación independiente de ambos FBX, 145.005 comprobaciones de piel/articulaciones/continuidad, 8.588 de catálogo, 32.736 de marcha diagonal, contactos altos/bajos y armadura, recogida, botella reutilizable, arco, guardado y 17 comprobaciones de interfaz nativa X11. Las animaciones del enemigo vigente conservan sus 21.935 comprobaciones. La validación no incluye una sesión manual en Windows ni mediciones de rendimiento en el equipo del usuario.

## Adaptación de animaciones y corrección del tórax (15 de octubre de 2026)

El catálogo completo funciona sobre el rig Meshy vigente de `c0bcd4b`. La
postura de enlace se lee de `rig_seeds.json` mediante `Anatomy.bind_pose()`;
no depende del reposo animado ni de las correcciones de apoyo. Mantiene las
articulaciones originales al editar un movimiento.

La ligadura automática asignaba casi todo el peso de algunos vértices de la
espalda a los brazos. La primera corrección, `meshy_torso_v1`, se describe aquí
como antecedente; queda sustituida por la versión v2 indicada más abajo. En una acción, puntos de la zona escapular se alejaban
hasta 8,48 unidades del tórax. La primera versión limitaba esa influencia en
el pecho/espalda central y la transfería al pecho. Se corrigieron 42943 vértices, sin mover posiciones, normales,
tangentes, UV ni triángulos. Los buffers geométricos publicados se conservan
byte a byte; el recurso solo actualiza ligadura, límites de huesos y metadatos.
El FBX y los cuatro PNG permanecen intactos. La corrección se hornea una vez,
no se calcula al crear cada actor. Está integrada en `bind_human.gd` y también
puede aplicarse al recurso existente:

```sh
godot --headless --path . --script tools/meshy/correct_survivor_weights.gd
```

La nueva animación de deslizamiento separa pelvis y pecho para curvar el torso,
abre la rodilla recogida con espacio suficiente para la pantorrilla y mantiene
la otra pierna adelantada con flexión suave. Los brazos libres equilibran con
los codos bajos y las manos por delante; las armas conservan sus agarres. El
salto mezcla ambas transformaciones desde la pose realmente mostrada. No se
modifican duración, velocidad, frenada ni dirección de la mecánica existente.
Las referencias y la revisión con F6 están descritas en `PROTOTYPE_3D.md`.

Además, las suelas ruedan sobre la longitud real de los pies importados; la
muñeca se extiende ligeramente al recoger objetos bajos sin mover el contacto
seleccionado con E. Al morir, las rodillas conservan el plano de flexión sobre
el suelo y las manos dejan de seguir un objeto ya oculto. La espada mantiene
el brazo vacío de contrapeso y el combate agachado sigue apuntando a la mira.

`prototype_3d_meshy_motion.gd` comprueba todos los estados y familias, con la
recogida sin equipo como en el jugador real: geometría por hash, rig fijo,
estabilidad de la corrección, piel sobre suelo, zona escapular junto al tórax,
mano de recogida y liberación del equipo al morir. Las pruebas existentes de
catálogo, diagonales, volumen de piel, deslizamiento, contactos y combate
agachado se ejecutan también sobre este mismo recurso.


Los gestos de las cuatro familias de armas/herramientas se documentan en
`WEAPON_ANIMATIONS_3D.md`. Usan los mismos buffers de piel y geometría; la nueva
suelta del arco orienta el codo de tracción respecto a la cabeza y mantiene el
anclaje de la muñeca junto a la mandíbula.


## Reparación de hombros y volumen de brazos (16 de octubre de 2026)

La máscara rectangular v1 incluía vértices de la cara interior del brazo:
en la postura original ese brazo pasa por dentro de la anchura máxima del tórax.
Al elevarlo, la cara interior quedaba retenida por el pecho y la exterior
acompañaba al húmero, estirando la piel y produciendo brazos anchos. Además,
el recorte superior de la máscara dejaba parte del trapecio ligada al brazo.
El problema afectaba también a portar/equipar objetos y al puñetazo sin arma.

`human_skin_weights.gd`, perfil **`meshy_shoulders_v2`**, separa las superficies
del torso y los brazos según las secciones reales de la postura de enlace:
no usa la caja exterior del tórax para inmovilizar la cara interna del brazo.
La transición se abre gradualmente en el deltoides y termina antes del cuello.
Se conservan las proporciones relativas de húmero, antebrazo, mano y collar de
codo de la ligadura original; no se escala ningún brazo ni se cambian sus
longitudes. La transición inferior distingue las cuerdas de la cintura de los
brazos. Se conservan FBX, posiciones, normales, tangentes, UV, topología y PNG;
solo cambian pesos, límites de huesos y el metadato del perfil.

La importación reproducible normal (`convert_human.py` + `bind_human.gd`) aplica
v2 directamente sobre los pesos de calor originales. Para migrar desde v1 se
recuperan primero esos pesos, evitando propagar la pérdida de influencias del
brazo causada por v1. El recurso de `c0bcd4b` tiene exactamente la misma
geometría y contiene la ligadura anterior a esa máscara:

```sh
git show c0bcd4b:assets/characters/prototype_3d/meshy/survivor_skin.res > /tmp/day-zero-survivor-heat.res
godot --headless --path . --script tools/meshy/correct_survivor_weights.gd -- /tmp/day-zero-survivor-heat.res
```

La herramienta rechaza fuentes cuya geometría no coincida. Aplicar la
corrección de nuevo sobre v2 no modifica los pesos. La prueba de movimiento
mide ahora la distancia de la piel al eje de ambos húmeros y antebrazos y al
centro de los codos, además de los apoyos y el tórax. La selección de espalda
separa el brazo interior de las costillas e incorpora la parte alta del
trapecio que no cubría el test anterior. Se contrastan las transformaciones de
las sondas con las del `Skeleton3D` usado para dibujar.


## Afinado escapular v3 (16 de octubre de 2026)

El perfil **`meshy_shoulders_v3`** conserva la separación anatómica de
v2 y reduce la influencia del brazo en la superficie posterior alta, en la
transición entre trapecio y deltoides. El límite se aplica desde 43 unidades de
altura y se desvanece hacia la cara externa del hombro: no inmoviliza el anillo
completo del brazo a 40–42 unidades que causaba la expansión anterior.
La regresión comprueba ahora también la extensión del panel escapular, además
del grosor de húmeros, antebrazos y codos. Se hornea con la misma herramienta y
los mismos pesos de origen indicados arriba, conservando todos los buffers
geométricos y PNG. No se requiere remodelar ni cambiar proporciones.

## Equipo Meshy y roca — 16 de octubre de 2026

Se sustituyen las representaciones anteriores del hacha, pico, arco, armadura
de hojas y roca 3D por los modelos originales facilitados en Releases. Los
objetos en el suelo y los iconos de inventario/fabricación usan las mismas
formas importadas. No se cambian recetas, durabilidad, daño ni recompensas.
La roca se importó inicialmente como una familia de cuatro tamaños. Desde
el 17 de octubre, roca1 usa la versión optimizada y una sola altura de 1 m;
ver la actualización al final de este documento.

| Recurso | Release | Archivo válido | Triángulos originales | Altura de autor |
| --- | --- | --- | ---: | ---: |
| Hacha | `modelo_hacha3d` | `hacha1_3d.zip` | 3.104 | 19,2 |
| Pico | `modelo_pico3d` | `pico3dmodelo.zip` | 255.100 | 21,6 |
| Arco | `modelo_arco1_3d` | `arco1_3d.zip` | 5.215 | 28 |
| Armadura | `modelo_armadurahojas_3d` | `armadurahojas_3d.zip` | 10.425 | 29 |
| Roca1 | `modelo_roca1_3d` | `piedra1_3d.zip` | 5.163 | 1 m fijo en el mundo |

Los originales están en `entregables/modelos/*/source/`; los PNG byte a byte,
la malla base `model.res` y los hashes están en `assets/models/meshy/*/`.
`source.json` registra URL exacta, SHA-256 de ZIP/FBX/PNG y triángulos. El primer
ZIP del hacha era idéntico al del pico: se utiliza exclusivamente el ZIP
corregido por el usuario, SHA-256
`6e21f8f6942dc70733f1851e52d6650686458d2a5c110e489d135903e3da066e`.

Las mallas base conservan todos los vértices, normales, UV y triángulos; solo
reciben escala uniforme, rotación y traslación. El hacha se orienta por el
eje real del mango antes de medir su filo. `anchors.gd` exporta la punta
real del hacha/pico: las animaciones apuntan con ella al contacto. No se
reconstruyen herramientas mediante primitivas. Los dos mangos importados usan
4,95 unidades entre palmas tras la reducción al 60 % (antes 8,25); el solucionador recibe la separación de cada perfil
en vez de asumir la de las herramientas anteriores. Comprueba también el
volumen de la cabeza y usa el menor traslado hacia delante que permite el
golpe bajo (hasta 4,5 unidades), conservando longitudes y la reducción de
flexión de rodillas del departamento de animación. Los objetos caídos conservan
la escala física de las herramientas sostenidas.

El arco sostiene su propia cuerda original: `deformable.res` conserva la base
y añade tres controles de desplazamiento de cuerda y uno de flexión de ramas.
Los extremos siguen atados; el centro acompaña a la mano y al culatín. Los
nodos StringContact son anclajes lógicos sin geometría, no cuerdas duplicadas.
La flecha del juego sigue siendo independiente y conserva su trayectoria.

La armadura original permanece intacta en `model.res`. Su variante vestida
`worn.res` ajusta la cavidad al personaje delgado (X ×0,9, profundidad ×0,62
alrededor de Z=2,2), sin cambiar UV ni topología. Añade pesos continuos de
pelvis/pecho, hombros y muslos para que faldón y hombreras acompañen las
articulaciones. Cada actor y retrato tiene esqueleto y Skin propios; comparten
la geometría inmutable. Se retiran el recurso procedural de armadura anterior
y su herramienta de proyección. La colisión de roca sigue su nueva anchura;
las pequeñas conservan su volumen de selección sin bloquear los pies.

### Regeneración reproducible

Con Blender y Godot 4.7.2, desde la raíz del repositorio:

```sh
mkdir -p /tmp/day-zero-meshy
for id in axe pickaxe bow leaf_armor rock1; do
  blender -b --python tools/meshy/convert_source.py -- entregables/modelos/$id/source/*.fbx /tmp/day-zero-meshy/$id.glb
done
godot --headless --editor --path . --import
godot --headless --path . --script tools/meshy/bake_props.gd -- tools/meshy/props.json
godot --headless --path . --script tools/meshy/prepare_wearables.gd
for id in axe pickaxe bow leaf_armor rock1; do
  godot --headless --path . --script tools/meshy/verify_source.gd -- /tmp/day-zero-meshy/$id.glb res://assets/models/meshy/$id/model.res
done
godot --path . --script tools/meshy/review_props.gd -- /tmp/day-zero-meshy-review
python tools/meshy/compose_gear_review.py /tmp/day-zero-meshy-review docs/previews/meshy_gear.png
godot --path . --script tools/meshy/review_gear_game.gd
```

La comparación independiente con los cinco FBX da error máximo de posición y
UV cero; las diferencias de normales quedan por debajo de 0,00013, debidas
al empaquetado de Godot. Se comprueban también todos los índices de triángulos.
Las pruebas de equipo verifican cuerda dibujada, filo sobre vértice real, piel
de armadura independiente y colisión de roca. Las capturas
`previews/meshy_gear.png` y `previews/meshy_gear_in_game.png` muestran el resultado
real de Godot. No se ha medido rendimiento en el ordenador del usuario; roca
y pico conservan las mallas densas originales.


Validación final con las animaciones de `8b341ec`: 50.995 comprobaciones en
once suites (armas, equipar/desequipar, combate agachado, contactos, recogida,
materiales, geometría y objetos físicos). La nueva prueba de equipo comprueba
también todos los vértices del hacha y pico frente al interior del tórax y
cráneo en seis fases completas del golpe, además del recorrido de sus ejes.

La integración final conserva también `301080b` del departamento de hitboxes:
la roca incorpora un Area3D de selección/impacto 15 cm mayor por lado que la
caja física. La caja física sigue la malla; la tolerancia no bloquea el paso.
Las siete suites de colisiones, separación, recursos, equipo, retícula,
geometría real y recogida pasan después de esta integración.


## Superviviente optimizado y pulido de piel — 16 de octubre de 2026

Se aplica el ZIP nuevo `personaje1_3d.zip` de la Release `modelo_personaje3d`,
SHA-256 `41d337bca5ab900bac67da6e9ede430d48d0bbc12964cd5fbcaaa1d6e4f4efb3`.
El FBX `1016142901` original y los cinco PNG están conservados byte a byte;
`source.json` registra procedencia, hashes y la huella de geometría final.
El FBX denso `survivor.fbx` queda solo como fuente histórica.

La malla pasa de 491218 a **20878 triángulos** (95,75 % menos) y de 263748 a
**22132 vértices de ejecución**. El recurso de geometría/pesos ocupa alrededor
de 0,63 MB, frente a 11,91 MB. Los PNG nuevos pesan más que los anteriores:
esto no mide memoria total ni FPS en el equipo del usuario. Se mantiene la
altura de 1,75 m, la anatomía, todos los clips, armas y la armadura existente.

La transferencia conserva los 24 huesos, cuatro controles de tela y cuatro
collares de volumen de codos/rodillas. `skin_transfer.json` identifica el
donante exacto SHA-256
`7c48018fd35027d7176679237ca96ad46100c8bd00b749adcd8b6f4e7e0ad56c`.
Distancia máxima a la superficie donante: 0,01933 unidades de autoría;
RMS: 0,00603. Se conservan las correcciones escapulares v3.

El pulido pedido en brazos, pectoral y espalda usa `skin_surface.gd` y
`survivor_skin.gdshader`. Suaviza normales de esquinas coincidentes de piel
sin soldar ni mover geometría, regenera tangentes y reduce a 0,15 la intensidad
del mapa normal sobre piel. Una máscara en el alfa del color de vértice
transiciona gradualmente en cintura y cuello; pelo, cara y ropa conservan
sus mapas completos. El material sigue usando las cuatro texturas originales,
las UV recibidas y muestreo nearest, en una sola superficie y pasada opaca.
El material original permanece como metadato para comparación y reproducción.

La comparación independiente con el FBX confirma posiciones, UV e índices
completos, con errores máximos de empaquetado de 0,00104 unidades y 0,000022
en UV. Las normales fuera de la zona pulida difieren como máximo 0,00129;
las de la piel se modifican deliberadamente. No se trata de identidad de
normales en esas zonas. La comprobación de geometría durante animaciones
usa la huella final declarada en el manifiesto y conserva los mismos límites
de apoyos, volumen y continuidad.

Capturas actuales: `previews/survivor_optimized_comparison.png`,
`previews/survivor_optimized_actions.png`, `previews/survivor_optimized_skin.png`
y `previews/survivor_meshy_in_game.png`. Las capturas anteriores sin el nombre
optimized son históricas cuando muestran la malla densa.


Para regenerar las capturas optimizadas:

```sh
mkdir -p /tmp/survivor-review
godot --path . --script tools/meshy/review_survivor.gd -- /tmp/human_original.glb /tmp/survivor-review
cp /tmp/survivor-review/survivor_meshy_comparison.png docs/previews/survivor_optimized_comparison.png
cp /tmp/survivor-review/survivor_meshy_actions.png docs/previews/survivor_optimized_actions.png
godot --path . --script tools/meshy/review_skin.gd -- /tmp/human_original.glb res://docs/previews/survivor_optimized_skin.png
godot --path . --script tools/meshy/review_game.gd
```

Validación de esta entrega: **336475 comprobaciones en 20 suites**, incluyendo
los 31 estados de animación y ocho familias de equipo, piel/volumen, soportes,
continuidad, giro retardado, puñetazos alternos, saltos/deslizamiento, combate
agachado, armas, arco, recogida, armadura, guardado y 17 comprobaciones de
interfaz nativa X11 con el retrato. No sustituye una prueba en el equipo del
usuario ni una medición de FPS.


## Hacha y pico al 60 % — 16 de octubre de 2026

Por petición del usuario, ambos modelos se reducen **un 40 % en los tres ejes**:
la altura del hacha pasa de 32 a 19,2 unidades de autoría (0,525 m) y la del
pico de 36 a 21,6 (0,590625 m). El mundo y los objetos soltados comparten
las mallas redimensionadas; no hay una escala distinta al soltarlas. Las UV,
triángulos, normales y PNG originales permanecen iguales.

`props.json` mantiene la calibración original de cada fuente y aplica
`model_scale: 0.6` al final, antes de medir sus anclajes. `grip_bottom: -4`
coloca el extremo inferior a la distancia que cubren los dedos de la mano:
se ajusta el punto de agarre, sin alterar el tamaño obtenido. `anchors.gd`
exporta punta real, escala, apoyo de segunda mano y límites del mango. Los
perfiles usan esos valores, sin volver a aplicar la escala. La separación
de palmas pasa de 8,25 a **4,95 unidades** (unos 13,5 cm).

La preparación desplaza el mango hacia delante para dejar libre la cabeza.
Los contactos bajos añaden una inclinación continua del torso alrededor de
la cadera, hasta 0,18 radianes tras el afinado de animación, y el menor traslado de apoyo
resuelto. Para contactos muy bajos se permite bajar seis unidades y avanzar
hasta diez, con los pies plantados. Los pies siguen plantados, las rodillas conservan
su corrección anterior y los huesos mantienen su longitud. Se conservan las
fases de preparación, golpe, extracción y recuperación y los enlaces de
equipar/desequipar. El solucionador y sus pruebas toman los límites reales
del mango reducido para no tratar como sólido un mango imaginario más largo.
No cambian daño, desgaste ni reglas de alcance del sistema de combate.

Las pruebas comprueban además la altura exacta solicitada, el apoyo de mano,
la punta sobre un vértice real, dimensiones del objeto soltado, las manos
durante equipamiento/locomoción y la malla completa frente a torso y cabeza.
La comparación independiente con ambos FBX conserva todos los índices,
posiciones transformadas, UV y normales dentro de precisión nativa.
Captura actual: `previews/tools_reduced_grips.png`.


## Pliegue axilar v4 (16 de octubre de 2026)

El perfil vigente es `meshy_shoulders_v4_axilla`. Conserva las correcciones
escapulares v3 y amplía solo el gradiente de pesos de la unión espalda/brazo
entre y=41,5–47, evitando que aristas muy cortas del sobaco sigan transformaciones
radicalmente distintas al extender el jab. Cambian pesos de 612 vértices de
la malla transferida de 22132 vértices/20878 triángulos y 24 huesos. Se conservan
los buffers originales de posiciones, normales/tangentes, UV, índices y colores,
así como material `skin_seams_v1`, FBX y PNG. No volver al horneado automático.
`human_skin_weights.gd` aplica la corrección reproducible en `bind_human.gd`;
se conservan los anillos de codos/antebrazos y la corrección es idempotente.

En el jab de ambos lados, 65 muestras por golpe, el peor cociente entre longitud
de arista deformada y original baja de 8,25 a 3,52 en el sobaco. Sigue existiendo
estiramiento propio de una piel de cuatro influencias, pero se elimina el salto
local de pesos que creaba el pliegue excesivo. Las pruebas cubren también
volumen, continuidad, apoyo de piel real y fidelidad a la fuente importada.


## Roca1 optimizada y una sola altura — 17 de octubre de 2026

Fuente vigente: `modelo_roca1_3d/piedra1_3d.zip`, FBX
`Meshy_AI_Wild_Wanderer_1016215008_texture.fbx`. Tiene **2526 vértices de
origen y 5163 triángulos**, frente a los 755810 anteriores (**99,32 % menos**).
La malla nativa baja de 15784003 a 166826 bytes; no se presenta esta reducción
como una medición de FPS o de la memoria total de las texturas.

Se conservan las formas, proporciones, normales, UV y los cinco PNG del archivo
entregado. Los cuatro mapas separados se asignan al material; el combinado
metálico/rugosidad se conserva sin duplicar su aplicación. Procedencia y hashes:
`assets/models/meshy/rock1/source.json`. El FBX anterior queda únicamente como
fuente histórica y ya no se usa en el juego.

**Roca1 mide un metro de alto en el mundo**, con anchura 2,843731 m y profundidad
2,905249 m. Se retiran los escalados de 0,28/0,7/1,4/2,4 m: `rock.configure()`
no recibe un índice de tamaño, y tanto `world_layout` como `stream_layout`
emiten altura 1,0. `world_content` no aplica una segunda escala. Las otras
familias de piedra quedan pendientes de sus propios modelos.

Se conservan las posiciones e identificadores de recursos, sus puntos de
resistencia, cantidades y estado de agotamiento para no invalidar los guardados.
Los afloramientos de un metro tienen colisión y se minan; ya no son variantes
pequeñas recogibles a mano. El material de inventario `piedra` y sus piezas
soltadas siguen representando el recurso extraído, usando la geometría nueva.
Se actualizan ambos iconos y se conserva la tolerancia de impacto de 15 cm.

[Vista junto al superviviente de 1,75 m](previews/rock1_optimized.png).

Regeneración: exportar el FBX con `convert_source.py`; usar la entrada `rock1`
de `tools/meshy/props.json` con la ruta GLB exportada y ejecutar `bake_props.gd`.
`verify_prop.gd -- res://assets/models/meshy/rock1/model.res /ruta/rock1.glb`
compara cada esquina de los 5163 triángulos y sus UV contra la fuente: error
cero observado. `review_rock.gd` genera la captura y los dos iconos.
`prototype_3d_rock1.gd` comprueba la única altura en el claro inicial y en
36 chunks de extensión, la colisión y el agotamiento por minería.
