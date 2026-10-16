# Prototipo 3D de Day Zero

Rama `prototype/third-person-3d`; `main` conserva el juego 2D. Seleccionar esta
rama antes de descargar el ZIP, importar `project.godot` en Godot 4.7.2 y pulsar
F5. La escena inicial es `scenes/prototype_3d/day_zero.tscn`: abre el menú principal.
`day_zero_3d.tscn` sigue siendo la escena del mundo, también usada por las pruebas.

Modelos vigentes: superviviente y botella de las Releases Meshy aportadas por
el usuario; procedencia, regeneración y comparativas en [MESHY_ASSETS.md](MESHY_ASSETS.md).
Las secciones que describen reconstrucción procedural y proyección de pinturas
recogen etapas anteriores; esos sistemas han sido sustituidos en el personaje 3D.

Mundo vigente: **6,4 × 6,4 km (40,96 km²)**, generado por proximidad.
Configuración → Gráficos → Generación de mundo: 100/200/400 metros,
200 por defecto. Generación, persistencia y pruebas en
[WORLD_STREAMING.md](WORLD_STREAMING.md).

## Incluido en esta integración

- Cámara sobre el hombro derecho: distancia 3,6 m, desplazamiento 0,30 m, FOV
  75°, sensibilidad 0,0025 rad/píxel, inclinación −90° a +90°. Una esfera evita
  atravesar paredes y copas. Movimiento relativo a la cámara.
- Superviviente estilizado de 1,75 m y 60 kg, delgado, con piel continua,
  articulaciones estables y pantalón holgado con inercia ligera. El esqueleto
  tiene 24 controles, incluidos cuatro para los bajos de la tela y cuatro para
  conservar el volumen de codos y rodillas.
- Atlas de alta resolución con acabado pixel art, paleta limitada y muestreo
  nearest con mipmaps. El superviviente conserva la geometría, UV y cuatro PNG originales del FBX Meshy.
- Catálogo de 29 estados para manos libres y siete familias de objetos: caminar,
  correr, agacharse, deslizamiento, saltos, transiciones, equipar en movimiento,
  gestos de herramientas/armas, tensado, recogida, comer, beber, parry, daño y
  muerte. Las animaciones son continuas y se pueden revisar desde cualquier
  ángulo; no dependen de direcciones discretas de sprites.
- El hacha existente tiene volumen, dos agarres y alcance anatómico. El punto
  de mira se fija al iniciar el golpe y los brazos acompañan al mango. El
  pico y la espada también tienen volumen y contacto por la mira. El arco tensa
  de forma continua durante 0,5 s, necesita una flecha y gasta un uso al tensar,
  incluso si se cancela; la flecha se consume únicamente al soltarla. Los rayos
  por segmento evitan atravesar objetivos entre fotogramas.
- La dirección del cuerpo converge hacia el contacto de la mira, también en
  reposo; al desplazarse durante un golpe sigue mirando al punto fijado al
  iniciarlo. El arco sigue la mira hasta soltar la flecha. El punto blanco se
  dibuja en el centro exacto del viewport, independiente de la tipografía o el
  tamaño del HUD. La cámara y el impacto toman el mismo contacto físico.
- Joven topo de 0,875 m, esqueleto propio de catorce huesos: cuatro apoyos al
  caminar/correr, levantarse para alternar puños, sentarse, comer de árboles,
  stun y muerte. Persigue al 85% de la caminata del jugador y deambula al 42,5%.
  Guarda la última posición vista y la investiga antes de volver a su rutina.
- Parry con ventanas de 0,5 s antes / 0,2 s después, daño diferido 0,35 s,
  enfriamiento 4 s y stun 1,5 s. Solo un bloqueo conseguido produce el pulso
  blanco alrededor de las manos. Indicador de stun circular reutilizable.
- HUD con vida, calorías, hidratación, peso, día/hora, nivel, mapa y seis huecos
  rápidos. Configuración integrada: correr automático y cinco tamaños del HUD.
- Inventario de 32 huecos, cinco espacios de armadura, seis huecos rápidos
  físicos, arrastre, Shift + clic, reparación y retrato renderizado en 3D.
  Iconos de 256×256 a partir de los originales; símbolo provisional compartido
  para diseños inexistentes.
- Creación con recetas originales, reserva de materiales, duración de 2 s y
  devolución exacta al cancelar. Habilidades y perks comparten puntos; los
  costes, límites y efectos son los del juego 2D. Las misiones y logros siguen
  vacíos y solo se admiten las cinco fuentes de experiencia ya aprobadas.
- Comer/beber aplica el consumo al terminar la animación de 1,2 s y permite
  caminar, evitando correr. Día de 16 minutos y nutrición reutilizados del 2D.
- Catálogo K con búsqueda, cantidades, +1 nivel y aparición de un joven.
- Terreno continuo con las cuatro texturas originales, semilla, regiones, máscaras
  orgánicas, precarga, descarga y caché de chunks. Consultas de tipo/densidad y
  suelo desnudo junto a los árboles. El mapa usa la misma semilla y regiones.
