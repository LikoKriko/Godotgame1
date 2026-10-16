# Zona de animaciones

El usuario ha reservado este chat para modelos, esqueletos, pesos y deformación,
animaciones de personajes/criaturas, vestimenta animada, agarres y coordinación
del cuerpo con las herramientas. Las futuras tareas de otros sistemas se
repartirán entre otros chats; esta nota no bloquea archivos ni reserva toda la
rama a un único hilo.

El superviviente y la botella vigentes son los FBX Meshy aportados por el usuario,
no las antiguas superficies procedurales. Ver `docs/MESHY_ASSETS.md` y
`assets/characters/prototype_3d/meshy/rig_seeds.json`: se conservan 24 controles,
con hombros a `(±6.2,48,1.3)`, muslo/tibia de 14,5 unidades y altura de 1,75 m.
Si se cambian los anclajes de reposo, regenerar pesos y recurso nativo; cada
actor conserva su propio esqueleto y comparte únicamente la malla inmutable.

Puntos principales: `survivor_model.gd`, `survivor_anatomy.gd`,
`meshy_body_profile.gd`, `humanoid_rig.gd`, `human_kinematics.gd`,
`survivor_animation.gd`, `leaf_armor.gd`, modelos/rigs del joven y escenas de
revisión en `scripts/prototype_3d/` y `scenes/prototype_3d/`. Los materiales de
piel y las pruebas de deformación acompañan esos cambios.

`player.gd`, `world.gd` y `shoulder_camera.gd` son integración compartida con
movimiento, cámara y mecánicas. Evitar reescribirlos ampliamente por un cambio
de pose. La corrección de convergencia de mira ya estaba autorizada antes de
esta división y se cierra como última tarea compartida de esta tanda.

La integración de cintura, pinturas y ropa está publicada en `979623f`, sobre
`prototype/third-person-3d`. Revisar los commits remotos y cambios locales antes
de integrar trabajo de otro chat; conservarlos y no sobrescribir su historial.
`main` mantiene la versión 2D.

## Coordinación natural y contacto de acciones

El catálogo 3D conserva las longitudes anatómicas, zancada/cadencia y los tiempos
existentes de combate, equipamiento y consumo. Pelvis y pecho tienen ahora
transformaciones coordinadas separadas; `body` sigue representando el torso que
acompaña la armadura y `pelvis` controla la raíz y las caderas. El rig vuelve a
resolver los miembros después de mezclar poses. El avance de fase toma la
velocidad conseguida y la entrada de movimiento tiene una transición visual.
Se añaden transferencia de peso, equilibrio en salto, preparación de puño,
trayectorias diferenciadas de herramientas, flexión para contactos bajos,
arco al equipar y seguimiento de
la mirada durante recogida. Agacharse añade bisagra de cadera y la caída separa
el apoyo de manos/pies del descenso del torso para respetar el suelo. El tensado del arco es continuo, manteniendo sus
0,5 s y las reglas de munición/desgaste.

`shoulder_camera.action_sample` usa el rayo central y dos anillos de doce rayos
para seleccionar superficies visibles dentro de un radio del 1,8% de la altura
del viewport (unos 19 px a 1080p). La superficie central válida tiene prioridad;
la ayuda solo interviene al iniciar acciones de corto alcance o pulsar E.
El arco conserva la mira central exacta. Cada golpe fija juntos collider y
punto al comenzar, y vuelve a comprobar presencia, alcance y obstáculos al
impactar. No se amplía la longitud de brazos ni herramientas.

E inicia una recogida dirigida de 0,72 s, con transferencia al inventario a
mitad del gesto (0,36 s). El objeto permanece visible hasta ese instante.
La pose adapta flexión y colocación escalonada de pies a la altura/distancia;
la mano alcanza el contacto fijado. Al caminar se acorta la zancada durante
la flexión para sostener ese alcance. Durante la recogida se conserva la reducción
de velocidad y su recuperación posterior de 0,5 s. Al contacto se comprueban
otra vez existencia, alcance, obstáculos, manos libres y espacio: un fallo
conserva el objeto. No se pueden duplicar recogidas ni cambiar de equipo a
mitad de ese gesto; los consumos conservan su circuito independiente.

