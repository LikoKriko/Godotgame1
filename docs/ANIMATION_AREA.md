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
`main` contiene ahora el juego 3D. El juego 2D ha sido retirado; consultar
[RETIRED_2D.md](RETIRED_2D.md) antes de recuperar dependencias antiguas.

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
`meshy_shoulders_v4_axilla`, descrito en `docs/MESHY_ASSETS.md`. La corrección reproducible está en
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
la orientación normal y la postura del arco siguen la cámara con 0,15 segundos
de retraso, también si el ratón continúa girando. La cámara responde al instante.
Golpes, tiro y recogida conservan el contacto de la mira y el giro hacia él;
los deslizamientos fijan su orientación al iniciarse.

`slide_back` mantiene la vista hacia delante mientras la cadera se retira.
La pierna izquierda queda más extendida y la derecha carga flexionada, con
planos de rodilla separados, tobillos suaves y torso curvado sobre la cadera.
Se activa con dirección hacia atrás + sprint + Ctrl. Las diagonales traseras
usan ahora `slide_back_left` y `slide_back_right`, con ese mismo recorrido
reducido. Dura 0,46 s y recorre el 60 % de los deslizamientos frontal/laterales.
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

`young_face.gd` genera cinco formas de mezcla locales: mandíbula izquierda y
derecha, pómulo izquierdo y derecho y elevación leve de nariz. No añade huesos
ni cambia la ligadura de quince huesos. El cuello y la unión cabeza/cuerpo
quedan fuera de todas las máscaras. Los colmillos superiores permanecen en el
maxilar; los inferiores giran con la mandíbula y su tejido circundante, sin
estirarlos ni separar sus puntas por el color de la textura.

La abertura utiliza un corte en la línea del labio: subdivide cincuenta y seis triángulos
de la superficie original e interpola UV y pesos en sus bordes. En reposo
reproduce la superficie cerrada, conservando todos los vértices originales
como prefijo, sus atributos originales y el material/PNG aportado. Una segunda
superficie de la misma malla forma el revestimiento hundido hacia dentro; sus
bordes comparten posiciones, deformaciones y pesos con ambos labios. Sustituye
la pieza independiente anterior. El labio se sitúa a 14,8 unidades y la
mandíbula gira 0,11 radianes. Su apertura máxima medida es 4,73 veces la de la
revisión anterior (1,1102 frente a 0,2346 unidades del modelo).

Al cerrarse, el revestimiento completo se colapsa sobre la línea del labio:
no queda una lámina oscura con profundidad. Al abrirse se despliega formando techo, fondo y suelo por detrás de los
colmillos y entre las alturas de ambos labios. El reverso se descarta y el fondo interior mira hacia la abertura.
Las máscaras respetan el volumen real de los cuatro colmillos y excluyen
los puños de piedra usando la pertenencia a la cabeza en la ligadura.
Textura interior sencilla de cinco tonos oscuros del hocico, píxeles nítidos
y muestreo nearest; no se modifican los archivos fuente.

El gesto facial completo dura **2 segundos**, con reloj independiente del
ataque normal (**1 s**) y crochet (**1,2 s**). Empieza con el ataque y termina
aunque el cuerpo ya haya regresado a otro comportamiento. Otro golpe durante
el gesto no reinicia su reloj. Al morir o quedar aturdido se cierra suavemente
desde los valores actuales durante 0,16 s. Las expresiones son independientes
por instancia; la geometría derivada se comparte mediante caché. Las formas
absolutas usan mezcla normalizada, suma de pesos limitada a uno y conservan
las normales/tangentes del modelo para evitar cambios de iluminación al activar los cinco controles.

Pruebas: `tests/prototype_3d_enemy_face.gd` y
`tests/prototype_3d_young_reference_mesh.gd`. Galería publicada de la revisión
anterior a esta última corrección: [boca interior](previews/enemigo1-boca-interior-2026-10-16/README.md).


## Afinado del superviviente: sobacos, dirección y retirada diagonal (16-10-2026)

El jab conserva alternancia y contacto. El antebrazo contrario parte del plano
real del brazo relajado y pasa a guardia mediante una curva quíntica: preparación
hasta el 42 % del clip y recuperación desde el 60 %. Se reduce la reorientación
del codo de apoyo al 30 %; las palmas vacías conservan su marco natural. Esto
elimina el salto inicial de giro y mantiene una transición visible de ida/vuelta.
La corrección local de piel `meshy_shoulders_v4_axilla` amplía la transición de
pesos del pliegue axilar sin cambiar geometría, UV ni texturas originales.

`gait_direction.gd` interpola todas las direcciones de marcha en 0,12 s,
por el arco corto y conservando el módulo, incluso entre direcciones opuestas.
Funciona al caminar, caminar agachado y con manos ocupadas, también en recogida,
comida/bebida o equipamiento durante la marcha. Los cambios continuos pequeños
de cámara actualizan el destino sin reiniciar toda la transición. Se aplica a
la animación; la velocidad física y los controles siguen respondiendo al instante.

