# Zona de animaciones

El usuario ha reservado este chat para modelos, esqueletos, pesos y deformación,
animaciones de personajes/criaturas, vestimenta animada, agarres y coordinación
del cuerpo con las herramientas. Las futuras tareas de otros sistemas se
repartirán entre otros chats; esta nota no bloquea archivos ni reserva toda la
rama a un único hilo.

Puntos principales: `survivor_model.gd`, `survivor_anatomy.gd`,
`survivor_surface.gd`, `humanoid_rig.gd`, `human_kinematics.gd`,
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
