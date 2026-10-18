# Superviviente compuesto

El cuerpo y los 66 huesos originales en T proceden de
`Personaje1_Renewed_3d/psnj1_3d_rigged.fbx`, conservado en `source/`.
La cabeza aprobada se conserva en `source/approved_head_source.glb` como
instantánea del modelo anterior, con sus UV y atributos de superficie.
Rugged Castaway sigue aportando la cicatriz, expresión, pelo y barba.

La composición tiene un solo MeshInstance3D con tres materiales: cuerpo,
cabeza y transición de cuello. Comparte el rig nuevo y los pesos de ambos
bordes del cuello. No se renderizan las antiguas superficies de sobacos.
La altura en partida es 1,75 m. Escena, manifiesto y parámetros en
`assets/characters/prototype_3d/composite/`; preparación en
`docs/ANIMATION_SYSTEMS.md`. Las fuentes originales quedan excluidas de la
importación automática mediante `.gdignore` y no se sobrescriben al regenerar.
