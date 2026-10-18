# Animación de Personajes y Enemigos

## Personajes

`scripts/animation/characters/humanoid_profile.gd` define la anatomía humanoide
compartida. `data/animation/characters/survivor.tres` describe los 24 controles
históricos de contactos y ropa, sin una malla visible. El cuerpo del jugador
usa `survivor_native.tres`: los **66 huesos originales** de
`psnj1_3d_rigged.fbx`, con referencia en T y pesos propios. Su escena está en
`assets/characters/prototype_3d/composite/model.scn`.

`native_survivor.gd` enlaza ese rig mediante `RigBinding` y aplica las poses
mediante `SkeletonPose`. Conserva las longitudes y ejes nativos; usa los planos
articulares compartidos para orientar brazos y piernas. Las curvas existentes
siguen proporcionando ritmo, cuerpo y contactos. Las extremidades libres
adaptan su alcance a las proporciones nuevas; las manos ocupadas resuelven IK
hacia los contactos, incluyendo proyección de clavículas y el centro real de
la palma. El lado 0 de los controles corresponde a Right del rig suministrado;
el lado 1 a Left. Los dedos originales acompañan los agarres. El modelo y el retrato
comparten la malla y los binds inmutables, con esqueletos independientes.

La cabeza aprobada conserva sus UV, normales, tangentes, máscaras y materiales.
Se liga a Neck/Head del rig nuevo. Dos contornos del cuello se unen con
triángulos conformes y los mismos pesos en sus bordes; el color de transición
procede de ambas fuentes. No superponer dos cuellos ni dejar una cabeza rígida
separada del cuerpo. La referencia completa mide 64 unidades de autoría y se
convierte a 1,75 m; consultar `author_bounds()` para encuadrar o escalar instancias.

La parte posterior de cada rodilla conserva volumen mediante los correctivos
`KneeFoldRight` y `KneeFoldLeft`, evaluados en GPU antes de la ligadura.
Se limitan a la piel posterior en un radio longitudinal de 0,13 m, con
un desplazamiento máximo de autoría de 0,08 m y caída cosenoidal suave.
El peso por pierna es `sin(flexión/2)^2`, atenuado de forma continua entre
115° y 145° para respetar el contacto muslo/pantorrilla al arrodillarse.
Se calcula desde la flexión real en todas las acciones, sin cambiar la pose
de reposo, huesos, pesos originales, UV ni geometría de cabeza y cuello.
Las instancias comparten la malla; sus dos pesos correctivos son independientes.

Las fuentes originales y `approved_head_source.glb` están en
`entregables/personajes/personaje1/source/`, excluidas de importación automática.
La instantánea de cabeza conserva la aprobación anterior y permite regenerar
sin depender de cambios posteriores del donante de sobacos. Para preparar la
composición desde la raíz, con Blender 4.3+ y Godot 4.7:

```sh
blender -b -t 6 --python tools/meshy/build_composite.py -- \
  entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx \
  entregables/personajes/personaje1/source/approved_head_source.glb \
  /tmp/survivor-composite/composite.glb
cp /tmp/survivor-composite/body_albedo.png assets/characters/prototype_3d/composite/body_albedo.png
godot --headless --editor --path . --import
godot --headless --path . --script tools/meshy/bake_composite.gd -- /tmp/survivor-composite/composite.glb
godot --headless --path . --script tools/animation/characters/bake_native_ground.gd
```

La preparación compara jerarquía, ejes de reposo y binds con una exportación
independiente del FBX nuevo. `rig.json` y `source.json` contienen los parámetros
vigentes. El apoyo durante la caída reutiliza `SkinGround` con un conjunto
horneado de puntos reales de las tres superficies; no recorre la malla completa
durante el juego. Si cambian las curvas de control, regenerar también estos
apoyos nativos. No transferir los pesos antiguos del cuerpo al rig en T.

## Enemigos