Los ataques de hacha, pico, espada y arco reducen la inclinación del pecho
un 50 %, conservando la postura base agachada. Se integra `cedeb33` del otro
departamento con hacha/pico al 60 % y palmas separadas 4,95 unidades. Su bisagra
adicional de contacto bajo se reduce también a la mitad, 0,18 rad. Los contactos
bajos que lo necesitan usan transferencia continua hacia delante y descenso
apoyado en las piernas, manteniendo pies, agarres y longitudes de huesos.
El brazo libre de espada eleva la mano un 70 % menos respecto al reposo;
el codo activo baja ligeramente sin mover el agarre. La pelvis reduce un 30 %
su balanceo lateral, giro, cabeceo y oscilación vertical cíclicos en carrera,
arranque, frenada y equipamiento corriendo, conservando la inclinación sostenida.

Las dos retiradas diagonales usan S+A/S+D + sprint + Ctrl. Mantienen la vista
hacia delante, desplazan la cadera y contrapesan el pecho/manos, con apoyo y
pierna extendida intercambiados según el lado. Tobillos y planos de rodilla
giran juntos hacia la diagonal. Ambas duran 0,46 s y recorren el 60 %;
el salto enlazado hereda los pies y tobillos realmente mostrados y conserva
su orientación relativa al deslizar. El guardado registra el lado y restaura
la pose correcta; los archivos anteriores siguen aceptándose sin ese campo.
F6 incluye ambos clips. Pruebas específicas: `prototype_3d_animation_polish.gd`
y ampliación de `prototype_3d_player_motion.gd`, además de las suites compartidas.


## Rendimiento de golpes y búsqueda de agarres (16-10-2026)

Corrección sobre `dd604ef`, última versión remota comprobada. Al golpear,
`survivor_animation.gd` resuelve la pose de impacto en cada fotograma.
`weapon_motion.gd` puede probar hasta 40 transferencias de apoyo; cada llamada
a `tool_aim.gd` recorría 1647 orientaciones. Un objetivo imposible —incluido
el punto a unos 100 m que entrega la cámara al golpear al aire— podía repetir
unas 70000 pruebas por fotograma. El contacto se resolvía otra vez después
de encontrar una transferencia válida.

`tool_aim.gd` conserva el objetivo y la anatomía, pero descarta antes de buscar
si la distancia supera brazo + punta, o brazo de apoyo + distancia punta/apoyo.
Son límites geométricos necesarios, no una reducción del alcance. Precalcula
senos/cosenos y prioridad de las mismas 1647 orientaciones, visita primero las
de menor coste y abandona cuando ninguna restante puede mejorar el resultado.
En empates conserva el orden original. Los candidatos descartados no necesitan
raíces cuadradas ni construir una Basis.

Se reutilizan consultas idénticas mediante claves por valor con contacto,
ambos hombros, punta, lado activo, uso de dos manos, transformación completa
del torso, separación de apoyo y límites del mango. También se guardan fallos;
128 entradas como máximo y resultados copiados al devolverlos. Cambiar arma,
pose, dirección, posición o agarre no reutiliza una solución incompatible.
No se cuantizan contactos ni se modifica daño, duración, modelos o texturas.

Comparación del personaje completo, 65 fases por secuencia, Godot 4.6.3
headless en la misma máquina; mediana del tiempo CPU de `animate()`:

| Caso | Anterior | Corregido |
| --- | ---: | ---: |
| Hacha, contacto bajo (0,14,28) | 16,416 ms | 0,403 ms |
| Pico, contacto bajo (0,14,28) | 14,488 ms | 0,393 ms |
| Hacha, objetivo lejano (0,40,3600) | 20,956 ms | 0,420 ms |
| Pico, objetivo lejano (0,40,3600) | 20,384 ms | 0,395 ms |
| Espada, contacto muy cercano (0,30,4) | 25,833 ms | 0,364 ms |

Son costes de animación, no mediciones de FPS globales ni del PC del usuario.
La primera consulta difícil de espada cercana, aún sin resultado reutilizable,
registró 22,678 ms; el percentil 95 de esa secuencia baja de 37,128 a 0,405 ms.
Los contactos que cambian continuamente se benefician de límites y orden de
búsqueda; la reutilización exige igualdad exacta de todos sus parámetros.

Prueba reproducible:
`godot --headless --path . --script tests/prototype_3d_tool_aim_performance.gd`.
La referencia congelada de `dd604ef` queda exclusivamente en fixtures de test.
Compara 989 consultas, incluidas ambas manos, posturas agachadas, cambios de
perfil y contactos cercanos/lejanos; comprueba resultados repetidos, aislamiento
de devoluciones, memoria limitada y mejora relativa frente al cálculo anterior.
Las suites de golpes, oclusión, agachado, mira, equipamiento y movimiento del
jugador permanecen vigentes. Se revisan también fotogramas nativos completos.
