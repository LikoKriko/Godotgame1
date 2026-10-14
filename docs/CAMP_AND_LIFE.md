# Campamento, criaturas y supervivencia

El día completo dura 960 segundos reales (16 minutos), definido en
`day_cycle.gd`. Hidratación y luz comparten ese reloj; las pausas lo detienen.

## Campamento y árboles

`camp_art.gd` define seis edificios: la choza inicial y las cinco estructuras
subidas. Los sprites se normalizan al mismo muestreo y contorno del personaje;
sus puertas se oscurecen un 70%. La separación entre bordes supera el ancho
máximo de cada pareja. `test_world.gd` reserva sus superficies antes de distribuir
plantas, hierba, agua o plataformas. E junto a cualquier puerta carga la misma
escena independiente `hut_interior.tscn`; al salir se vuelve a esa entrada.
Los enemigos y cadáveres permanecen fuera. El identificador de edificio se guarda.

`bake_large_trees.gd` extrae las nueve vistas del PNG original sin cambiarlo.
`large_tree_art.gd` usa el sexto dibujo como referencia de 67,2 unidades; los
otros conservan las proporciones relativas del archivo. `generate_tree_groups`
crea grupos de 3–15 árboles, con 64 unidades entre bases distintas y al menos
430 entre centros de grupos. El diseño y los tonos son deterministas por semilla.

`world_depth.gd` ordena personajes, criaturas, árboles, rocas y edificios por sus
pies. Los obstáculos grandes solo bloquean su base; detrás quedan visibles con
35% de opacidad al cubrir al jugador y 75% al cubrir otras criaturas. Las sombras
siguen usando los contactos del dibujo, no los límites de colisión.

Las plataformas conservan su geometría y sus 9,6 unidades de altura. La piedra
se rasteriza a la mitad de resolución anterior; la tierra marrón usa una capa
fina independiente y una variación de tono leve, sin emborronar las losas.

## Curtido

En la mesa básica, una pieza de cuero curtido necesita:

- 1 cuero sin refinar, consumido.
- 1 uso de la bolsa de sal (12 usos iniciales).
- 3 usos del cuchillo (40 usos iniciales).

La sal y el cuchillo son objetos individuales del catálogo K; el cuchillo todavía
no tiene sprite ni combate. El primer y segundo dibujos de `cuerocurtido_fases`
son los iconos de cuero curtido y piel sin refinar. La reserva de fabricación dura
2 segundos y cancelar restaura materiales, posiciones, identidades y durabilidad.

## Comida y muerte

`life_cycle.gd` consume la pila seleccionada después de 12 fotogramas en 1,2 s;
permite caminar, bloquea correr incluso con carrera automática, y no consume
alimentos si la acción se interrumpe por muerte. Cada alimento tiene sus sprites
completos, con piernas animadas al caminar y variantes con armadura.

El jugador cae durante 3 s con la armadura que llevaba. La ventana integrada
ofrece Reaparecer o Salir al menú. Reaparecer elimina mochila, barra rápida,
equipo, experiencia, puntos y perks; conserva las habilidades desbloqueadas y
reinicia el nivel a 1. El mundo y sus recursos no se regeneran al reaparecer.

El joven cae durante 2 s, con abdomen y cabeza hacia el suelo. Después permanece
180 segundos reales: su caducidad usa un reloj de pared y sigue transcurriendo
al abrir menús. E cerca del cuerpo abre `corpse_loot.gd`, con ocho espacios en
2 filas, ventana del 30% del área del inventario, ocupación real de la mochila y
acciones Recoger/Tirar. Tirar deja el objeto en el mundo; recogerlo con E requiere
manos libres y reproduce la inclinación. Se conserva su durabilidad. La piel de
prueba es botín provisional, no una tabla de recompensas definitiva.

Las partidas manuales conservan cadáveres, contenidos, caducidad y objetos
arrojados. Las partidas anteriores conservan inventario y progreso, y adoptan
la nueva distribución de árboles y campamento.
