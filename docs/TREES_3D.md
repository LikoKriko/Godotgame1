# Árboles Twisted Oak

Los árboles adultos utilizan la edición radial de
`modelo_arbol3d/arbol1.zip`, fuente Meshy Twisted Oak 1019091539. El FBX original
permanece intacto en `entregables/modelos/twisted_oak/source/`. La edición
modificable está en `entregables/modelos/twisted_oak/edited.blend`.

## Forma y dimensiones

Se conservan las raíces y la parte inferior del tronco del modelo entregado.
La continuación del tronco tiene una transición coincidente con su sección de
corte. Quince ramas principales rodean el tronco con separaciones de 20–30°,
a distintas alturas. Cada una tiene 3–7 ramas secundarias, y cada secundaria
2–3 ramitas terminales. Longitudes, grosores, inclinaciones y giros varían con
semilla fija. La desviación entre las tangentes inicial y final de cada curva
no supera 30°, 15° y 5°, respectivamente. Se comprueba la separación entre
ramas fuera de los cuellos embebidos de las bifurcaciones. No tiene hojas.

La malla normalizada mide un metro y mantiene las proporciones con escala
uniforme. Cada registro del mundo conserva su altura y posición anteriores.
Los nueve tamaños canónicos siguen siendo 2,65; 2,79; 3,20; 3,28; 2,57; 1,8375;
2,62; 2,74 y 3,24 m. Las cuatro variantes son orientaciones de 0°, 90°, 180°
y 270°. La especie usa una única malla compartida de 22976 triángulos y dos
superficies: raíz/tronco original y corteza transferida de las ramas.

## Material y autoría

Los cuatro mapas PBR originales están en `assets/models/meshy/twisted_oak/`.
Los mapas `bark_*` de 512×512 proyectan su corteza alrededor del tronco; el
normal se convierte al nuevo espacio tangente. Las tres primeras filas del
tronco editado mezclan las UV y el normal originales con la corteza transferida
para suavizar la unión; el resto de las ramas solo muestrea los mapas `bark_*`.
El material usa mipmaps y
filtrado lineal anisotrópico. No añade contornos ni hojas procedurales.

`data/world/trees/twisted_oak.json` controla la edición. Para regenerar:

```sh
blender -b -t 6 --python tools/trees/build_twisted_oak.py -- /tmp/twisted-oak
# Importar primero las texturas actualizadas en Godot.
godot --headless --editor --path . --import --quit
godot --headless --path . --script tools/trees/bake_twisted_oak.gd -- /tmp/twisted-oak/edited.glb
```

`branches.json` conserva los ejes, radios, parentesco y curva de cada rama,
junto con la espina ligera de colisión del tronco. Los controles completos de
autoría están en coordenadas Blender (Z arriba); `collision_spine` ya usa las
coordenadas Godot (Y arriba). El generador normaliza ambos con la misma escala.

## Interacción y recursos compartidos

`tree_model.gd` instancia la malla compartida sin generar ramas en partida.
`tree_geometry.gd` conserva los tamaños y comparte las formas de colisión por
altura. Las cápsulas siguen el tronco real; las raíces quedan transitables.
Quince cápsulas adicionales impiden atravesar las ramas principales con la
cámara. No hay esferas de copa invisibles entre las ramas sin hojas.

Se mantienen los IDs, posiciones, resistencia, madera y estado guardado de
cada recurso. La sacudida visual solo se procesa después de un golpe, vuelve
a la orientación de reposo y se suspende al acabar. La calidad por distancia
utiliza el sistema compartido de mallas y materiales.

La escena `scenes/prototype_3d/tree_review.tscn` permite revisar el árbol desde
cualquier ángulo y con las alturas y orientaciones existentes.

## Contrato de identidad y persistencia

- Árboles adultos: Twisted Oak 1019091539 de modelo_arbol3d/arbol1.zip,
  edición radial de 22976 triángulos, 15 ramas principales, 73 secundarias y
  182 ramitas, sin hojas. Mantener alturas, IDs, posiciones y estados de tala.
  Perfil en data/world/trees/twisted_oak.json; regenerar según docs/TREES_3D.md.
