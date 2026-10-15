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

La zona central de la espalda sigue el tórax; no debe quedar asignada a los
brazos por la difusión automática. La corrección reproducible está en
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
