# Prototipo 3D de Day Zero

Rama `prototype/third-person-3d`; `main` conserva el juego 2D. Seleccionar esta
rama antes de descargar el ZIP, importar `project.godot` en Godot 4.7.2 y pulsar
F5. La escena inicial es `scenes/prototype_3d/day_zero_3d.tscn`.

## Incluido en esta integración

- Cámara sobre el hombro derecho: distancia 3,6 m, desplazamiento 0,60 m, FOV
  75°, sensibilidad 0,0025 rad/píxel, inclinación −60° a +65°. Una esfera evita
  atravesar paredes y copas. Movimiento relativo a la cámara.
- Superviviente estilizado de 1,75 m y 60 kg, delgado, con piel continua,
  articulaciones estables y pantalón holgado con inercia ligera. El esqueleto
  tiene veinte huesos, incluidos cuatro para los bajos de la tela.
- Atlas de alta resolución con acabado pixel art, paleta limitada y muestreo
  nearest con mipmaps. Ojos, barba y marca azul conservan el diseño original.
- Catálogo de 29 estados para manos libres y siete familias de objetos: caminar,
  correr, agacharse, deslizamiento, saltos, transiciones, equipar en movimiento,
  gestos de herramientas/armas, tensado, recogida, comer, beber, parry, daño y
  muerte. Las animaciones son continuas y se pueden revisar desde cualquier
  ángulo; no dependen de direcciones discretas de sprites.
- El hacha existente tiene volumen, dos agarres y alcance anatómico. El punto
  de mira se fija al iniciar el golpe y los brazos acompañan al mango. El
  pico y la espada también tienen volumen y contacto por la mira. El arco tensa
  durante seis pasos en 0,5 s, necesita una flecha y gasta un uso al tensar,
  incluso si se cancela; la flecha se consume únicamente al soltarla. Los rayos
  por segmento evitan atravesar objetivos entre fotogramas.
- Joven topo de 0,875 m, esqueleto propio de catorce huesos: cuatro apoyos al
  caminar/correr, levantarse para alternar puños, sentarse, comer de árboles,
  stun y muerte. Persigue al 85% de la caminata del jugador y deambula al 42,5%.
  Guarda la última posición vista y la investiga antes de volver a su rutina.
- Parry con ventanas de 0,5 s antes / 0,2 s después, daño diferido 0,35 s,
  enfriamiento 4 s y stun 1,5 s. Solo un bloqueo conseguido produce el pulso
  blanco alrededor de las manos. Indicador de stun circular reutilizable.
- HUD con vida, calorías, hidratación, peso, día/hora, nivel, mapa y seis huecos
  rápidos. Configuración integrada: correr automático y seis tamaños del HUD.
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
  60% durante 0,36 s y la recupera en 0,5 s. Al equipar se pierde un 5%, que se
  recupera progresivamente en 1 s. Se puede seguir caminando al sacar el objeto.
- Espada: 3 de daño y un uso solo al impactar; hacha/pico: 1 de daño, dos usos
  contra enemigo o recurso incorrecto y uno en su función correcta. El daño
  contra recursos solo lo hace la herramienta correspondiente. El arco hace 3
  de daño. La estela corta sigue la punta física de la espada.
- Muerte del jugador en 3 s y reaparición sin objetos ni perks, a nivel 1,
  conservando las habilidades desbloqueadas en su primer nivel.

Este es un prototipo en migración, no el juego 2D trasladado por completo. El
escenario de pruebas sigue siendo una superficie limitada de 48×48 m renderizada por chunks con cuatro
árboles, rocas, un charco y una pared; edificios, generación por chunks y otras mecánicas se
registran en [MIGRATION_3D.md](MIGRATION_3D.md).

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
permite terreno sin límite; el escenario conserva el límite del mapa 2D, 84×56 m.
Caminos y distribución de recursos se comparten con el generador original.

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

Pendiente: acabar los modelos del entorno, resto de objetos,
guardado 3D. El sistema del PDF sigue pospuesto hasta
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
generación completa, sin las antiguas muestras de cuatro árboles y cuatro rocas.


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
seleccionable con E; la representación del suelo es aún un icono 256² orientado
hacia la cámara, pendiente del modelo de cada material. La recogida usa manos
libres y la animación inclinada. `prototype_3d_loot.gd` cubre transferencia,
mochila llena, botella con contenido, contador y caducidad sin duplicaciones.

## Correcciones de modelos y puntería (15 de octubre de 2026)

El cuerpo conserva el mismo rig y la altura de 1,75 m. Los hombros tienen
casquetes biselados; las piernas, perfiles octogonales con rodilla, gemelo y
tobillo. El pelo usa una cubierta continua de mechones bajos y planos. En los
golpes el descenso de la pelvis se limita antes de resolver el alcance con IK,
para no sustituir el gesto de brazos por una sentadilla.

Los brazos libres al correr mantienen 75° interiores en el codo y un balanceo
máximo de 18° en el hombro, con entradas/salidas de 0,14/0,18 s. El brazo ocupado
por un objeto y ambos brazos con herramientas de dos manos conservan sus
agarres. La armadura comparte la transformación del torso: hojas dentadas,
nervaduras finas, ataduras trenzadas y huecos para que pasen los brazos.

Hacha, pico, espada y arco mantienen los mismos anclajes de agarre/contacto,
con madera segmentada y superficies de piedra biseladas. El pico toma la
silueta de `entregables/herramientas/pico1_3d.png`: mango doble, contrapunta ancha
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