`scripts/animation/enemies/enemy_profile.gd` declara una familia de locomoción,
huesos por función, cadenas de tres o cuatro articulaciones y fases de apoyo
para marcha/carrera. No presupone que todos los enemigos tengan el mismo número
de patas o una anatomía humanoide. Los recursos `enemy1.tres` y `enemy3.tres`
describen sus rigs originales, respectivamente cuadrúpedo y bípedo digitígrado.

Los generadores de animación de ambos enemigos usan `RigBinding` para medir
extremidades y resolver IK. Los perfiles controlan sus fases de apoyo; los clips
bakeados existentes y sus velocidades siguen siendo los del runtime. No se
regeneran automáticamente al modificar un perfil de autoría.

## Núcleo compartido

- `rig_profile.gd`: mapa entre funciones anatómicas y nombres originales; valida
  huesos presentes, cadenas y dimensiones.
- `rig_binding.gd`: captura padres, transformaciones de referencia, longitudes y
  offsets una sola vez. `solve_metres` usa las tolerancias del solver actual para
  rigs en metros; el rig humanoide mantiene su solver en unidades de autoría.
- `skeleton_pose.gd`: convierte poses globales a locales reutilizando una inversa
  por padre. La entrada antigua de `prototype_3d/` mantiene compatibilidad.
- `animation_retargeter.gd`: adapta rotaciones de un clip usando funciones
  anatómicas y ejes de referencia, creando un `Animation` separado.

La adaptación requiere ambos rigs en su pose de referencia. Conserva duración,
loop, tiempos e interpolación; cambia nombres de pistas al esqueleto destino.
El movimiento de raíz es opcional y escala con la altura de referencia. Las
traslaciones de extremidades y las escalas no se copian para evitar estiramientos.
Tampoco se transfieren automáticamente expresiones faciales, eventos, sonido,
trayectorias de armas ni huesos sin una función equivalente.

La transferencia automática exige la misma categoría y familia. La API permite
un override explícito revisado para transferencias parciales entre familias;
no convierte por sí sola una marcha cuadrúpeda en una bípeda. Si el destino mira
hacia otro eje, proporcionar una base de alineación a `configure`. El resultado
es una base editable: revisar apoyos, silueta, límites articulares y agarres antes
de publicarlo. Los FBX, UV, skin y jerarquías originales permanecen intactos.

## Herramienta de adaptación

```sh
godot --headless --path . --script res://tools/animation/retarget_clip.gd -- \
  --source-scene res://assets/enemies/first/rig/model.scn \
  --target-scene res://assets/enemies/first/rig/model.scn \
  --source-profile res://data/animation/enemies/enemy1.tres \
  --target-profile res://data/animation/enemies/enemy1.tres \
  --animation res://assets/enemies/first/rig/motions.res \
  --clip walk --output user://adapted_walk.res
```

Para otro modelo compatible, sustituir la escena y el perfil de destino. El
archivo de entrada puede ser un `Animation` o una `AnimationLibrary` con `--clip`.
La herramienta necesita un solo esqueleto por escena y escribe un archivo nuevo;
no reemplaza las fuentes ni incorpora el resultado al catálogo del juego. Informa
las pistas omitidas para que el departamento complete lo específico del modelo.

## Curvas del superviviente

`assets/characters/prototype_3d/motion/controls.res` contiene curvas nativas
compartidas para marcha, carrera, salto, ocho deslizamientos, caída frontal y
los golpes de hacha, pico y espada. Se interpolan controles de cuerpo, manos,
apoyos y esfuerzo; las extremidades se resuelven después con las longitudes
del rig. La mira sigue resolviendo el contacto real y los agarres del objeto.
No se interpolan escalas de brazos, piernas, cabeza ni cuello.

