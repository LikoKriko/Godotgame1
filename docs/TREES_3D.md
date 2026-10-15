# Árboles de la primera especie en 3D

Referencia: `entregables/entorno/plantas/arboles_especie1_3d.png`, incorporada por
el usuario en `f35900c`. La lámina contiene nueve caras frontales, no vistas
ortogonales de todos los lados. Las ramas posteriores y la profundidad son una
reconstrucción volumétrica coherente; no una copia exacta de vistas inexistentes.

## Modelos

`tree_geometry.gd` separa nueve perfiles de tronco y distribuciones de ramas,
con cuatro variantes deterministas por perfil. El sexto conserva 1,8375 m de
altura canónica, un 5% más que el personaje. En partida se mantienen las alturas
y posiciones del generador existente; `world_content.gd` también transmite el
diseño del recurso, que antes se ignoraba al crear su representación 3D.

Los troncos tienen 24 lados, variación longitudinal, curvas cúbicas y raíces
individuales ensanchadas. Las bifurcaciones se estrechan hacia ramillas. Las
copas usan hojas anchas cerradas, con pliegue y volumen, grupos irregulares y
ramas en profundidad. No hay un plano frontal ni esferas verdes de relleno.
Los extremos de madera están cerrados; las bases de raíces se ajustan al suelo.

Las dos texturas de superficie de 512×512 se generan de forma reproducible con
`tools/build_tree_materials.gd`, usando una paleta de corteza y hojas contrastada
con la referencia. No recortan el fondo de la lámina ni reutilizan texturas de
piel, ropa o enemigo. El shader usa muestreo nearest con mipmaps; el detalle
complementa la forma modelada. Los originales del usuario permanecen intactos.

## Recursos e interacción

Cada variante se combina en una sola superficie. Hay un máximo de 36 mallas
compartidas; las texturas y material son únicos para toda la especie. La sacudida
solo procesa fotogramas después de un golpe. Las cápsulas siguen el tronco
curvado y los bloqueadores de cámara siguen los grupos de copa, sin convertir
las hojas ni raíces en paredes para el movimiento. Se mantienen tres golpes,
recompensas, agotamiento y guardado existentes.

## Revisión

Abrir `scenes/prototype_3d/tree_review.tscn` con F6. Los selectores muestran las
nueve siluetas y cuatro variantes. Arrastrar con el botón derecho permite girar
y cambiar la elevación; la rueda cambia la distancia. Revisar también detrás,
desde arriba y desde debajo de la copa.

`tests/prototype_3d_trees.gd` comprueba determinismo, nueve formas diferentes,
volumen en dieciséis proyecciones alrededor del árbol, alturas, raíces apoyadas,
normales, recursos compartidos, texturas y retirada de colisiones al talar. La
revisión nativa capturó ocho ángulos de cada diseño y vistas superior/inferior.
La prueba de población conserva 83 árboles y 5191 grupos de césped para la
semilla de prueba. Son comprobaciones de integridad, no una certificación de
parecido exacto o rendimiento en el ordenador del usuario.