- Armadura de hojas visible sobre pecho, abdomen, espalda y hombros, con cuello
  abierto y costuras finas. Comparte el movimiento completo del torso y aparece
  en el retrato del inventario; todavía no añade protección.
- Rocas de prueba: una pequeña recogible con E y tres tamaños para pico de
  4/8/12 golpes y 4/10/15 piedras. La muestra pequeña da dos piedras, dentro del
  rango de 1–3 original. Un charco permite rellenar la botella seleccionada con E.
- Botella y tres alimentos visibles al comer/beber. Recoger baja la velocidad un
  60% durante 0,72 s y la recupera en 0,5 s. Al equipar se pierde un 5%, que se
  recupera progresivamente en 1 s. Se puede seguir caminando al sacar el objeto.
- Espada: 3 de daño y un uso solo al impactar; hacha/pico: 1 de daño, dos usos
  contra enemigo o recurso incorrecto y uno en su función correcta. El daño
  contra recursos solo lo hace la herramienta correspondiente. El arco hace 3
  de daño. La estela corta sigue la punta física de la espada.
- Muerte del jugador en 3 s y reaparición sin objetos ni perks, a nivel 1,
  conservando las habilidades desbloqueadas en su primer nivel.

El escenario aislado de pruebas conserva su superficie de 48×48 m con cuatro
árboles, rocas, un charco y una pared. La partida normal utiliza el mundo amplio
y la carga por proximidad descritos en [WORLD_STREAMING.md](WORLD_STREAMING.md).
El seguimiento de la migración está en [MIGRATION_3D.md](MIGRATION_3D.md).

## Controles y escenas de revisión

WASD y ratón; Shift correr; Ctrl agacharse o deslizarse mientras corres; Espacio
saltar; 1–6 seleccionar/quitar el acceso rápido; clic golpear o usar; E interactuar; F parry; I inventario; T crear;
M mapa; K catálogo; Z/X habilidades; Esc pausa/cerrar. Desde pausa puede abrirse
la versión 2D. El prototipo no escribe partidas 2D.

Para revisar poses sin alterar la partida, abrir una de estas escenas y usar F6:

- `scenes/prototype_3d/animation_review.tscn`: familias y animaciones del jugador.
- `scenes/prototype_3d/young_review.tscn`: acciones y manos alternas del joven.
- `scenes/prototype_3d/icon_review.tscn`: catálogo de iconos originales/provisionales.

En las dos primeras, arrastrar con botón derecho gira la cámara; hay cámara lenta.
Los anclajes ObjectGrip, SupportHand y ObjectTip se expresan en el espacio del
modelo. Cada perfil de objeto declara punta y segundo agarre en `held_profiles.gd`.

## Arquitectura y comprobaciones

El perfil `survivor_surface.gd` comparte las medidas de cintura, caja torácica,
cuello y cadera entre geometría, pinturas, separación de brazos y armadura.
Los hitos frontal/trasero proceden de las imágenes entregadas; la profundidad
se modela por separado. `humanoid_rig.gd` guarda las dos proyecciones en UV2 y
CUSTOM0 y el shader mezcla sus **colores**, evitando interpolar coordenadas
espejadas que atravesaban el fondo del dibujo. Cada pernera tiene su propio
recorrido de textura. La cintura, el puente de tela y la cuerda comparten el
contorno físico; los bajos conservan sus huesos y movimiento independientes.

`tests/prototype_3d_surface_fit.gd` comprueba la malla real, sus proporciones,
cobertura de ambas pinturas, interpolación dentro de triángulos, unión de las
perneras y pesos de la cintura. Se complementa con las pruebas de deformación,
articulaciones y holgura de la armadura, y con revisión renderizada desde ocho
orientaciones. La cobertura y estabilidad numérica no certifican un parecido
artístico perfecto: las vistas frontal/trasera no especifican toda la profundidad.

`scripts/prototype_3d/` separa anatomía, catálogo de poses, IK de herramientas,
rig humano, rig del topo, decisiones de criatura, física, cámara e interfaz.
Una sola malla por personaje conserva pesos y UV durante toda la animación;
no se regeneran sprites ni superficies cada frame. La personalidad usa
`creature_profile.gd`; la memoria y los objetivos están en `creature_brain.gd`.

Las ventanas 3D heredan la interfaz 2D con proveedores de iconos, mapa y retrato
sustituibles. Los valores por defecto del 2D permanecen intactos. La fabricación,
almacenamiento, reparación, nutrición, progresión y parry comparten sus reglas
originales. La captura del ratón se libera únicamente al abrir interfaces;
no se convierte la posición del cursor manualmente ni se abren ventanas nativas.

Pruebas con Godot 4.7.2:

```sh
godot --headless --path . --script tests/prototype_3d.gd
godot --headless --path . --script tests/prototype_3d_animation_catalog.gd
godot --headless --path . --script tests/prototype_3d_movement.gd
godot --headless --path . --script tests/prototype_3d_creature.gd
godot --headless --path . --script tests/prototype_3d_systems.gd
```