La reducción de claves usa límites de error de 0,018 unidades para posiciones
y 0,0004 para ángulos y pesos de mezcla. Conserva las fases de contacto, impacto,
entrada y salida, además de los extremos del ciclo. Las pistas constantes
usan una sola clave. Los datos de autoría no se evalúan durante el juego.
El reloj base usa el desplazamiento horizontal real en coordenadas del modelo.
La marcha erguida usa semizancada de apoyo de 8,8 unidades, contacto frontal
del 25 % y elevación máxima de 2,8 unidades, definidos en `gait_parameters.gd`.
La distancia efectiva por ciclo es `2 * 8.8 * (1.75 / 64) / 0.25`, 1,925 m:
a 2 m/s dura 0,9625 segundos, unos 2,08 pasos por segundo. El retorno de la
pierna ocupa el 75 % del ciclo frontal, con aceleración continua y aterrizaje
suave. El reloj conserva esta duración también en diagonales y laterales;
la amplitud y el tiempo de contacto se ajustan juntos a cada dirección para
mantener la velocidad del pie apoyado respecto al terreno. La altura de apoyo
ronda 29,8 unidades y el objetivo nativo se centra bajo su propia cadera,
con entrada y salida suavizadas. La marcha hacia delante y de lado es de 2 m/s. Hacia atrás y en ambas
diagonales traseras es el 30 %, 0,6 m/s, con frenada progresiva; la marcha
agachada conserva el mismo factor direccional respecto a su avance frontal.
La carrera mantiene su máximo propio. El reloj de animación sigue la distancia
real también a estas velocidades, sin reducir dos veces la amplitud del paso.
La marcha agachada conserva su curva propia `crouch_walk`, su distancia base
`1.56 * 0.68 * lerp(1, 0.44, abs(direccion.x))` y sus apoyos del 60–45 %.
El reloj mezcla ambas distancias durante la transición de postura y conserva
`GAIT_PLAYBACK_RATE = 0.90`. La escala de autoría es
`GAIT_STRIDE_LENGTH = 1.10`. La carrera usa los parámetros compartidos de
`gait_parameters.gd`: semizancada de apoyo de 7,8 unidades, contacto frontal
del 22 % del ciclo y elevación máxima de 5,6 unidades. El ciclo recorre
`2 * 7.8 * (1.75 / 64) / 0.22`, aproximadamente 1,939 m. Su reloj sigue la
distancia real con `RUN_PLAYBACK_RATE = 1.0`; la transición mezcla el reloj
de marcha y el de carrera. A 4,48 m/s son unos 4,62 pasos por segundo.
La carrera adapta la duración del contacto al recorrido lateral, conservando
la velocidad relativa del apoyo. La recuperación horizontal usa aceleración
continua, con liberación del pie, avance y entrada al siguiente apoyo. El
retorno vertical es C2 y las claves cercanas al contacto se conservan al reducir
las curvas. La altura de apoyo de carrera ronda 29,8 unidades, sin añadir
rebote a la pelvis. El rig nativo centra el apoyo bajo sus propias caderas y
mantiene un margen de suela de 0,30 unidades. La velocidad física no cambia.
Las calles de apoyo dejan espacio para la trayectoria completa antes de resolver IK, sin recortar su
mitad interior. El pie levantado regresa en el sentido real de desplazamiento.
El paso lateral usa `LATERAL_STEP_SCALE = 0.45` y
`LATERAL_LIFT_SCALE = 0.40`: reduce apertura y elevación de la pierna para
recoger el paso bajo la cadera y evitar tirones del pantalón. Entra suavemente
al pasar de diagonales de 45° al desplazamiento lateral puro, sin cambiar
la cadencia global ni la velocidad física.
La altura de apoyo calcula el alcance de ambos extremos del paso completo.
En marcha y carrera erguidas, `GAIT_LOWERING = 0.15` conserva solo el 15 % del
descenso total anterior, incluido el rebote y la compensación de alcance.
Las rodillas se resuelven con longitudes constantes y los objetivos de pie
limitan suavemente el alcance horizontal a la altura de la suela, evitando
alargar huesos o levantar los apoyos para alcanzar una zancada imposible.
La marcha agachada mantiene su altura propia. Los golpes erguidos comparten
esta corrección de altura y el límite horizontal de alcance de los pies antes
de resolver el contacto del arma. Los golpes agachados conservan su postura;
los objetivos bajos pueden necesitar una bajada adicional para alcanzarlos.
Durante los golpes cuerpo a cuerpo la velocidad se multiplica por 0,50, además
de desactivar el sprint. La entrada tarda 0,08 s y la recuperación ocupa los
últimos 0,12 s del gesto, con interpolación suave; no cambia el tiempo del golpe
ni la velocidad normal de marcha/carrera. El arco conserva su comportamiento.
El balanceo y giro base usan `GAIT_HIP_MOTION = 0.45`; después de resolver
la postura completa, `GAIT_HIP_REDUCTION = 0.40` conserva el 40 % del
desplazamiento final de pelvis alrededor de su altura de apoyo habitual
y de sus giros respecto a la inclinación
media del torso. Se aplica también a la oscilación vertical y de inclinación
de carrera, sin alterar el reloj de las piernas.
Al caminar, la pelvis mantiene un giro leve opuesto al de la espalda visible;
los contactos conservan un balanceo suave de 0,004 rad. El brazo libre opuesto
a la pierna que recupera inicia un pequeño gesto del codo hacia atrás, con
0,10 rad de amplitud; antebrazo y muñeca lo siguen 0,025 s después al ritmo
nominal de cada dirección. La muñeca añade solo 0,025 rad de giro. Las manos
ocupadas mantienen sus agarres y la carrera mantiene su gesto propio.
La piel visible de la pelvis conserva el 40 % de su deformación anterior
respecto al hueso de cadera. `hip_skin.gd` mezcla el 60 % restante hacia ese
hueso en la cintura (34,5–36) y la zona posterior de glúteos (31,5–36).
La cintura entra suavemente entre 32,7–34,5; el apoyo posterior entre
27,5–31,5 y se desvanece hacia el frente entre z=1,2–3,4. Ambos terminan
suavemente entre alturas 36–40. Usa transiciones C2. El cuádriceps frontal
por debajo de la articulación de cadera conserva sus pesos originales de muslo;
no se fija a la pelvis ni recibe una segunda flexión en mitad del músculo.
La malla GPU se prepara una sola vez y se comparte: no se recalculan vértices
durante el juego. Conserva los vértices de reposo, UV, materiales, morfos de
rodilla y ligaduras originales de las fuentes; solo la copia de pesos de la
piel visible recibe esta corrección. Cabeza, cuello y zonas exteriores no cambian.
La ligadura nativa conserva ejes y longitudes: las piernas usan giro desde el
reposo sin copiar la torsión axial del rig de contactos al pantalón.
El brazo libre de espada usa `SWORD_BALANCE_MOTION = 0.80`, proporciones nativas
y dedos relajados; su objetivo es de equilibrio, sin fijarlo a un contacto
de herramienta ni forzar la clavícula para alcanzarlo.
La caminata separa las rodillas un 10 % mediante el plano de flexión de cada
pierna, con `WALK_KNEE_SPREAD = 1.10`. Conserva pies, cadera y longitudes de
muslo/pantorrilla; limita el ajuste al círculo alcanzable de la articulación.
Añade `WALK_LEAN = 3°` hacia delante: `Spine` aporta 1,2° (40 %),
`Spine1`, `Spine2` y `Neck` aportan 0,6° cada uno. La cabeza sigue los 3°
acumulados del cuello. La entrada/salida se suaviza y se reduce con la velocidad
visual y la transición a carrera. La marcha agachada mantiene su postura propia.
La carrera aplica la misma separación de rodillas. Añade 0,8° a cada aporte
de inclinación de caminata: `Spine` 2°, `Spine1` 1,4°, `Spine2` 1,4° y
`Neck` 1,4°, para `RUN_LEAN = 6,2°`. La cabeza acompaña al cuello; la mezcla
marcha/carrera interpola los aportes por hueso junto con el peso de sprint.
El torso acompaña las diagonales con hasta 20° de giro adicional, repartidos
acumulativamente al 25/60/100 % entre los tres huesos de la espalda.
Las diagonales de retirada invierten el giro respecto a las de avance del
mismo lado, manteniendo la orientación frontal. El giro desaparece suavemente
al acercarse a una dirección cardinal o al detenerse, con respuesta exponencial
14/s, velocidad de giro máxima de 120°/s y el filtrado direccional de los pasos.
La pelvis conserva su postura y la cabeza mantiene la orientación de mirada con compensación en el cuello.
La columna visible distribuye la rotación total entre `Spine`, `Spine1` y
`Spine2` con pesos acumulados de 25 %, 60 % y 100 %. En locomoción añade un giro
total de 2° hacia la pierna que recupera y deprime suavemente la clavícula del
mismo lado hasta 2°; los brazos libres acompañan esa bajada y las manos ocupadas
conservan sus contactos. La intensidad sigue la velocidad visual al arrancar y
frenar. En el resto de gestos se distribuyen las rotaciones ya existentes entre
pelvis y pecho, sin sumar el giro cíclico a una caída o un reposo.
Las pistas `spine` y `shoulders` comparten el reloj y la reducción de claves
con marcha/carrera, con error angular/peso máximo de 0,0004.
Los dedos nativos de pico, hacha y espada envuelven el mango con pulgar opuesto,
conservando la longitud de cada falange. El cierre usa el peso de equipamiento
y el de la mano de apoyo. `data/animation/characters/hand_grips.tres` contiene
las secciones medidas y las orientaciones de palma relativas a cada mango;
se regenera con `bake_grips.gd`. Esa orientación estable evita inversiones del
agarre al cambiar el plano del golpe. La geometría
de herramientas se consulta únicamente en esa herramienta de autoría.
El apoyo de marcha/carrera rueda suavemente de talón a planta y despega por
los dedos: −0,05/+0,085 rad caminando y −0,035/+0,085 rad corriendo. La bajada
del pie usa un arco vertical C2 con velocidad y aceleración nulas al contactar;
conserva el recorrido horizontal, la altura máxima y la cadencia. La rodilla
acompaña la descarga progresiva del tobillo, con longitudes óseas constantes.
Los pies suavizan la entrada durante 0,15 s; el ciclo posterior sigue las claves
sin un filtro acumulativo que retrase el contacto. Los giros de marcha y carrera
comparten el suavizado de dirección de 0,12 s.

