# Referencias de anatomía

Las referencias consultadas para los límites articulares fueron [Arm26 de OpenSim](https://github.com/opensim-org/opensim-models/blob/master/Models/Arm26/arm26.osim) y [Gait2392](https://github.com/opensim-org/opensim-models/blob/master/Models/Gait2392_Simbody/gait2392_thelen2003muscle.osim). Son modelos biomecánicos, no medidas exactas del personaje.

El runtime actual utiliza modelos y esqueletos 3D con IK continuo.
La base matemática compartida permanece en `scripts/continuous_body_pose.gd`;
los exportadores de sprites y su runtime 2D se han retirado.

## Primera revisión de deslizamiento 3D — 15 de octubre de 2026

El usuario eligió deslizamiento sobre una cadera, con una pierna extendida y la
otra flexionada. `scripts/prototype_3d/slide_pose.gd` implementa esa postura con
IK de longitudes constantes y transfiere la pose al salto. Esta implementación
es una primera aproximación anatómica; **no se ha contrastado todavía con un
vídeo, una secuencia fotográfica o mocap real de un deslizamiento**.

Se intentó consultar Little League y la página de Slide (baseball) de Wikipedia;
el proxy rechazó esos dominios con 403 antes de obtener su contenido. La búsqueda
en GitHub fue accesible, pero no proporcionó una referencia útil verificada. Se
ha guardado el borrador de red con los dominios de Little League y Wikimedia,
pendiente de publicación. No citar esas fuentes como consultadas ni dar por
terminada la parte de investigación visual hasta poder examinarlas.

## Revisión del superviviente 3D — 15 de octubre de 2026

Fuentes descargadas y examinadas durante esta revisión:

- [Arm26, OpenSim](https://github.com/opensim-org/opensim-models/blob/master/Models/Arm26/arm26.osim): segmentos brazo/antebrazo y articulación de codo con flexión 0–130°. Es un modelo simplificado; sus límites no describen todos los movimientos de una persona.
- [Gait2392 Millard, OpenSim](https://github.com/opensim-org/opensim-models/blob/master/Models/Gait2392_Simbody/gait2392_millard2012muscle.osim): organización y sentido de flexión de cadera, rodilla y tobillo.
- [Caminata subject01_walk1, cinemática inversa](https://github.com/opensim-org/opensim-models/blob/master/Pipelines/Gait2392_Simbody/subject01_walk1_ik.mot): 211 muestras, 0,5–4 s. Cadera derecha −22,32° a 21,91°, rodilla −70,26° a 1,01° según sus ejes y tobillo −7,90° a 17,95°. Contraste de apoyo y avance; **no se importó el clip ni se copiaron sus valores literalmente** sobre el personaje estilizado.
- [Ejemplo BVH de bvh-python](https://github.com/20tab/bvh-python/blob/master/tests/test_freebvh.bvh): contraste de jerarquía de esqueleto y canales. El archivo no identifica la acción; no se presenta como una caminata ni un deslizamiento verificados.
- Referencias visuales del usuario: `entregables/personajes/personaje1_frente.png` y `personaje1_espaldas.png`. No se alteran los originales.

GitHub fue accesible. Wikipedia y Little League siguieron devolviendo 403 del
proxy. Esta revisión no añade una referencia audiovisual real de deslizamiento,
golpeo o consumo; esas acciones continúan siendo animaciones de autor, con
cinemática comprobada. Las pruebas numéricas no certifican parecido idéntico a
las imágenes ni naturalidad perfecta.

### Cambios en la malla y deformación

`human_kinematics.gd` define planos de flexión ligados al torso y marcos completos
para controlar giro y flexión, además de una separación continua del brazo
respecto al tórax. La postura de enlace de la malla se adapta a los centros
reales del esqueleto; el escalado XYZ ya no modifica las longitudes de los
segmentos. La orientación de las palmas distingue locomoción de agarre.

El esqueleto pasa de 20 a 24 controles: se conservan los índices existentes y
se añaden cuatro anillos de volumen para codos y rodillas. Los pesos se
transfieren de segmento a anillo y a segmento para evitar el aplastamiento de
una mezcla lineal directa durante flexiones fuertes. La malla sigue siendo
única y no se reconstruye durante las animaciones.

El torso tiene 48 vértices por sección y relieves discretos de pectorales,
esternón, clavículas y escápulas. Los miembros tienen 24 vértices por anillo,
con más secciones alrededor de las articulaciones. Se revisaron unión de
hombros, cierre de la entrepierna, mandíbula, ojos, barba y mechones con
volumen. Las pinturas frontal/posterior se comparten con la piel de los brazos,
con UV fijas en la postura de enlace y selección coherente por triángulo. La
armadura se adapta a la profundidad del tórax y a las nuevas aperturas.

La postura del arco abre el torso 0,40 radianes y lleva la mano de tensado al
lado correspondiente de la cara, manteniendo trayectoria por la mira y las
reglas de munición existentes. Se conservan alturas, velocidades, tiempos,
zancada aprobada, ángulos de reposo/carrera y física de movimiento.

`tests/prototype_3d_human_deformation.gd` deforma vértices con los pesos reales:
comprueba enlace neutro, volumen de articulaciones, longitudes, flexión,
orientaciones sin reflexión y continuidad entre poses en las 29 acciones y las
ocho familias. Se complementa con revisión nativa frontal/lateral, con/sin
armadura, y pruebas de agarres, trayectoria del arco y movimiento.