Cubren longitud de huesos y agarres en todo el catálogo, separación de pies en
16 rumbos, persistencia de malla, alcance, memoria sin visión, parry temprano y
daño diferido, HUD, almacenamiento, reserva/devolución de materiales, consumo al
terminar la animación y puntos compartidos. Las escenas también se renderizan
para revisar geometría, capas y distribución. Las comprobaciones automáticas
no sustituyen la revisión artística final ni las pruebas en el Windows del usuario.

El componente `building_stream.gd` prepara interiores en el mismo mundo, con
carga por proximidad, prioridad junto a la puerta y descarga con histéresis.
Su prueba aislada es `tests/prototype_3d_building_stream.gd`; los edificios del
campamento todavía tienen que modelarse y conectarse a este componente.

## Terreno por chunks

`terrain_profile.gd` conserva los parámetros del 2D: 512 unidades originales por
chunk (14 m con escala 1,75/64), dos chunks progresivos por actualización, una
corona de precarga, dos de retención y 96 en caché. Las proporciones iniciales
son 67,5% normal, 10,5% oscuro, 12% vegetación y 10% tierra. Región 720 unidades,
transición 0,028, muestra de textura 144 unidades y paso de píxel 1.

El renderer 3D comparte `terrain_sampler.gd` con el 2D. Las posiciones globales
se convierten una sola vez a las unidades del sampler. Los planos comparten
malla/texturas y las máscaras no dependen del chunk. `configure(seed,profile)`
permite terreno sin límite. La partida 3D lo limita a 6400×6400 m y usa chunks
de terreno de 28 m, ocho activaciones por fotograma, una corona de retención y
16 chunks ocultos en caché. Caminos y sampler se comparten con el generador
original; sus 84×56 m se conservan como zona inicial, extendida por streaming.

La prueba gráfica `tests/prototype_3d_terrain.gd` compara cada píxel entre varios
chunks y un único plano, también en coordenadas negativas y lejanas. Comprueba
además la reproducción exacta al descargar/regresar y el límite de la caché.

## Equipo e interacciones migradas

`held_prop.gd` construye objetos sólidos a partir de perfiles de categoría;
`prop_mesh.gd` comparte cilindros y materiales de detalle pixel art. La cuerda
se orienta entre puntos reales sin escalar en los ejes del mundo. Cada golpe
mantiene el punto de mira inicial y limita el alcance anatómico; los contactos
bajos flexionan el cuerpo y las piernas. La cuerda del arco y el culatín siguen
el hueso de la mano que tira. La botella acerca su boca a los labios.

Pruebas añadidas: `tests/prototype_3d_equipment.gd` comprueba daño, desgaste,
munición, cancelación, tiempos, cuerda, colisión del proyectil y armadura;
`tests/prototype_3d_interactions.gd` usa el rayo real de cámara para recoger y
rellenar, y verifica consumo de 250 ml conservando el recipiente. La prueba de
movimiento también cubre la ralentización de recogida y comer con correr
automático activado. La revisión F6 permite mostrar la armadura.

Pendiente: acabar los modelos del entorno y el resto de objetos. El sistema del PDF sigue pospuesto hasta
terminar toda la migración.


## Población, elevaciones e interiores

`world_layout.gd` adapta los datos de `test_world.gd` y `harvesting.gd`, sin
mantener dos generadores distintos. `world_content.gd` crea recursos con un
presupuesto de 4 ms por frame y un edificio por actualización. Con seed 73129
hay 83 árboles y 5191 grupos de hierba; estos últimos usan quince MultiMesh,
y cada árbol agrupa su geometría en una superficie compartida por variante.
Los materiales reutilizan detalles en gris de los atlas existentes, a 256²,
con muestreo de píxel y tintes contenidos. El césped no usa un segundo pase
de contorno, que taparía sus superficies delgadas.

`raised_ground.gd` convierte el contorno de cada uno de los tres sprites en
una superficie física. Altura 0,2625 m; faldón de tierra con apoyo convexo para
subir andando. Los objetos de más de 0,525 m bloquean el paso durante un salto;
la altura física determina este límite, no el tamaño de su hitbox en pantalla.

`camp_building.gd` adapta las posiciones y separación del campamento original.
Los exteriores son volúmenes provisionales de madera y cubierta; aún necesitan
la revisión artística de cada diseño. Los interiores vacíos se cargan mediante
`building_stream.gd`, con puertas físicas y suelo de tamaño ajustado. La capa 32
reserva la barrera de las puertas a criaturas; el jugador la ignora. No hay
teletransporte ni cambio de escena al cruzarlas. Inicio a 18 m, prioridad a 3 m
y descarga a 26 m, manteniendo cargada una habitación ocupada.

Pruebas: `prototype_3d_population.gd` verifica semilla, grupos y lotes gráficos;
`prototype_3d_resources.gd`, recolección y elevaciones con física real;
`prototype_3d_camp.gd`, separación, streaming, entrada y descarga. Las pruebas
aisladas usan `tests/fixtures/prototype_layout.gd`; la partida F5 usa siempre la
generación de la ventana local, sin las antiguas muestras de cuatro árboles y
cuatro rocas. El resto del mundo se genera al avanzar.


