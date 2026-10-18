# Day Zero: regla visual permanente del usuario

La rama de integración vigente es `main` y contiene el juego 3D.
El runtime 2D ha sido retirado; conservar los sprites y sistemas compartidos
que se detallan en `docs/SHARED_RESOURCES.md`. Actualizar las ramas de departamento
antes de trabajar para evitar restaurar archivos obsoletos.

## Autorización de publicación de animación

El usuario autoriza al departamento de animación a crear commits y hacer push
a `main` de sus futuras entregas dentro del alcance solicitado, sin pedir otra
confirmación de publicación. Actualizar primero la rama remota, conservar el
trabajo de los demás departamentos, resolver los conflictos de integración y
realizar las comprobaciones pertinentes antes de publicar. Actualizar también
la documentación de parámetros cuando corresponda, sin añadir informes ni
registros de cambios. Esta autorización del usuario no sustituye las
credenciales ni los permisos técnicos exigidos por GitHub o por el entorno.

## Acabado permanente de todas las texturas

Todas las texturas nuevas o adaptadas deben mantener el estilo visual actual
del juego. La referencia principal de acabado es el enemigo3 Sunny Sprout,
sus materiales en `assets/enemies/third/sprout/` y su apariencia dentro del juego.
El estilo es fantasía 3D estilizada con acabado pintado: formas orgánicas
legibles, colores armonizados, variaciones de tono suaves y detalles de
superficie definidos y limpios. El enemigo3 combina amarillos cálidos, crema,
verdes vegetales y marrones; usarlo como referencia de tratamiento y calidad,
adaptando la paleta al material y la identidad de cada personaje u objeto.

La textura debe acompañar el volumen y distinguir piel, pelo, hojas, tela,
madera o piedra mediante color, rugosidad y relieve moderado. Se permiten mapas
de normales y otros mapas de material para aportar detalle fino sin aumentar
innecesariamente la geometría. Mantener transiciones cuidadas, costuras UV
discretas y rasgos propios como cicatrices, ojos y expresión de la boca.
Evitar ruido, manchas de material incorrecto, contrastes excesivos y relieve
que deforme visualmente las facciones. El resultado debe leerse bien tanto
de cerca como a la distancia habitual de juego.

Esta referencia sustituye la exigencia anterior de pixel art, incluso donde
queden menciones antiguas: no imponer pixelado visible ni reducir la paleta
para simularlo. Elegir resolución, filtrado y mipmaps para reproducir el acabado
de referencia con nitidez y estabilidad, sin escalones artificiales ni pérdida
de detalle por desenfoque. Se aplica a texturas generadas, adaptadas de imágenes
o sprites y destinadas a modelos 3D, objetos e interfaz. Conservar las reglas
de contornos finos y las excepciones de interfaz indicadas a continuación.

El superviviente 3D representa un hombre estilizado de 1,75 m y 60 kg, delgado,
con articulaciones identificables y definición anatómica discreta. Compartir
anatomía y pesos de piel en todas las animaciones. La tela holgada acompaña las
piernas con inercia pequeña. Cada golpe tiene preparación, acción, retroceso y
recuperación. El golpe apunta al punto de mira fijado al iniciarlo, con alcance
limitado por brazos y herramienta. Las nuevas herramientas usan los anclajes
del catálogo de poses, sin duplicar o separar brazos del cuerpo.

Todos los dibujos del juego deben usar contornos tan finos como los del personaje principal. Se aplica a personajes, animales, árboles, rocas, césped, objetos, armas, armaduras, materiales y a sus representaciones en inventario, fabricación, reparación y cualquier interfaz o mecánica futura. No incorporar nuevos dibujos con bordes gruesos. Excepción de interfaz solicitada por el usuario: los marcos de ventanas y botones tienen un contorno cuatro veces más grueso, manteniendo sus rectángulos, zonas de clic y adornos originales.

El grosor de referencia es un píxel de la rasterización del personaje completo (192×192 por celda, ~1,5 píxeles de raster por unidad del mundo). El contorno escala con el dibujo y el zoom; no mantiene un ancho fijo en pantalla. Usar `scripts/visual_style.gd` para normalizar dibujos e iconos. La exportación del personaje y sus herramientas debe compartir esta política, evitando añadir dos contornos consecutivos. Eliminar solo el borde oscuro exterior grueso; preservar sombreado y detalles interiores.

Las herramientas no deben dibujarse a través del torso o la cabeza al mirar hacia arriba o hacia los lados. Los agarres y los brazos deben seguir visibles donde corresponda. Validar la oclusión en los fotogramas completos exportados, no únicamente en el rig antiguo.

Si una decisión visual o de comportamiento no está especificada, presentar opciones al usuario antes de escogerla. Las decisiones de implementación que cumplen el resultado ya definido no necesitan consultas repetidas.

## Animación y anatomía compartidas

Usar los modelos y rigs de `scripts/prototype_3d/` y la cinemática de
`scripts/continuous_body_pose.gd` como base reutilizable para personajes y
enemigos. El runtime y los exportadores de sprites 2D se han retirado. Los huesos
mantienen su longitud; hombros y caderas permanecen dentro
del torso, y piel, manos, pies y ropa acompañan sus articulaciones. Las fases de
apoyo y transferencia se comparten mediante `stance_swing`; el número de patas y
la postura deben corresponder a la criatura. El joven camina sobre cuatro patas
y se levanta solo para sus puñetazos alternos.

Orientar las herramientas a partir de sus puntos reales de agarre y de su plano
de corte, de forma continua durante reposo, preparación, impacto y recuperación.
No solucionar una orientación incorrecta con inversiones aisladas de frames o
direcciones. La estela de la espada debe tomar la punta exportada en cada sprite.
Revisar todas las direcciones y poses completas, también con armadura; validar
agarres, oclusión, márgenes y continuidad antes de publicar los atlas.

