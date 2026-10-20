# Armas y herramientas

## Acciones

| Familia | Comportamiento |
| --- | --- |
| Hacha | Carga con agarre a dos manos, impacto y recuperación cerca del cuerpo |
| Pico | Preparación y arco propios, con inclinación de pecho para golpes bajos |
| Espada | Corte guiado por la mira; brazo libre como contrapeso; manos alternas para puños sin arma |
| Arco | Tensado de 0,5 s, flecha y cuerda alineadas con la mano; suelta y seguimiento visual de 0,24 s |

Hacha, pico y espada tienen preparación, contacto, continuación y recuperación.
El contacto ocurre en la fase 0,5. La espada tarda 1,0125 s por acción; hacha
y pico, 0,75 s. Los agarres usan los anclajes reales de cada herramienta y
respetan las longitudes de brazos, alcance y envolvente del tórax.

El objetivo de los golpes queda fijado al comenzar. El arco sigue la mira
hasta soltar la flecha. Su seguimiento visual puede sustituirse al iniciar
otra acción; no consume otra flecha ni añade desgaste.

## Sujeción y equipo

Las guardias y el porte se adaptan a cada familia y a caminar, correr o
agacharse. Equipar y desequipar enlazan con esas poses. El pico utiliza una
transición de 0,5 s; las otras familias, de 0,42 s.

Hacha y pico usan `model_scale: 0.6`. Los agarres generados están en
`assets/models/meshy/{axe,pickaxe}/anchors.gd`; sus palmas se separan 4,95
unidades de autoría. El ajuste inferior del agarre es −4. No aplicar una
segunda escala al sujetar o tirar el objeto.

El cálculo de contacto reutiliza soluciones y candidatos dentro de una caché
acotada. Las trayectorias visibles mantienen la misma anatomía, agarres y mira.
Los controladores están en `weapon_motion.gd`, `tool_aim.gd`, `held_profiles.gd`
y `survivor_animation.gd`, dentro de `scripts/prototype_3d/`.

## Orientación y oclusión

Las herramientas no deben dibujarse a través del torso o la cabeza al mirar hacia arriba o hacia los lados. Los agarres y los brazos deben seguir visibles donde corresponda. Validar la oclusión en los fotogramas completos exportados, no únicamente en el rig antiguo.

Orientar las herramientas a partir de sus puntos reales de agarre y de su plano
de corte, de forma continua durante reposo, preparación, impacto y recuperación.
No solucionar una orientación incorrecta con inversiones aisladas de frames o
direcciones.

En el runtime 3D la estela sigue el anclaje `tip_socket`/`ObjectTip` del modelo
y `combat_effects.track_tip`, llamado desde `player.gd`; conservar su trayectoria
y el plano de corte. Las instrucciones de punta exportada, atlas y fotogramas
se conservan con alcance explícito en
[SHARED_RESOURCES.md](SHARED_RESOURCES.md#referencias-de-exportación-2d-verificar-vigencia).
Validar también las poses completas frontal, lateral y vertical, con armadura.
Las cuatro fases del golpe y los anclajes no autorizan separar brazos del cuerpo.
