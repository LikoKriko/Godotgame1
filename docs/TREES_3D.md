# Árboles de la primera especie

## Formas y dimensiones

La especie tiene nueve perfiles de tronco y ramas, con cuatro variantes
deterministas por perfil: 36 mallas compartidas. El sexto perfil tiene una
altura canónica de 1,8375 m. La altura de cada instancia sigue las dimensiones
del generador. La referencia artística es
`entregables/entorno/plantas/arboles_especie1_3d.png`.

Los troncos tienen 24 lados, curvas y raíces ensanchadas. Las bifurcaciones se
estrechan hacia ramillas; las copas usan hojas con volumen y grupos irregulares.
Las bases se ajustan al suelo. Corteza y hojas tienen texturas de 512×512 con
muestreo nearest y mipmaps, y material compartido por la especie.

## Interacción

Las colisiones siguen el tronco; la cámara también considera la copa.
Las hojas y raíces no forman paredes para el movimiento. Los árboles adultos
se talan con hacha y entregan madera. La resistencia, rendimiento, agotamiento
y persistencia se definen en los registros de recursos de la generación.
La sacudida visual solo se procesa después de un golpe.

`tree_geometry.gd` define las formas; `tree_model.gd` crea sus instancias;
`world_content.gd` aplica el perfil y la altura del registro generado. Los
archivos están en `scripts/prototype_3d/`.