La caída de 3 s apoya primero las rodillas y termina boca abajo, con brazos y
piernas abiertos. Un conjunto reducido de apoyos de la piel real mantiene el
contacto con el suelo, incluyendo interrupciones desde posturas bajas.

La superficie `meshy/survivor_axilla.res` se conserva como donante del
sistema de autoría de contactos y para sus verificaciones históricas. No es la
malla visible del jugador. Sus bucles del sobaco y 24 controles pertenecen a
ese sistema. `build_axilla.gd`, `bake_controls.gd` y `bake_ground.gd` regeneran
esos recursos cuando cambia la autoría compartida; después de cambiar curvas,
regenerar también `bake_native_ground.gd`. No reemplazar la composición visible
por ese donante ni reconstruir su cabeza aprobada desde él.

Referencias de autoría: [marcha](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/),
[carrera](https://www.animationmentor.com/blog/animating-dynamic-run-cycles/),
[salto y aterrizaje](https://www.animationmentor.com/blog/tutorial-animate-a-jump-and-land/),
[deslizamiento sobre cadera](https://www.littleleague.org/university/articles/backyard-tips-sliding-tip/),
[mecánica de hacha](https://www.fs.usda.gov/t-d/pubs/pdfpubs/pdf18232812P/Part11a_UsingAnAx.pdf),
[golpes de herramientas](https://mocaponline.com/blogs/mocap-news/survival-game-animation-guide)
y [espada](https://www.animationmentor.com/blog/tutorial-animate-sword-fights-battle-sequences/).
Los movimientos se adaptan al rig y los tiempos de juego; no se incluyen clips
comerciales de terceros.