F6 en `animation_review.tscn` permite pausar, recorrer manualmente la fase y
variar altura/distancia de contacto en metros. El punto dorado marca el objetivo
físico de revisión. `tests/prototype_3d_natural_actions.gd` cubre la tolerancia
en tres resoluciones, prioridad central, oclusión, anatomía, apoyos, mano real
en el contacto, transferencia diferida, repetición, alejamiento y mochila llena.
Las pruebas no acreditan naturalidad perfecta ni equivalencia con mocap.


## Trayectoria de marcha diagonal

`leg_frame` orienta juntos los carriles de apoyo, los polos de rodilla y los
pies al caminar diagonalmente. La pelvis acompaña con medio giro y el torso
conserva la orientación de apuntado. La separación se limita perpendicularmente
a esos carriles, evitando cortar la mitad interior de la zancada con el eje X
frontal y convertir el paso en un abanico lateral. La amplitud se escala desde
la posición neutral de cada carril; la orientación se mezcla entre fotogramas.
Caminar hacia atrás mantiene el pie orientado hacia delante en su diagonal.
La recogida andando conserva su colocación específica. No cambian velocidad,
cadencia ni longitudes anatómicas. `prototype_3d_diagonal_gait.gd` comprueba las
trayectorias completas en las cuatro diagonales, pies renderizados, huesos y
agarres para las ocho familias y caminar/correr/agachado.


## Enemigo1 Meshy

Las animaciones actuales usan el Meshy Mossclaw Boar de `d551f4c`, sin recuperar
la reconstrucción procedural anterior. Mantener `young_pose.bind_pose()` fijo
y separado del catálogo de acciones: lo usan el esqueleto y el exportador de
ligadura. La revisión de F6 permite pausar y recorrer la fase del joven.
Ver `docs/YOUNG_3D.md` y `tests/prototype_3d_young_motion.gd`.


## Superviviente Meshy: espalda y deslizamiento

La espalda y el trapecio siguen el tórax; la cara interior del brazo sigue al
brazo. No inmovilizarla con una máscara rectangular de la espalda: produce
ensanchamientos al levantar el húmero. El perfil vigente es
`meshy_shoulders_v3`, descrito en `docs/MESHY_ASSETS.md`. La corrección reproducible está en
`human_skin_weights.gd` y `tools/meshy/correct_survivor_weights.gd`, conservando
la geometría importada. La postura de enlace usa `Anatomy.bind_pose()`.
El deslizamiento nuevo curva el pecho respecto a la pelvis y mantiene la
rodilla recogida con espacio para la pantorrilla. Revisar frontal, lateral y
espalda en F6, incluyendo el salto desde distintas fases y los objetos equipados.
Ver `docs/MESHY_ASSETS.md` y `tests/prototype_3d_meshy_motion.gd`.


## Gestos de armas y herramientas

`weapon_motion.gd` separa las trayectorias de hacha, pico, espada y arco de la
anatomía y de las mecánicas. Para referencias, fases y revisión con F6, consultar
`docs/WEAPON_ANIMATIONS_3D.md`. El arco incorpora `bow_release`, un seguimiento
visual que no añade espera para volver a disparar. Conservar el impacto en la
fase 0,5 y la orientación del arma calculada para ese contacto.


## Enemigo1: guardia y crochet

`young_pose.gd` incorpora `boxing_guard`, `boxing_walk`, `boxing_rise`,
`boxing_lower` y `hook`, sin modificar el Meshy. `young_enemy.gd` gestiona la
probabilidad tras el primer daño y los temporizadores persistentes. Ver
`docs/YOUNG_3D.md` para reglas exactas; revisar ambos brazos en F6 y conservar
los pies y las raíces de cadera al girar el torso. Prueba específica:
`tests/prototype_3d_enemy_boxing.gd`.


