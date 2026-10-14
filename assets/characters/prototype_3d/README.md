# Materiales del superviviente 3D

`painted_materials.png` es un atlas creado para esta primera pasada de acabado
pintado estilizado, con cuatro regiones iguales: piel (arriba izquierda), tela
(arriba derecha), pelo (abajo izquierda) y fibras de cuerda (abajo derecha).

El atlas se generó con la herramienta de imágenes, con tonos elegidos a partir
del diseño original del superviviente. `humanoid_rig.gd` asigna UV2 en la malla
de reposo; la animación mantiene esas coordenadas, sin reproyectar cada pose.
Los ojos y la marca facial conservan el color del modelo. El shader limita la
variación del material para mantener la paleta y evitar exceso de contraste.

La importación genera mipmaps y el shader usa filtrado lineal para reducir
parpadeo en el detalle de telas y pelo a distancia. El contorno exterior conserva
el grosor fino del prototipo. El atlas y el cuerpo pertenecen solo a la rama 3D;
los diseños y sprites originales siguen conservados.