La mesa básica usa `prototype_3d/workbenches.gd`: seleccionar en acceso rápido,
apuntar a suelo libre cercano y pulsar clic. La previsualización muestra su
huella real; se bloquea en agua, objetos, jugadores o terrenos elevados.
Colocarla lleva 3 s y Esc conserva el objeto. La barra verde clara se sitúa
sobre el acceso rápido y escala con el HUD. `workbench.gd` tiene cuatro patas
con colisión y sombra reales, a 0,875 m de altura. Con E se abre la ventana
compartida de creación en estación (nivel 1), conservando desbloqueos y costes.
`tests/prototype_3d_workbench.gd` comprueba colocación, cancelación, inmovilidad,
colisión, entrada/salida de la ventana y curtido con desgaste de sal/cuchillo.


`corpse_loot.gd` adapta el almacén de ocho espacios a los cuerpos 3D. La selección
se habilita al completar la caída; el cuerpo conserva su inventario durante 3 min.
La recogida respeta slots y estados individuales. Tirar crea un `world_item.gd`
seleccionable con E; la representación del suelo usa modelos sólidos compartidos para los objetos
con diseño disponible; conserva un marcador para los diseños todavía ausentes. La recogida usa manos
libres y la animación inclinada. `prototype_3d_loot.gd` cubre transferencia,
mochila llena, botella con contenido, contador y caducidad sin duplicaciones.

## Correcciones de modelos y puntería (15 de octubre de 2026)

El cuerpo conserva el mismo rig y la altura de 1,75 m. Los hombros se unen al
perfil continuo del torso; las piernas tienen perfiles facetados con rodilla, gemelo y
tobillo. El pelo usa una cubierta continua de mechones bajos y planos. En los
golpes el descenso de la pelvis se limita antes de resolver el alcance con IK,
para no sustituir el gesto de brazos por una sentadilla.

Los brazos libres al correr mantienen 75° interiores en el codo y un balanceo
máximo de 16,2° en el hombro, con entradas/salidas de 0,14/0,18 s. El brazo ocupado
por un objeto y ambos brazos con herramientas de dos manos conservan sus
agarres. La armadura comparte la transformación del torso: hojas dentadas,
nervaduras finas, ataduras trenzadas y huecos para que pasen los brazos.

Hacha, pico, espada y arco mantienen los mismos anclajes de agarre/contacto,
con madera segmentada y superficies de piedra biseladas. El pico toma la
silueta de `entregables/herramientas/pico1_3d.png` y la lámina posterior
`pico1_4vistas_3d.png`: mango doble, contrapunta ancha
y punta de trabajo más estrecha. El arco sigue la mira durante los 0,5 s de
tensado; al soltar se fija una línea recta desde la flecha hasta el blanco.
La cámara consulta hasta 100 m y el proyectil desaparece a esa distancia, sin
gravedad. Apuntar al suelo cercano baja la postura y añade una inclinación leve.

Los árboles añaden raíces, tronco quebrado, ramas/tallos y grupos de follaje
facetados. Conservan una sola superficie por árbol y caché para 30 variantes.
No se han convertido los nueve diseños 2D en nueve modelos específicos.

El joven incorpora la referencia nueva de cuatro vistas
`entregables/enemigos/enemigo1_joven_3d.png`, copiada al recurso de ejecución
`assets/enemies/first/reference_3d.png`. El rig de 14 huesos conserva las patas
cortas, marcha cuadrúpeda y ataques erguidos alternos. Los detalles de pelo usan
una muestra limpia de la vista posterior, con muestreo y paleta cuantizados:
no se proyectan ojos o bocas de la imagen sobre superficies curvas del cuerpo.
Ojos, hocico, marcas, colmillos, cresta y puños tienen geometría propia.

Comprobaciones adicionales: `prototype_3d_bow_accuracy.gd` (retícula móvil,
alineación de flecha/manos, vuelo recto y 100 m), `prototype_3d_running_arms.gd`
(ángulos, longitudes, transiciones y agarres) y
`prototype_3d_model_corrections.gd` (geometría, flexión y holgura de armadura).
Se revisaron también imágenes renderizadas con Compatibility; la aprobación
artística del jugador sigue pendiente de probar esta rama en su equipo.


## Partidas 3D: menú, guardado y carga

Al pulsar F5 se muestra el menú principal con el fondo aprobado. **Jugar** crea
una partida; si ya existe un guardado, la confirmación es una ventana integrada
en la interfaz. Crear una partida no borra el archivo anterior. **Continuar**
solo está disponible si hay un guardado 3D válido. La pausa tiene Continuar,
Guardar partida, Configuración, Menú principal y Salir. El panel de muerte
mantiene Reaparecer y Salir al menú principal.

Hay una sola partida manual. Para probar: Jugar → explorar/recolectar → Esc →
Guardar partida → Menú principal → Continuar. También se puede cerrar Godot y
volver a pulsar F5: Continuar lee el archivo del disco. Volver al menú o cerrar
sin guardar descarta los cambios posteriores al último guardado; no hay
sustitución automática del guardado al crear, salir o morir.

El archivo es `user://day_zero_3d.save`. En una instalación normal de Windows
corresponde a `%APPDATA%/Godot/app_userdata/Day Zero/day_zero_3d.save`.
El guardado 2D `day_zero_save.cfg` conserva su formato y archivo propios. No se
convierten partidas 2D en 3D en esta versión.