## Equipar, agarres y carga de rodillas

El equipamiento 3D usa `equipment_pose()` y captura los brazos realmente
mostrados antes de cambiar de familia. La mano principal acerca el objeto y
la izquierda se une al mango entre el 25 % y el 85 % del gesto. Transportar el
plano del codo al cambiar de objetivo; interpolar los polos linealmente puede
invertirlo al sacar un arma distinta. No filtrar de nuevo las manos contra las
claves genéricas del reposo, que no son la pose relajada realmente dibujada.

Porte de armas/herramientas 10° más diagonal; apoyo de hacha/pico a 8,25 unidades
del agarre principal. Codos ocupados ligeramente más bajos, pronación continua
hasta 12° orientada por el eje del mango. El arco conserva su línea de tiro.
La flexión adicional de rodillas al atacar se reduce al 40 %; mantener la
postura base de Ctrl. Para contactos bajos se aumenta la bisagra del torso.
El perfil v3 limita la influencia del húmero en la superficie escapular sin
inmovilizar la cara interna del brazo. Pruebas específicas de transición:
`tests/prototype_3d_equip_transitions.gd`.


## Persecución y muerte con apoyo de rodillas

`prototype_3d/fall_motion.gd` define curvas suaves compartidas para el orden
rodillas → caída de espaldas → apertura de brazos y piernas. Se preservan
las duraciones: tres segundos para el superviviente y dos para el enemigo1.
La postura final se mantiene inmóvil, incluida la ropa. El superviviente captura
la pose real al morir desde carrera, combate, arco, agachado o deslizamiento;
si ya está a ras del suelo, enlaza directamente con la parte reclinada sin
levantarse antes de caer. Los giros de pies y cabeza acompañan al cuerpo.
Se transportan los planos de flexión para conservar continuidad en codos y
rodillas; no se modifican longitudes óseas ni geometría o texturas del humano.

La persecución del enemigo1 usa pasos visualmente más lentos y amplios,
conservando su velocidad física. La cola incorpora una bisagra y pesos locales
necesarios para dejarla a un lado durante la caída. El cadáver conserva una
zona de recogida con E ajustada a su nueva postura. Véase `docs/YOUNG_3D.md`.
La suite `tests/prototype_3d_falls.gd` comprueba orden de apoyos, apertura,
continuidad desde acciones y poses bajas, soporte de piel y cadáver estable.


## Respuesta del superviviente: cámara, retirada, salto y sprint

`facing_delay.gd` mantiene un historial temporal de la dirección de la mira:
la orientación normal y la postura del arco siguen la cámara con un segundo
de retraso, también si el ratón continúa girando. La cámara responde al instante.
Golpes, tiro y recogida conservan el contacto de la mira y el giro hacia él;
los deslizamientos fijan su orientación al iniciarse.

`slide_back` mantiene la vista hacia delante mientras la cadera se retira.
La pierna izquierda queda más extendida y la derecha carga flexionada, con
planos de rodilla separados, tobillos suaves y torso curvado sobre la cadera.
Se activa con dirección hacia atrás + sprint + Ctrl; las diagonales conservan
el recorrido normal. Dura 0,46 s y recorre el 60 % de los otros deslizamientos.
El salto encadenado conserva su pose real de salida y la inercia reducida.
Se adapta el apoyo lateral de pierna de Baseball Canada y el descenso bajo de
cadera del manual de combate escénico; no se reproduce una caída rígida ni se
invierte simplemente el clip anterior.
Referencias: https://www.baseball.ca/sliding-fundamentals y
https://weaponsofchoice.com/the-textbook-of-stage-combat/foundations-of-staged-violence/unarmed-stage-combat/falls/.

