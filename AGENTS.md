# Day Zero: regla visual permanente del usuario

## Acabado permanente de todas las texturas

Todas las texturas nuevas o adaptadas deben tener acabado pixel art de muy alta
resolución: píxeles definidos, paleta controlada y detalle moderado, sin acabado
fotográfico ni pinceladas borrosas. Incluye texturas generadas, adaptadas de
imágenes o sprites del usuario y sus versiones para modelos 3D, objetos e
interfaz. Esta indicación sustituye el acabado pintado suavizado de la primera
prueba 3D. Conservar contornos finos y usar muestreo que preserve los píxeles;
el tamaño grande de un atlas no justifica ruido ni exceso de contraste.

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

Usar las superficies continuas de `tools/continuous_actor.gd` y la cinemática de
`scripts/continuous_body_pose.gd` como base reutilizable para personajes y
enemigos. Los huesos mantienen su longitud; hombros y caderas permanecen dentro
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
pata de muebles y apoyos de edificios en coordenadas del dibujo, y reutilizar
`ground_contact_shadow.gd`; la hitbox no define el origen. Conservar la sombra
del personaje. Ver `docs/CREATURES_AND_SHADOWS.md` para parámetros y exportación.

## Registro de tiempos solicitado por el usuario

Registrar hitos y duración real de las tareas para informar cuando el usuario
lo pida y mejorar futuras estimaciones. Guardar los datos en
`docs/WORK_TIMES.md`; indicar alcance, comprobaciones incluidas, estimación
previa y duración medida. No inventar horas de inicio ni reconstruir como exactos
intervalos no registrados: marcarlos como parciales o estimados. Los informes
al usuario usan Europe/Madrid. El registro no sustituye terminar las tareas.


## Referencias vigentes de los modelos 3D

El superviviente usa ahora el FBX Meshy Wild Wanderer aportado por el usuario
en la Release `modelo_personaje3d`: `assets/characters/prototype_3d/meshy/source.json`.
La botella usa el FBX de la Release `modelo_botella_3d`:
`assets/items/prototype_3d/bottle_meshy/source.json`. El enemigo1 usa el FBX Meshy
Mossclaw Boar de `modelo-enemigo1`: `assets/enemies/first/meshy/source.json`.
Las peticiones de sustituir los modelos anteriores tienen prioridad: conservar
la geometría, proporciones, UV y PNG originales de esos archivos, sin
reconstruirlos con formas procedurales ni reproyectar las láminas antiguas.
Las pinturas de personajes y `entregables/enemigos/enemigo1_joven_3d.png` se
conservan como referencias históricas. Adaptar los rigs a los archivos
importados, manteniendo las alturas de 1,75 m/0,875 m. Los FBX no traen esqueleto
ni animaciones; las ligaduras añadidas integran las acciones del juego.
Ver `docs/MESHY_ASSETS.md` para regenerar el personaje y la botella.
