# Modelos y materiales vigentes

Los modelos proceden de los FBX y GLB aportados por el usuario. Conservar geometría,
proporciones, UV, PNG y anclajes de sus fuentes. Los recursos que carga el juego
están en `assets/`; los originales se organizan en `entregables/`.

## Personajes y criaturas

| Modelo | Altura en partida | Triángulos | Esqueleto |
| --- | --- | --- | --- |
| Superviviente Wild Wanderer | 1,75 m | 20878 | 24 huesos, con controles de ropa y volumen articular |
| Enemigo1 Mossclaw Boar | 0,875 m | 7340 | 25 huesos originales SmartRigArmature |
| Enemigo3 Sunny Sprout | 0,9 m | 13582 | 35 huesos originales |

El superviviente usa `Meshy_AI_Wild_Wanderer_1016142901_texture.fbx`, de
`modelo_personaje3d/personaje1_3d.zip`. El recurso nativo es
`assets/characters/prototype_3d/meshy/survivor_skin.res`.

Enemigo1 usa `Meshy_AI_Character_output.glb`, de la Release `modelo1_rig`.
Su fuente está en `entregables/enemigos/enemigo1/source/`. La escena nativa,
la malla facial, las animaciones y el manifiesto están en
`assets/enemies/first/rig/`; las texturas originales se comparten desde `meshy/`.

Enemigo3 usa `entregables/enemigos/enemigo3/modelo_enemigo3.fbx` y conserva
su esqueleto propio. La escena nativa está en
`assets/enemies/third/sprout/model.scn`.

El superviviente tiene una ligadura añadida para el juego. Enemigo1 y enemigo3
conservan las jerarquías y pesos de sus rigs originales.
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

Roca1 usa `Meshy_AI_Wild_Wanderer_1016215008_texture.fbx`, de
`modelo_roca1_3d/piedra1_3d.zip`: 5163 triángulos y **un metro de alto** en
todas las instancias del mundo. Se extrae con pico. No aplicar variantes de
escala a esta familia; otras dimensiones requieren sus propios modelos.

## Materiales y preparación

Se mantienen albedo, normal, rugosidad y metal originales. El muestreo utiliza
nearest y mipmaps. El perfil `skin_seams_v1` del superviviente suaviza normales
coincidentes de piel y atenúa su mapa normal mediante máscara por vértice;
no altera posiciones, UV, índices ni PNG. Pelo y ropa conservan su detalle.

Las herramientas de preparación están en `tools/meshy/`, `tools/enemy/`,
`tools/enemy1/` y `tools/enemy3/`. La configuración de objetos es `tools/meshy/props.json`.
El superviviente usa transferencia de piel con `transfer_survivor.py` y
`bind_human.gd` en modo `transferred`; enemigo1 utiliza `import_rig.gd`
y `bake_motion.gd` en `tools/enemy1/`. La armadura se prepara con `prepare_wearables.gd`.
Usar las fuentes y manifiestos vigentes al regenerar recursos.