`scripts/prototype_3d/session.gd` gestiona el menú y el ciclo de vida de la
partida. `save_game.gd` guarda datos JSON versionados con comprobación SHA-256;
no instancia objetos ni scripts desde el archivo. Valida datos antes de
restaurar, incluidos identificadores únicos y recursos originales de la semilla.
Escribe y verifica `.tmp`, conserva el archivo válido anterior en `.bak` y
reemplaza el principal. Si el principal falta o está dañado, Continuar recupera
la copia válida e informa al jugador. Si ambos fallan, muestra el error sin
iniciar silenciosamente una partida vacía.

Se conservan posición, velocidad, cámara, salto/deslizamiento y recuperaciones
del personaje; mochila, equipo, barra física, selección, usos y agua por objeto;
recetas, experiencia, nivel, puntos, habilidades/perks y sus temporizadores;
vida, nutrición, día/hora y enfriamiento del parry; recursos agotados o dañados;
mesas, objetos tirados; criaturas vivas, memoria y estado de comportamiento,
stun, cadáveres, botín y tiempo restante antes de desaparecer. Los interiores
vacíos se regeneran por semilla y se terminan de cargar antes de reanudar una
partida guardada dentro. El tiempo no avanza mientras el juego está cerrado.

Para evitar guardar una transacción a medias, el botón pide terminar o cancelar
una fabricación/colocación, un golpe, equipamiento o consumo en curso, o esperar
el final de un proyectil/impacto diferido. No consume ni devuelve objetos como
efecto secundario de guardar. Un salto o deslizamiento sí se puede guardar.

Configuración tiene **Juego, Gráficos y Audio**: correr automático, seis tamaños
del HUD, VSync, FPS, MSAA 3D y volúmenes. Se aplican y se guardan al cambiar.
Resolución y modo de pantalla siguen bloqueados para no reintroducir el desfase
del ratón. Los cambios gráficos no modifican el tamaño/escala del viewport.

Pruebas reproducibles:

- `tests/prototype_3d_saves.gd`: ciclo completo y recursos, botín, edificio,
  errores, copia de seguridad, rutas `user://` y cancelaciones.
- `tests/prototype_3d_save_restart.gd -- write|read /tmp/day-zero-restart-test-<nombre>.save`:
  escribir y recuperar desde dos procesos distintos de Godot.
- `tests/prototype_3d_session_ui.gd`: con pantalla nativa, clics reales en menú,
  pausa, guardar/continuar y desplegable; FPS, MSAA, audio y HUD sin cambiar
  coordenadas de entrada. Se omite explícitamente en headless.

Las pruebas se ejecutaron en Godot 4.7.2 con Compatibility en Linux. La prueba
nativa comprueba coordenadas con ratón del motor, sin un cursor superpuesto.

## Reposo y unión de hombros

Los brazos libres en reposo usan 165° interiores, sin movimiento cíclico. La
transición dura 0,14 s; la carrera conserva 75° y los agarres ocupados se mantienen.
El deltoides se integra en el perfil del torso, eliminando las piezas esféricas
separadas y enterrando el cierre proximal del brazo. Los primeros pesos mezclan
pecho y brazo para suavizar la unión. La espalda añade planos y relieves discretos
en las escápulas. Cabeza y torso del joven tienen más secciones y planos marcados,
conservando el rig, las proporciones aprobadas y las referencias de cuatro vistas.


## Referencias renovadas, ritmo y cámara (15 de octubre de 2026)

En la etapa procedural anterior se utilizaron
`entregables/personajes/personaje1_frente.png` y `personaje1_espaldas.png`.
Se conservan sin editar; las copias importables en
`assets/characters/prototype_3d/reference_front.png` y `reference_back.png`
alimentan la pintura de pecho, espalda y pantalón en coordenadas de reposo.
El muestreo usa píxeles definidos, cuantización moderada de paleta y mipmaps.
Las vistas no proporcionan una malla 3D: el volumen lateral se reconstruye
mediante perfiles anatómicos. Cara, cejas, iris/pupilas, nariz, barba, pelo,
manos con dedos y piernas son geometría; no se proyectan ojos sobre brazos.
Se ha retirado la marca azul anterior y los parches redondos del pantalón.

`survivor_model.gd` mantiene veinte huesos; `humanoid_rig.gd` adapta pesos de
hombro, piel, tela y proyección de las nuevas pinturas. La cabeza tiene volumen
mayor y el pie un ancho compatible con la referencia. El límite de cruce entre
pies usa este nuevo ancho. Se normaliza la altura visible a 1,75 m; una pequeña
transferencia de peso de hasta 1,5 unidades de autoría (~4 cm) permite alcanzar
contactos cercanos altos sin alargar huesos ni separar las manos del mango.
La armadura sigue el torso y conserva sus huecos para los brazos.

