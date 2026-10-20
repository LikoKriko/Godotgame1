# Dirección visual y recursos compartidos

Estas reglas completan el AGENTS.md raíz. Leer solo el apartado aplicable al recurso;
las fichas de especie y los manifiestos fijan sus fuentes y dimensiones.

## Acabado 3D vigente

Todas las texturas nuevas o adaptadas deben mantener el estilo visual actual
del juego. La referencia principal de acabado es el enemigo3 Sunny Sprout,
sus materiales en `assets/enemies/third/sprout/` y su apariencia dentro del juego.
El estilo es fantasía 3D estilizada con acabado pintado: formas orgánicas
legibles, colores armonizados, variaciones de tono suaves y detalles de
superficie definidos y limpios. El enemigo3 combina amarillos cálidos, crema,
verdes vegetales y marrones; usarlo como referencia de tratamiento y calidad,
adaptando la paleta al material y la identidad de cada personaje u objeto.

La textura debe acompañar el volumen y distinguir piel, pelo, hojas, tela,
madera o piedra mediante color, rugosidad y relieve moderado. Se permiten mapas
de normales y otros mapas de material para aportar detalle fino sin aumentar
innecesariamente la geometría. Mantener transiciones cuidadas, costuras UV
discretas y rasgos propios como cicatrices, ojos y expresión de la boca.
Evitar ruido, manchas de material incorrecto, contrastes excesivos y relieve
que deforme visualmente las facciones. El resultado debe leerse bien tanto
de cerca como a la distancia habitual de juego.

Esta referencia sustituye la exigencia anterior de pixel art, incluso donde
queden menciones antiguas: no imponer pixelado visible ni reducir la paleta
para simularlo. Elegir resolución, filtrado y mipmaps para reproducir el acabado
de referencia con nitidez y estabilidad, sin escalones artificiales ni pérdida
de detalle por desenfoque. Se aplica a texturas generadas, adaptadas de imágenes
o sprites y destinadas a modelos 3D, objetos e interfaz. Conservar las reglas
de contornos finos y las excepciones de interfaz indicadas a continuación.

## Contornos y excepciones de interfaz

Todos los dibujos del juego deben usar contornos tan finos como los del personaje principal. Se aplica a personajes, animales, árboles, rocas, césped, objetos, armas, armaduras, materiales y a sus representaciones en inventario, fabricación, reparación y cualquier interfaz o mecánica futura. No incorporar nuevos dibujos con bordes gruesos. Excepción de interfaz solicitada por el usuario: los marcos de ventanas y botones tienen un contorno cuatro veces más grueso, manteniendo sus rectángulos, zonas de clic y adornos originales.

Conservar las líneas negras interiores finas de ramas, troncos y separaciones
de hojas, tomando las ramitas como referencia. Normalizar el contorno exterior
no debe borrar esas líneas ni aumentar su grosor.

## Vestimenta y cobertura

Las armaduras normales acompañan la transformación completa del torso; la de
hojas cubre pecho, abdomen, espalda y hombros, dejando abierto el cuello. No
recortar la cobertura a una pequeña pechera.

La anatomía y la inercia de tela se rigen por [ANIMATION_SYSTEMS.md](ANIMATION_SYSTEMS.md#contratos-de-anatomía-y-contacto).
Los materiales y fuentes de armadura están en [MESHY_ASSETS.md](MESHY_ASSETS.md#objetos).

## Referencia de raster para recursos planos

El grosor de referencia es un píxel de la rasterización del personaje completo (192×192 por celda, ~1,5 píxeles de raster por unidad del mundo). El contorno escala con el dibujo y el zoom; no mantiene un ancho fijo en pantalla. Usar `scripts/visual_style.gd` para normalizar dibujos e iconos. La exportación del personaje y sus herramientas debe compartir esta política, evitando añadir dos contornos consecutivos. Eliminar solo el borde oscuro exterior grueso; preservar sombreado y detalles interiores.

**Alcance:** la utilidad `scripts/visual_style.gd` continúa normalizando iconos y
recursos planos compartidos. Sus constantes son `OUTLINE_PIXELS = 1` y
`PIXELS_PER_WORLD = 1.53125` (aproximación histórica de ~1,5).
**Verificar vigencia:** la celda de personaje 192×192 y la exportación conjunta
pertenecen al flujo de sprites retirado; no definen la resolución de texturas UV,
el filtrado ni una obligación de exportar animaciones 3D. No reactivar exportadores
2D. Véase [SHARED_RESOURCES.md](SHARED_RESOURCES.md#referencias-de-exportación-2d-verificar-vigencia).

## Origen de las sombras

Las sombras de objetos parten del contorno visible de sus apoyos. Declarar cada
pata de muebles y apoyos de edificios en coordenadas del dibujo, y usar sus
apoyos físicos 3D; la hitbox no define el origen visual. Conservar la sombra
del personaje. Ver `docs/YOUNG_3D.md` y `docs/PROTOTYPE_3D.md` para el runtime vigente.

Para luz, cielo y atmósfera consultar [PROTOTYPE_3D.md](PROTOTYPE_3D.md#dirección-de-iluminación-y-ambiente).
La colocación de apoyos no se deduce de la hitbox de combate.