## Fabricación y vestimenta

Toda herramienta o arma nueva que no sea básica necesita como mínimo una mesa
de fabricación básica y no debe aparecer en Crear desde el inventario. Marcar
las básicas mediante `basic_tool`; el requisito se comprueba también al fabricar,
no solo en la interfaz. Las recetas de mesa deben respetar los desbloqueos.

Conservar las líneas negras interiores finas de ramas, troncos y separaciones
de hojas, tomando las ramitas como referencia. Normalizar el contorno exterior
no debe borrar esas líneas ni aumentar su grosor.

Las armaduras normales acompañan la transformación completa del torso; la de
hojas cubre pecho, abdomen, espalda y hombros, dejando abierto el cuello. No
recortar la cobertura a una pequeña pechera.

## Criaturas y contactos de sombra

Cada criatura nueva debe tener un perfil propio y separar decisiones, física y
exportación de sus sprites completos. Reutilizar articulaciones continuas e IK;
conservar anatomía y proporciones en las dieciséis direcciones. El joven camina
sobre cuatro patas, se sienta en el suelo y se alza para atacar.

Las sombras de objetos parten del contorno visible de sus apoyos. Declarar cada
pata de muebles y apoyos de edificios en coordenadas del dibujo, y usar sus
apoyos físicos 3D; la hitbox no define el origen visual. Conservar la sombra
del personaje. Ver `docs/YOUNG_3D.md` y `docs/PROTOTYPE_3D.md` para el runtime vigente.

## Zonas fijas de historia

`data/world/story_zones.json` define las coordenadas, recintos y márgenes de
las zonas de historia. Los generadores nuevos de recursos, poblados y caminos
deben consultar `story_zone_catalog.gd` antes de colocar su huella completa;
no basta con comprobar el centro. Conservar los IDs de zonas y elementos al
sustituir las cajas por contenido definitivo. Ver `docs/FIXED_STORY_ZONES.md`.

## Documentación del proyecto

Mantener solo información vigente: dimensiones, velocidades, comportamiento,
controles, reglas, configuración y recursos actuales. No añadir registros de
cambios de departamentos, tiempos de trabajo, informes de pruebas, métricas
comparativas ni capturas de revisión al repositorio. Las verificaciones y
archivos temporales quedan locales. Actualizar los valores documentados cuando
cambie su definición en el código. No recrear WORK_TIMES.md ni galerías de
informes; las imágenes generadas de docs/previews están excluidas de Git.

## Referencias vigentes de los modelos 3D

Consultar `docs/MESHY_ASSETS.md` y los manifiestos source.json de assets para
la fuente actual de cada modelo. Conservar los FBX, PNG, UV, geometría y rigs
originales; adaptar las animaciones a ellos sin reconstruir sus siluetas.

- Superviviente: Rugged Castaway 1017215425, 31182 triángulos, 1,75 m,
  24 huesos con tela y volumen de articulaciones. Mantener skin_seams_v1 y
  face_materials_v1 (máscaras de pelo/barba y relieve facial sutil);
  regenerar mediante transferencia de piel, no con ligadura automática.
  El runtime muestra survivor_axilla.res, con soporte local del sobaco; conservar
  survivor_skin.res como fuente y regenerar según docs/ANIMATION_SYSTEMS.md.
- Enemigo1: Mossclaw Boar 1016001519, 4036 triángulos de superficie, 0,875 m,
  25 huesos originales SmartRigArmature de modelo1_rig. Mantener jerarquía,
  ejes de reposo y ligadura original, con pesos interpolados en la superficie
  reducida. Fuente intacta de 7340 triángulos; relieve horneado en normal de
  2048 px. Animaciones nativas compartidas en rig/.
- Enemigo3: Sunny Sprout de entregables/enemigos/enemigo3/modelo_enemigo3.fbx,
  13582 triángulos y 35 huesos originales. Altura de partida 0,9 m. K permite
  añadirlo con patrulla de veinte metros por tramo y ciclo de carrera de
  10/20/40 s, con descansos de 5 s entre modalidades; la última incluye pausas
  de 2 s cada 8 s corriendo. Velocidad de carrera diez veces la marcha y
  torso/cabeza inclinados 60 grados. Sin objetivos reales, combate ni aparición
  automática. Guardado en sprouts; no mezclar prototype_sprouts con el joven.
- Hacha y pico: model_scale 0.6, grip_bottom −4 y palmas separadas 4,95 unidades.
  Usar assets/models/meshy/{axe,pickaxe}/anchors.gd sin duplicar la escala.
- Botella, arco y armadura: conservar sus fuentes Meshy, anclajes y materiales;
  la armadura acompaña torso y articulaciones y el arco deforma su cuerda nativa.
- Roca1: Wild Wanderer 1016215008 de modelo_roca1_3d/piedra1_3d.zip,
  5163 triángulos y altura única de 1 m, sin variantes de escala.
  Los afloramientos se minan con pico. Conservar IDs, posiciones, resistencia
  y rendimientos para cargar partidas existentes.

## Bases reutilizables

Consultar `docs/REUSABLE_SYSTEMS.md`. Definir nuevos terrenos mediante recetas
y perfiles de `data/world/`; reutilizar los generadores y comprobar las reservas
completas de historia. Mantener separados los perfiles de animación de Personajes
y Enemigos en `data/animation/characters/` y `data/animation/enemies/`, usando
las herramientas de `scripts/animation/shared/`. Conservar las fuentes originales
y revisar las adaptaciones de clips antes de incorporarlas al runtime.