El joven se reconstruye en `young_model.gd` siguiendo
`entregables/enemigos/enemigo1_joven_3d.png`, importada en
`assets/enemies/first/reference_3d.png`. Tiene pelaje por capas, cresta y marcas
vegetales doradas, hocico con fosas nasales, ojos rojos con párpados, orejas,
marcas claras en las mejillas, colmillos, uñas, cola y puños de placas de piedra
biseladas. Las cuatro vistas definen las siluetas y detalles. La textura toma una zona
limpia de pelaje de la referencia; ojos, piedra y hocico no se duplican en la piel. Mantiene los
catorce huesos no humanos y toda su rutina: cuatro apoyos, incorporarse,
puñetazos alternos, comer, sentarse, stun, recuperación y muerte.

La zancada horizontal aumenta un 30%, conservando las velocidades de caminar y
correr (2 y 3,2 m/s). Un ciclo dura 0,78 s al caminar y 0,585 s al correr: 30%
más tiempo, aproximadamente 23,1% menos frecuencia. Brazos y piernas comparten
fase. El balanceo de brazos se reduce un 10%, manteniendo codos de 165° en
reposo y 75° en carrera. El apoyo del pie y la longitud de los huesos permanecen
constantes; la pelvis desciende solo lo necesario para alcanzar la zancada.

La cámara admite ambos polos verticales y guarda/restaura esos ángulos. La
recuperación de colisión converge a la distancia segura actual, evitando la
oscilación entre extensión completa y retracción que provocaba el parpadeo al
mirar arriba. Se reutilizan la esfera y su consulta física.

El HUD 3D tiene cinco niveles. El nivel 1 equivale al antiguo nivel 3. Como la
métrica elegida es superficie, el factor de cada eje es
`sqrt(0.56 * (1 + 0.10 * (nivel - 1)))`. Los niveles ocupan 100%, 110%, 120%,
130% y 140% de la nueva superficie base. El ajuste compartido del juego 2D
conserva su escala anterior; HUD y colocación de mesas 3D usan la nueva escala.

Comprobaciones específicas: `tests/prototype_3d_camera_gait.gd` reproduce la
colisión de suelo al mirar arriba y comprueba amplitud/cadencia/IK;
`prototype_3d_reference_models.gd` valida procedencia de imágenes, piel ligada,
poses finitas y las cinco escalas del HUD. El catálogo existente revisa todos
los estados/familias y dieciséis orientaciones de desplazamiento; la revisión
nativa añade vistas frontales y laterales en varias fases con/sin armadura.


## Objetos físicos y recursos compartidos

`item_models.gd` construye una vez y comparte mallas/materiales de las 21
categorías con referencia disponible. Hacha/pico/espada/arco/flecha reutilizan
la geometría de sus versiones en mano; la armadura, la malla de hojas; la mesa,
las mismas siete piezas y medidas que su versión colocada. Consumibles,
botella, palos, piedra, cuerda trenzada, bobina de hilo, bolsa de sal y láminas
curvadas de hojas/pieles conservan sus diseños. Las texturas de láminas y etiqueta
de sal usan sus dibujos importados con píxeles definidos, sin rectángulos de fondo.

`world_item.gd` muestra el modelo real con profundidad y sombras. Su zona de
selección se ajusta al volumen, con un mínimo para objetos muy pequeños. Es un
Area3D: el objeto tirado no bloquea al caminar. Al crearlo se apoya sobre la
superficie física bajo su posición; al cargar se conserva exactamente la
posición guardada, sin volver a buscar suelo. E, manos libres, animación de
recogida y reglas de mochila siguen compartidas con el botín.

Los estados de agua tienen recursos separados (vacía/250/500 ml); cantidad,
usos y uid permanecen en el registro individual. Variar el desgaste o tamaño
de una pila no crea nuevas mallas. Un modelo representa la pila completa,
sin multiplicar dibujos por cada unidad de material. Cuchillo, fibra, prendas
sin diseño y otros objetos no disponibles mantienen su marcador provisional;
no reciben un diseño inventado.

Revisión F6: `scenes/prototype_3d/item_review.tscn`, selector de objeto, botella
llena, giro con botón derecho y zoom con rueda. No concede objetos en partida.
`tests/prototype_3d_item_models.gd` verifica geometría, apoyo, caché, estados,
sombras y recogida; las pruebas de botín, mesa y guardado cubren su integración.


## Deslizamiento sobre una cadera

`slide_pose.gd` adapta el deslizamiento al Meshy Wild Wanderer. La entrada
transfiere el peso a la cadera izquierda; la pierna recogida abre la rodilla y
conserva una flexión de unos 70°, en lugar de plegar la pantorrilla contra el
muslo. La pierna derecha se adelanta con una rodilla suave. La pelvis se inclina
hacia atrás y el pecho se curva respecto a ella; los brazos libres se adelantan
con codos flexionados, y las manos ocupadas conservan sus agarres. La salida
recupera una postura baja y la mezcla al saltar conserva tórax y pelvis separados.

