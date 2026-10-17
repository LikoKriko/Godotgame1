# Relieve de la zona inicial

El mundo normal incluye una prueba de relieve con trazado base fijo,
en X entre −56 y +56 m y Z entre −112 y +28 m. El resto del terreno mantiene
su altura original. No se generan montañas ni cuevas en otros chunks.

Desde la aparición, avanzar hacia Z negativa permite recorrer un camino de
unos 90 m de longitud y aproximadamente 3,2 m de anchura interior, con bordes
irregulares y transición de tierra hasta unos 5,2 m de anchura. Incluye pequeñas
ondulaciones y depresiones de hasta 10 cm. Entre Z −18 y −38 m sube una rampa
con pendiente base de 5°, que alcanza unos 1,75 m. Una montaña de unos 8 m,
con base de 46 m de diámetro, está centrada en X 23, Z −66 m. Sus formas se
unen gradualmente con el suelo exterior; la aparición permanece plana.

`initial_relief.gd` define la altura en metros y el trazado del camino. El suelo
visible usa una retícula de 0,5 m únicamente en los chunks que intersectan la
prueba. La colisión usa los mismos vértices y triángulos, sin el antiguo plano
físico por debajo de los baches. Se conserva esta pequeña colisión local al
viajar; las superficies visibles conservan el streaming y la calidad por
distancia del resto del mundo. Las veinte mallas locales se reutilizan al
regresar a la zona. No se recalcula el relieve en cada fotograma.

Los árboles, rocas, plantas y césped se apoyan en la altura local. Bajo árboles,
rocas y plantas se adapta una zona de apoyo plana cuyo radio es el de la base
más un **5 % de su diámetro en cada dirección horizontal**: radio final =
1,10 × radio original. Una base de 2 m de diámetro recibe 10 cm adicionales
por cada lado. La base considera las raíces del árbol (radio máximo 0,28 ×
altura), el contorno de roca1 (radio 1,5 m), o el apoyo de las plantas
(radios 0,47/0,32 m). Un borde de 0,75 m enlaza suavemente con la pendiente.
Las bases solapadas comparten una altura; no se cambia la escala ni la
hitbox del objeto. Los apoyos se calculan por semilla una vez y se consultan
mediante una cuadrícula espacial compartida entre suelo, colisiones y recursos.
Las huellas completas de recursos y césped dejan libre el camino. El buffer de césped se
prepara en el hilo de chunks y su atributo CUSTOM0 conserva la altura del centro
para aplicar correctamente la calidad por distancia. El camino usa
`terreno1_claro_1_Path.png` con sus colores originales y la misma máscara en
ambos shaders del suelo. Las tres imágenes generales de suelo cubren el resto.

Las casas antiguas del inicio no se instancian. Los charcos y plataformas
planos que intersectaban la prueba tampoco se colocan sobre el nuevo relieve.
Sus recursos fuente y los IDs de recursos se conservan para compatibilidad.
Las partidas anteriores siguen siendo válidas; al continuar, jugador, criaturas,
objetos y mesas que hayan quedado bajo el suelo se elevan hasta su superficie,
sin modificar su posición horizontal ni sus acciones guardadas.

La huella completa de la prueba se comprueba contra las reservas de historia.
La zona `story_demo_01`, en X 192, Z −128 m, conserva su suelo y contenido.
