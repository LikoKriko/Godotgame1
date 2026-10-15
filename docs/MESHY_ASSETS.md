# Personaje y botella Meshy aportados por el usuario

El superviviente y la botella del prototipo 3D utilizan los FBX de las Releases `modelo_personaje3d` y `modelo_botella_3d`. Sus URL, SHA-256 de ZIP/FBX/PNG y rutas del original están en los respectivos `source.json`:

- `assets/characters/prototype_3d/meshy/`: superviviente, 491.218 triángulos originales, 263.748 vértices en Godot tras las separaciones de UV; altura uniforme de 64 unidades, convertida a 1,75 m por el jugador y el retrato.
- `assets/items/prototype_3d/bottle_meshy/`: botella de madera y cuerda, 883.250 triángulos originales y 472.027 vértices en Godot. El origen está en el cuello que sujeta la palma; la boca está en `(0, 2.8, 0)`. Se comparte el mismo recurso entre mano y suelo, con la misma escala física en mano y suelo (unos 28,4 cm de alto).

Las mallas visibles no se remallan ni diezman. Se conservan las cuatro texturas originales, con albedo, normales, metal y rugosidad, y muestreo nearest con mipmaps. Los FBX originales quedan en `entregables/.../source/`, con `.gdignore` para evitar su importación y exportación duplicadas. El juego carga recursos nativos comprimidos; no necesita Blender ni los ZIP al ejecutarse. No se ha añadido LOD: estos recursos conservan toda la densidad de los archivos recibidos.

## Ligadura y poses

El FBX del superviviente no contiene esqueleto ni clips. Los 16 huesos principales usan los nombres y cadenas del rig compartido. La ligadura automática se calcula sobre una copia auxiliar voxelizada de 0,012 unidades Blender: evita las singularidades de los detalles desconectados del FBX. Solo se transfieren los pesos a la malla original mediante interpolación de la superficie más cercana; la copia auxiliar se elimina antes de exportar.

Se mantienen cuatro controles de tela y cuatro collares de volumen de codos y rodillas, con un máximo de cuatro influencias normalizadas por vértice. Los collares conservan volumen al flexionar; los controles de tela afectan únicamente al pantalón oscuro importado. El recurso es compartido e inmutable, mientras que cada actor y el retrato tienen su propio esqueleto y Skin.

La anatomía del prototipo 3D se ajusta a la nueva malla: caderas a 31 unidades, hombros a `(±6.2, 48, 1.3)` y muslo/tibia de 14,5 unidades. La plantilla de animación común 2D permanece como fuente de tiempos e IK. La recogida baja el cuerpo hasta alcanzar el contacto; el deslizamiento adapta la pierna extendida; las herramientas recuperan alrededor del pecho y la armadura se refita con sus huecos de brazos. La armadura se hornea alrededor de la superficie real del torso importado, conservando los huecos de brazos y evitando hundir las hojas en la piel. Las manos mantienen los agarres y la botella se alinea con los labios del nuevo personaje.

La flecha tensada se orienta desde la posición real de la mano hasta el objetivo, conservando la precisión a corta y larga distancia tras el cambio de hombros.

La botella es opaca: vacío, medio y lleno comparten malla e icono. El contenido de cada botella sigue siendo un estado independiente de 0–500 ml; beber, rellenar, guardar y recoger conservan esa información. El horneado futuro de iconos utiliza el render del nuevo modelo.

## Regeneración

Usar Godot **4.7.2**. Los comandos se ejecutan desde la raíz del repositorio, con rutas temporales fuera de los assets exportables. Primero importar los PNG con el editor.

```bash
godot --headless --editor --path . --import
godot --headless --path . --script tools/meshy/export_human_bind.gd -- /tmp/human_joints.json
blender -b -t 2 --python tools/meshy/convert_human.py -- entregables/personajes/personaje1/source/survivor.fbx /tmp/human_skinned.glb /tmp/human_joints.json
godot --headless --path . --script tools/meshy/bind_human.gd -- /tmp/human_skinned.glb
godot --headless --path . --script tools/meshy/fit_armor.gd
blender -b -t 2 --python tools/meshy/convert_source.py -- entregables/objetos/botella/source/bottle.fbx /tmp/bottle.glb
godot --headless --path . --script tools/meshy/bake_bottle.gd -- /tmp/bottle.glb
```

`rig_seeds.json` conserva la definición usada en la importación actual. Si cambian articulaciones o longitudes, regenerar tanto los pesos como el recurso nativo.

Para la comparación independiente, exportar también el FBX humano sin rig:

```bash
blender -b -t 2 --python tools/meshy/convert_source.py -- entregables/personajes/personaje1/source/survivor.fbx /tmp/human_original.glb
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
