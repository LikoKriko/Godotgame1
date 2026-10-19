# Modelos y materiales vigentes

Los modelos proceden de los FBX y GLB aportados por el usuario. Conservar geometría,
proporciones, UV, PNG y anclajes de sus fuentes. Los recursos que carga el juego
están en `assets/`; los originales se organizan en `entregables/`.

## Personajes y criaturas

| Modelo | Altura en partida | Triángulos | Esqueleto |
| --- | --- | --- | --- |
| Superviviente Rugged Castaway | 1,75 m | 32569 | 24 huesos, con controles de ropa y volumen articular |
| Enemigo1 Mossclaw Boar | 0,875 m | 4036, sin apertura facial | 25 huesos originales SmartRigArmature |
| Enemigo3 Sunny Sprout | 0,9 m | 13582 | 35 huesos originales |

El superviviente combina el cuerpo y rig de
`Personaje1_Renewed_3d/psnj1_3d_rigged.fbx` con la cabeza aprobada de Rugged
Castaway. La escena nativa es `assets/characters/prototype_3d/composite/model.scn`;
su manifiesto y parámetros del rig están junto a ella. El albedo del cuerpo
procede del FBX, y los mapas de cabeza se conservan en `meshy/`. Las fuentes y la
instantánea de cabeza están en `entregables/personajes/personaje1/source/`.
Véase [ANIMATION_SYSTEMS.md](ANIMATION_SYSTEMS.md) para ensamblado y regeneración.
Los recursos survivor_skin.res y survivor_axilla.res de meshy/ se conservan
como donantes de autoría; no dibujan el cuerpo actual.

Enemigo1 usa `Meshy_AI_Character_output.glb`, de la Release `modelo1_rig`.
Su fuente está en `entregables/enemigos/enemigo1/source/`. La escena nativa,
la malla facial, las animaciones y el manifiesto están en
`assets/enemies/first/rig/`; las texturas originales se comparten desde `meshy/`.

Enemigo3 usa `entregables/enemigos/enemigo3/modelo_enemigo3.fbx` y conserva
su esqueleto propio. La escena nativa está en
`assets/enemies/third/sprout/model.scn`.

El superviviente conserva el rig en T del FBX nuevo, con la cabeza aprobada
ligada a sus huesos de cuello y cráneo. Enemigo1 y enemigo3
conservan las jerarquías de sus rigs originales. Enemigo1 interpola los pesos
existentes sobre una superficie reducida con cabeza, plantas y límites
protegidos; conserva intacta la fuente de 7340 triángulos.
Los manifiestos `source.json`, `rig_seeds.json` y `skin_transfer.json` junto a
los recursos contienen medidas, procedencia y datos necesarios de conversión.

## Objetos

Hacha, pico, arco, armadura de hojas y roca1 están en
`assets/models/meshy/{axe,pickaxe,bow,leaf_armor,rock1}/`.
La botella está en `assets/items/prototype_3d/bottle_meshy/`.
Cada familia conserva su `source.json` y las texturas originales.

Hacha y pico usan `model_scale: 0.6`, agarre inferior −4 y separación de palmas
de 4,95 unidades de autoría. Usar los anclajes generados sin duplicar esa escala.
El arco conserva la cuerda original deformable. La armadura de hojas acompaña
el torso y las articulaciones, con huecos para brazos y cuello.

Roca1 usa `Meshy_AI_Mossy_Stone_Outcrop_1019090447_texture.fbx`, de
`modelo_roca1_3d/roca1.zip`: 11931 triángulos y **un metro de alto** en
todas las instancias del mundo. Se extrae con pico. No aplicar variantes de
escala a esta familia; otras dimensiones requieren sus propios modelos.

## Materiales y preparación

Se mantienen los PNG originales. Enemigo1 usa un normal tangente derivado
de 2048 × 2048 en `rig/surface_normal.png`, que proyecta el relieve y el normal
del modelo fuente sobre la superficie reducida; comparte los albedos y mapas
de rugosidad y metal originales. El muestreo utiliza
nearest y mipmaps en los materiales existentes. El superviviente usa filtrado
lineal anisotrópico con mipmaps, acorde al acabado pintado vigente. El cuerpo visible usa el albedo del FBX nuevo y rugosidad de 0,85, sin metal.
El perfil `skin_seams_v1` se conserva en los donantes de autoría;
`face_materials_v1` controla por separado la piel facial (0,4),
el pelo y la barba. Corrige las manchas de proyección de color de piel dentro
del pelo, conserva el marrón original y usa rugosidad mínima de 0,85 y metal
nulo en esas zonas. El material se dibuja por ambas caras para que las láminas
abiertas de los mechones no dejen huecos al mirarlas desde atrás. La máscara de pelo se hornea por vecindad geométrica, con
protección de frente, orejas, ojos y boca; la piel facial añade un normal fino
`face_detail_normal.png` con intensidad de 0,055. La cicatriz y los rasgos
faciales mantienen sus UV y albedo originales. Posiciones, índices y PNG de
la entrega permanecen intactos; el detalle facial es un recurso adicional.

La preparación vigente del superviviente usa `build_composite.py` y
`bake_composite.gd`, conservando los pesos originales del cuerpo y creando
únicamente la ligadura de cabeza/cuello. `transfer_survivor.py` y `bind_human.gd`
se conservan para los donantes antiguos; no se usan para el cuerpo en T actual.

Las herramientas de preparación están en `tools/meshy/`, `tools/enemy/`,
`tools/enemy1/` y `tools/enemy3/`. La configuración de objetos es `tools/meshy/props.json`.
El superviviente usa composición con rig nativo; enemigo1 utiliza `import_rig.gd`
y `bake_motion.gd` en `tools/enemy1/`; la superficie optimizada se deriva con
`optimize_surface.py` y `bake_surface.gd`, sin regenerar las animaciones.
La armadura se prepara con `prepare_wearables.gd`.
Usar las fuentes y manifiestos vigentes al regenerar recursos.

El superviviente muestra `meshy/survivor_axilla.res`, una derivación local de
`survivor_skin.res` con soporte adicional del pliegue axilar y transición suave
de pesos. El recurso fuente conserva su geometría y UV; el manifiesto distingue
la superficie de ejecución. Al actualizar el modelo, regenerar el soporte y
los apoyos según [ANIMATION_SYSTEMS.md](ANIMATION_SYSTEMS.md).
