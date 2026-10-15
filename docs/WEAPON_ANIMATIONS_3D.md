# Animaciones de hacha, pico, espada y arco sobre el Meshy

Los gestos de `scripts/prototype_3d/weapon_motion.gd` utilizan el rig y la piel
actuales del Meshy Wild Wanderer. Se mantienen los modelos, materiales, agarres,
longitudes de huesos y corrección de espalda. El catálogo común conserva
locomoción, deslizamiento, salto, recogida y consumo.

## Referencias consultadas

- Hacha: [USDA Forest Service, An Ax to Grind, Chopping Technique](https://www.fs.usda.gov/t-d/pubs/pdfpubs/pdf99232823/pdf99232823Pdpi72pt06.pdf),
  y [One Moving Part: Using an Ax](https://www.fs.usda.gov/t-d/pubs/pdfpubs/pdf18232812P/Part11a_UsingAnAx.pdf).
  Se consultaron sus fragmentos indexados sobre recorrido de corte y agarre;
  la descarga completa de estos PDF devolvió 403. El movimiento de juego se
  adapta a la cabeza de piedra y a la separación de manos existente.
- Pico: [Washington Trails Association, Moving Mindfully](https://www.wta.org/news/magazine/features/moving-mindfully-how-to-care-for-your-body-while-caring-for-trails)
  y [Portland, Trail Building Tools](https://www.portland.gov/transportation/planning/trail-building-tools-and-resources).
  Base: apoyo estable, flexión de rodillas/caderas y uso del peso de la cabeza.
- Espada: [Anonimo Bolognese, traducción de Stephen Fratus](https://wiktenauer.com/images/8/83/Anonimo_Bolognese_translation_%28Stephen_Fratus%29.pdf),
  secciones de cortes, giros del cuerpo y espada sola. Se adapta la carga alta,
  el corte diagonal y el regreso a guardia a una espada de una mano.
- Arco: [World Archery, Barebow](https://www.worldarchery.sport/sport/equipment/barebow)
  y [World Archery, Recurve](https://www.worldarchery.sport/sport/equipment/recurve).
  Base: elevar el arco, tensar hacia la cara, mantener anclaje y continuar el
  gesto tras la suelta. La muñeca queda junto a la mandíbula para que los dedos
  lleguen a la cara del modelo; el codo de tracción se abre hacia fuera/atrás.

Son movimientos de autor con IK, adaptados a los tiempos y objetos del juego.

## Gestos y contactos

| Familia | Preparación | Golpe o suelta | Recuperación |
| --- | --- | --- | --- |
| Hacha | Carga oblicua alta, hombros y pelvis cargan el peso | Acelera hacia el contacto; el cuerpo acompaña | Extrae la cabeza hacia delante/arriba y vuelve a guardia |
| Pico | Elevación más vertical y flexión de rodillas | La cabeza cae hacia el punto con una bisagra de cadera | Despeja el pecho con la herramienta antes de bajar las manos |
| Espada | Guardia adelantada y carga alta del brazo de arma | Corte diagonal con giro de pecho y pelvis | Continúa el filo y vuelve a guardia; el brazo vacío mantiene el contrapeso |
| Arco | Eleva el arco, une la mano de cuerda y tensa hasta la mandíbula | Brazo de arco extendido con codo suave; suelta al finalizar el tensado | La mano de cuerda continúa, la cuerda vibra y el arco baja |

El hacha, pico y espada comparten las fases de carga, impacto, continuación y
recuperación, pero tienen trayectorias y esfuerzo corporal diferenciados.
El impacto sigue en la fase 0,5. El contacto y la orientación se calculan para
esa pose de impacto; las demás fases interpolan hacia ella sin volver a elegir
una solución distinta por cada cambio de postura del torso. El solver comprueba
que el mango o la hoja despejen la envolvente real del tórax. Descarta temprano
candidatos que no pueden mejorar el resultado para evitar trabajo por fotograma.

La guardia y el porte al caminar/correr/agacharse se adaptan a cada familia;
equipar y desequipar enlazan con esas guardias. Los dos agarres de las
herramientas siguen sus anclajes reales. El brazo vacío de la espada conserva
la extensión de equilibrio solicitada por el usuario.

En el arco, `draw` dura los mismos 0,5 s. La flecha aparece una vez que la mano
se une al arco elevado, y sigue la línea real entre el culatín y la mira. La
mano y la cuerda coinciden durante el tensado. El estado `bow_release` añade
0,24 s de seguimiento visual: no bloquea un nuevo disparo, no consume más
flechas ni añade desgaste. Correr, saltar, deslizarse o iniciar otra acción
pueden sustituir ese seguimiento. La recuperación visual se reinicia al cargar
una partida y al reaparecer.

## Revisión

F6 en `scenes/prototype_3d/animation_review.tscn`: escoger familia y `action`;
para el arco, revisar `draw` y `bow_release`. La pausa y el deslizador de fase
permiten inspeccionar carga, contacto y extracción. Revisar con armadura y
con «Atacar agachado», desde delante, atrás y de lado. Los controles de altura
y distancia de contacto conservan la asistencia de la mira del juego.

`tests/prototype_3d_weapon_motion.gd` comprueba continuidad de la palma, agarres,
impactos a tres alturas, agachado, mango/hoja fuera del tórax y cráneo, anclaje
junto a la mandíbula, codo suave, inicio y final del seguimiento del arco. Se
complementa con las suites de volumen de piel, armadura, precisión del arco,
combate agachado, contrapeso, movimiento diagonal, deslizamiento y guardado.

Las duraciones de golpe, daño, alcance físico, tolerancia de la mira, consumo de
flechas, desgaste y vuelo de proyectiles permanecen bajo las mecánicas vigentes.


## Transiciones y postura de sujeción (16 de octubre de 2026)

El equipamiento ya no usa las antiguas claves genéricas que obligaban a las
dos manos a tomar el mango desde el primer fotograma. `equipment_pose()` enlaza
la postura vacía de cada locomoción con el porte correspondiente. En partida,
`begin_equipment_transition()` toma las manos, codos, palmas, giro de antebrazos
y torso que realmente se ven, también al cambiar directamente entre armas o
interrumpir una transición. La segunda mano se une entre el 25 % y el 85 %;
los objetivos y límites de alcance entran gradualmente. Las manos siguen la
curva suavizada de la animación y no se filtran contra las claves genéricas
anteriores. El plano de flexión del codo se transporta con el brazo, evitando
la inversión que puede producir una interpolación lineal de polos.

El porte de hacha, pico y espada se inclina **10° más lejos de la vertical**
en su plano previo. El arco añade **10° de inclinación lateral** alrededor de
la dirección de tiro, conservando la precisión de la flecha. La mano izquierda
del hacha/pico sujeta a **8,25 unidades** a lo largo del mango, una unidad por
encima del apoyo anterior; perfil e IK de impacto comparten ese anclaje.
El codo del brazo ocupado baja ligeramente. Antebrazo y palma reciben una
pronación continua de hasta **12°**, orientada por el eje real del mango;
no se cambia el brazo libre de contrapeso ni el codo de tracción del arco.

La flexión adicional de rodillas del ataque se reduce un **60 %** respecto a
la postura base, manteniendo el agachado de Ctrl y la marcha. La altura de
cadera se calcula con las longitudes óseas originales. Al golpear bajo, el
pecho se inclina más desde la cadera para conservar el alcance sin compensar
con otra sentadilla. Los impactos continúan en la mira y los tiempos de acción
no cambian. El perfil escapular vigente se describe en `MESHY_ASSETS.md`.