Referencias consultadas para la distribución de apoyos y la pierna flexionada:
[Baseball Canada: Sliding Fundamentals](https://www.baseball.ca/sliding-fundamentals)
y [Ficklin et al., comparación de técnicas de deslizamiento](https://pmc.ncbi.nlm.nih.gov/articles/PMC6188574/),
figura 1B. Se adapta esa mecánica al juego y a sus objetos equipados; es una
animación de autor con IK, no un clip de captura de movimiento.

No cambia `locomotion.gd`: duración 0,46 s, distancia, frenada, Control al correr,
salto en cualquier instante con inercia y giro máximo de 70° permanecen iguales.
La orientación visual acompaña la dirección real de deslizamiento y del salto,
aunque la cámara gire. El modelo conserva la última pose mostrada para iniciar
el salto desde ella; `Slide.jump_from` abre gradualmente las piernas y mezcla
cadera, manos, agarres y plano de la herramienta durante el primer 45% de salto.
Las rodillas tienen polos explícitos interpolados; no se alargan los huesos.

## Primer pulido de modelado: hombros y pelo (15 de octubre de 2026)

La inserción de los brazos añade secciones proximales y un perfil de deltoides
redondeado. El tórax cede su volumen lateral superior al brazo, evitando la
repisa de los hombros. El sombreado conserva planos discretos en los miembros
y suaviza esa unión; el pase de contorno descarta las raíces enterradas para
que no dejen caras negras coplanares sobre el pecho.

El pelo conserva la paleta y las referencias frontal/trasera: cubierta más
densa situada fuera del cráneo, nuca cubierta y mechones volumétricos más anchos,
de longitudes escalonadas y barrido irregular. Se conserva el esqueleto, las UV
en reposo, las proporciones y los agarres. No se modifican los PNG originales.

`tests/prototype_3d_hair_coverage.gd` lanza 33 rayos contra la geometría real para
detectar cuero cabelludo expuesto en la nuca, parte posterior y frente superior.
Complementa las pruebas de deformación, referencias, proporciones y armadura.
Revisión renderizada con Godot 4.7.2 Compatibility: cuatro orientaciones en
reposo y dos orientaciones en carrera, golpe y tensado de arco, con/sin armadura.

`tests/prototype_3d_slide.gd` comprueba postura central, longitudes, rodillas y
pies sobre suelo, agarres de todas las familias y continuidad de despegues al
principio, centro y final. Las pruebas de catálogo, movimiento y guardado
comprueban las integraciones existentes. F6 en `animation_review.tscn` permite
revisar slide/slide_jump con cada objeto y con armadura.

## Revisión conjunta de animación y modelado — 15 de octubre de 2026

Entregas revisadas juntas: animación `69a4d8f` y modelado `c99e19b`, ya presentes
en `prototype/third-person-3d`. Se ajustan las ataduras superiores de la armadura
al recorrido de los brazos. La selección del agarre de espada favorece una mano
adelantada, manteniendo el punto físico de impacto; el mango deja de acercar el
brazo al interior de la vestimenta. Se conservan el rig, las referencias y la
cobertura de hojas, sin cambiar la selección de agarres de dos manos.

La prueba de modelos conserva el límite de descenso de 3,8 unidades para golpes
altos. Los contactos bajos del nuevo catálogo requieren flexión: se comprueban
alcance, coincidencia de punta y contacto, y rodillas/pies sobre el suelo. La
holgura mínima de armadura sigue siendo 1,3 unidades, ahora muestreada en 33
fases por acción en lugar de ocho, incluyendo las fases intermedias de impacto.

Validación conjunta con Godot 4.7.2 en Linux/Compatibility: 23 suites superadas,
incluidas deformación humana, catálogo, pelo, superficie/UV, referencias, brazos,
cámara, deslizamiento, mira, equipo, arco, interacciones, botín, guardado,
movimiento, sistemas, criatura, árboles, integración general y modelos. Dos
de esas suites usan X11 y clics reales para inventario, menú, configuración y
guardar/continuar. Revisión visual de 16 capturas con/sin armadura en reposo,
golpe, arco, recogida y contacto bajo. La validación no incluye Windows ni una
medición de rendimiento en el ordenador del usuario.



### Piel de brazos sin líneas de la referencia

Los brazos dejan de usar la proyección XY directa de la fotografía: esa
proyección trasladaba su silueta oscura al interior de la piel curva. Cada
brazo recorre ahora sus propias franjas de piel frontal y trasera, con márgenes
interiores y UV fijas en reposo. Torso, piernas, geometría y contorno exterior
conservan su tratamiento. `tests/prototype_3d_arm_skin.gd` comprueba muestras
interpoladas y cuantizadas igual que el shader contra ambas imágenes originales.


## Enemigo1: modelo Meshy aportado por el usuario

Se retira la reconstrucción procedural y se sustituye por el FBX **Mossclaw
Boar** de la Release `modelo-enemigo1`. La versión vigente es el FBX reducido
`1016001519`, del ZIP `enemigo1_3d.zip`: **7340 triángulos**, frente a los
977782 anteriores. Se conservan las proporciones, UV y los PNG del archivo nuevo. El recurso nativo de Godot
se comparte entre enemigos y carga directamente, sin generar el pelaje al
iniciar la partida. Cada enemigo mantiene un esqueleto independiente de
quince huesos, incluida la cola, y una altura normalizada de **0,875 m**.

El FBX no incluye rig ni animaciones; se transfiere por interpolación de
triángulos la ligadura animada anterior, manteniendo los clips y anclajes
articulares. La punta de impacto del hocico se mide sobre la geometría nueva. La escena F6
`young_review.tscn` muestra la postura original en **Postura de referencia**,
las cuatro vistas y las acciones. Ver [YOUNG_3D.md](YOUNG_3D.md) para procedencia,
reproducción de la conversión y capturas del archivo importado.

## Hitboxes y alcance de golpes (16 de octubre de 2026)

Los golpes cuerpo a cuerpo, con manos libres o cualquier arma de contacto,
aceptan hasta 1 m horizontal desde el origen del personaje al punto seleccionado.
La altura admitida va desde 0,35 m bajo los pies hasta 0,35 m sobre la cabeza;
la aceptación del golpe ya no depende de que el solver de la animación alcance
exactamente ese punto. Las animaciones conservan sus límites anatómicos.
El arco conserva su vuelo y alcance de 100 m.

Las cápsulas de impacto de los troncos y las esferas de piedras y del joven
incluyen 0,15 m adicionales de radio. Los arbolitos pasan de 0,32 a 0,47 m de
radio de selección. Árboles y piedras tienen áreas de impacto independientes de
sus cuerpos sólidos; el espacio bloqueado al caminar y las copas que limitan la
cámara conservan sus dimensiones. Las áreas se desactivan al agotar el recurso.
Se mantienen herramientas requeridas, daños, recompensas y desgaste existentes.

`tests/prototype_3d_hitboxes.gd` comprueba el límite horizontal en dieciséis
orientaciones con/sin arma, límite vertical, selección fuera del volumen sólido
de una roca, paso libre y retirada de áreas al agotarla, así como hitboxes de
árboles y del joven.

## Separación entre criaturas (16 de octubre de 2026)

El joven usa la capa física de criaturas (`8`) y máscara `43`: suelo/estructuras,
jugador, otras criaturas y barrera de edificios. Su cilindro físico tiene
0,875 m de altura y un radio obtenido de la extensión horizontal máxima del
modelo respecto a su origen, multiplicada por **1,02**. Es una envolvente
circular estable al girar, no una colisión animada por extremidad; la separación
visible varía con la postura y el ángulo. El 2% se aplica a esta envolvente,
no a un número fijo de píxeles de pantalla.

El sondeo de obstáculos también incluye criaturas. El comienzo y el contacto del ataque admiten
la distancia de contacto con el nuevo cuerpo físico, para que no se detenga
fuera del umbral de ataque. Las hurtboxes ampliadas para recibir golpes siguen
siendo áreas independientes; un cadáver conserva la regla anterior de no
bloquear el paso. Nuevas criaturas deben compartir la capa `8` e incluirla en
su máscara para participar en esta colisión, además de dimensionar su cuerpo.

`tests/prototype_3d_creature_spacing.gd` comprueba convergencia de tres cuerpos,
bloqueo por una criatura detenida, sondeo para rodearla, inicio de ataque y
persecución real de tres jóvenes. Admite hasta 1 cm de tolerancia de contacto
del motor, inferior al margen nominal combinado de estos modelos.


## Respuesta de movimiento del superviviente (16 de octubre de 2026)

La cámara gira de inmediato y el personaje la sigue con un segundo de retraso.
Las acciones sobre la mira conservan su orientación hacia el contacto. Sprint
entra con una transición de 0,16 s y acelera hasta su máximo durante el segundo
siguiente. Al soltar Shift o el movimiento, frena durante 0,24 s hasta caminar,
quedarse quieto o caminar agachado. Se puede interrumpir y reiniciar en cualquier
fase. Los pasos y el balanceo acompañan la velocidad real.

Al deslizarse hacia atrás, la cadera lidera la retirada y el personaje sigue
mirando hacia delante, con las piernas en apoyos distintos y el torso recogido.
Ese recorrido es un 40 % menor; los demás conservan su distancia. El salto
levanta lentamente las manos y el arma o herramienta acompaña al agarre.
Los puñetazos alternan las manos; torso, cadera y pie del lado activo acompañan
cada golpe, también agachado. F6 incluye retirada y puñetazo izquierdo.
Se guardan la fase de sprint y la variante de retirada, con compatibilidad
para partidas anteriores. Detalles y referencias en `docs/ANIMATION_AREA.md`.

## Optimización de distancia (16 de octubre de 2026)

Texturas y mallas reducen su detalle por distancia y orientación de cámara,
con recuperación gradual al volver a mirar. Los enemigos se suspenden desde
150 m conservando su acción. Umbrales, implementación, comprobaciones y límites
en [DISTANCE_OPTIMIZATION.md](DISTANCE_OPTIMIZATION.md).


## Caché de sombreado y ciclos del enemigo (16 de octubre de 2026)

El terreno prepara sus máscaras por chunk y conserva el muestreo original del
detalle. Los ciclos repetitivos del enemigo usan keyframes compartidos con
subdivisión adaptativa, conservando la resolución de sus articulaciones y los
tiempos de las acciones. Método, límites y mediciones en
[SHADING_ANIMATION_OPTIMIZATION.md](SHADING_ANIMATION_OPTIMIZATION.md);
[capturas antes/después](previews/shading-animation-2026-10-16/README.md).