El salto eleva ambas manos gradualmente unas 3,8 unidades de autoría durante
la subida y las devuelve al bajar. También afecta al agarre, apoyo y plano del
objeto equipado; muñecas y antebrazos se resuelven con la misma anatomía.
Los puñetazos alternan derecha/izquierda desde la entrada real de ataque.
Cada brazo recibe preparación, extensión y recuperación; torso y pelvis giran
y el pie del lado que golpea da un pequeño paso antes del contacto. Se mantiene
el ataque agachado y la selección de contacto de la mira.

`movement_response.gd` coordina velocidad y mezcla visual: arranque de 0,16 s,
fase máxima que acelera durante 1 s hasta el multiplicador 1,6, y frenada de
0,24 s hacia reposo, marcha o marcha agachada. Interrumpir o reiniciar captura
la velocidad y la carga de sprint actuales; no exige terminar una fase.
Los pasos, torso, manos ocupadas y balanceo de brazos usan esa carga común.
Las nuevas partidas, reaparición y colocación reinician la respuesta; el
guardado conserva la fase y el deslizamiento hacia atrás. Los archivos antiguos
siguen siendo válidos. En F6 se añaden el clip de retirada y el selector de
puñetazo izquierdo. Pruebas: `tests/prototype_3d_player_motion.gd`.


### Jab y altura del brazo contrario

El brazo de apoyo conserva su desplazamiento de guardia, pero su elevación
vertical respecto al brazo relajado se multiplica por 0,2: la mitad de la
elevación de la primera revisión del jab (0,4), y un 80 % menos que la versión
inicial. La corrección se calcula en el marco del torso, por lo
que sigue siendo la misma al agacharse o girar.

Cada puño prepara cerca del pecho entre 0 y 0,28 del gesto, se extiende en
línea recta hasta el contacto en 0,5, regresa por esa misma línea hasta 0,72
y vuelve al reposo. El objetivo libre queda cerca de la altura del hombro,
con alcance de 18,57 sobre 19 unidades de brazo y codo suave. Con contacto
seleccionado, la misma trayectoria usa el punto de la mira dentro del alcance.
El plano de flexión transporta el codo bajo el antebrazo sin abrirlo hacia el
lado ni invertirlo al entrar/salir. Se conservan alternancia, giro de torso y
pelvis, paso del pie activo y duración/contacto del golpe. Prueba específica:
`tests/prototype_3d_jab.gd`.


## Rutina nocturna y aplicación de comportamientos del enemigo1

La lógica de `creature_brain.gd` decide sueño de 23:00 a 06:00, interrumpido por
alerta, memoria de un jugador o daño. `young_enemy.gd` amplía la percepción
nocturna a veinte metros con comprobación de obstáculos. `young_sleep.gd`
añade descanso recogido y respiración sobre los apoyos de sentado, más entrada
y despertar; no cambia las curvas de ningún clip anterior. Las entradas desde
una pose interrumpida se capturan en `young_model.gd`.

El secundario requiere daño real registrado y se limpia si quedan indicadores
incoherentes. Se preserva su probabilidad, duración y daño. Sentarse y comer
conservan sus animaciones; la selección de árboles, distancia física de llegada,
pausa entre comidas y restauración al cargar se aplican desde el comportamiento.
La integración del nuevo modelo corresponde al departamento de modelaje:
esta tarea no modifica mallas, pesos, UV ni texturas.


## Expresión facial del enemigo1

La versión reducida del nuevo modelo incorpora apertura de mandíbula y tensión
suave de mejillas durante `attack` y `hook`, mediante forma de mezcla local en
`young_face.gd`. El cuello y la unión cabeza/cuerpo quedan fuera de la máscara.
La cara original, los buffers de reposo, la ligadura y las texturas se conservan.
El interior de la boca es una cavidad pequeña del tono del hocico más oscuro,
unida al marco de la cabeza y visible solo durante la apertura. La expresión
es independiente por instancia y se cierra al interrumpir el ataque.
