# Godotgame1 · Exploración y recolección 2D

Prototipo con Godot 4.6.3 estándar y GDScript. Esta versión se centra en el personaje, la recolección y el inventario. No hay enemigos ni oleadas; la espada y el arco permiten probar sus acciones.

## Jugar

Importa `project.godot` en Godot 4.6.3 y pulsa F5.

La ventana y la resolución base son **1920 × 1080**. La cámara tiene un zoom de 1.5 para mantener legibles el personaje y los decorados; la interfaz se adapta al tamaño de la ventana. El detalle del suelo se calcula en coordenadas del mundo a resolución de un píxel, con pequeñas briznas de hierba, hojas, piedrecitas y sombras suaves de relieve. Los senderos tienen curvas y bordes irregulares; la paleta permanece reducida para facilitar la lectura. El relieve es visual y no cambia el movimiento.

- WASD o flechas: movimiento.
- 1: espada; 2: arco; 3: pico; 4: hacha; 0: dejar las manos libres.
- Mantén E cerca de un árbol con el hacha, de una roca con el pico o de una máquina con las manos libres.
- Clic izquierdo o Espacio: utilizar la espada o disparar el arco, apuntando al ratón.
- I: inventario; I, Esc o ×: cerrar. El inventario pausa el juego y los proyectiles.
- Tab: abrir/cerrar el panel de habilidades; pausa el juego.
- R: reiniciar la prueba con la misma semilla. Restaura los recursos, herramientas y ropa inicial, y vacía los materiales.
- F2: generar otro mapa y reiniciar la prueba.

El recurso al alcance se resalta y muestra cuántos golpes faltan. Árboles → madera; rocas → mineral; maquinaria abandonada → chatarra. Las balizas son decorativas. Una roca grande requiere seis golpes; los otros recursos, tres. Los materiales se añaden al inventario al agotar el objeto, que desaparece y libera su colisión. No se puede recolectar desde lejos ni a través de otro obstáculo.

El personaje sigue la nueva referencia: humano sin camiseta, con barba, marca azul grisácea junto al ojo, pantalón corto marrón y pies descalzos. Tiene el pelo castaño corto, tomando aproximadamente 6 cm arriba y 2 cm a los lados como guía real. Hay ocho vistas de reposo y caminata, incluidas las diagonales, con cuatro fotogramas de caminar por dirección. Los giros pasan por las vistas intermedias de 45°; hay transiciones de 45°, 90° y 180° en ambos sentidos. La duración y frenada dependen del ángulo, y al completar el giro vuelve la velocidad máxima. La altura visible es de 64 px en el mundo y los pies mantienen su apoyo durante las transiciones. El inventario muestra el mismo personaje.

Las animaciones antiguas de armas y herramientas, sus atlas y los efectos visuales de ataque del personaje se han retirado para rehacerlos después. La recolección sigue funcionando con el personaje en reposo, orientado al recurso. Moverse cancela el trabajo pendiente; un golpe que ya impactó se conserva. Mantener E repite el ciclo; soltarla permite terminar la acción actual. Se conservan las restricciones de cada herramienta, los usos, los materiales y las acciones básicas de espada/arco.

El sombreado de pantalla es muy leve: ocupa solo el último 2% de cada borde, con una transición suave hasta un 18% de opacidad en el extremo. A 1920 × 1080 equivale aproximadamente a 38 px a izquierda/derecha y 22 px arriba/abajo. El centro y la interfaz permanecen despejados.

La recolección da experiencia y puntos de habilidad. Hay seis ramas de cinco rangos: Silvicultura (+1 madera por árbol), Minería (+1 mineral por roca), Agilidad (+22 velocidad), Reciclaje (+1 chatarra por máquina), Ritmo (+12% velocidad de trabajo) y Sabiduría (+20% experiencia).

## Inventario y objetos

Panel cuadrado centrado, con un área aproximada del 60% de la pantalla. En ventanas muy alargadas se limita al 95% del lado menor para permanecer visible. Muestra el personaje con cinco espacios fijos alrededor: cabeza, torso, piernas, manos y pies. Debajo hay 32 espacios de mochila. Selecciona un objeto y pulsa **Equipar**, o selecciona una pieza equipada y pulsa **Quitar equipo**. Las herramientas y armas ocupan Manos; la ropa ocupa su espacio correspondiente. Los materiales se apilan hasta 99 unidades por espacio.

| Objeto básico | Uso permitido | Usos iniciales |
| --- | --- | --- |
| Espada | Ataque cuerpo a cuerpo | 40 |
| Arco | Disparar flechas | 60 |
| Pico | Extraer mineral de rocas | 30 |
| Hacha | Cortar árboles | 30 |

Cada impacto válido con una herramienta, ataque de espada o disparo consume un uso. Un intento con la herramienta incorrecta o una cancelación antes del impacto no consume usos. El objeto conserva su desgaste al guardarlo o equiparlo. A cero usos queda roto y no funciona. Por ahora solo existe rareza Básico; los valores están en las definiciones de objetos. El arco no requiere munición separada en esta versión.

Si no cabe la recompensa en la mochila, el último golpe no destruye el recurso ni consume un uso. El intercambio de equipo tampoco pierde objetos cuando la mochila está llena. No hay guardado persistente, fabricación ni reparación todavía. La ropa puede equiparse y retirarse del inventario; por ahora el sprite del personaje conserva su aspecto original.

## Mapa

Primer bioma: bosque sencillo con un claro central, pequeño y procedural, de 48 × 32 casillas (3072 × 2048 px), con el doble de superficie que la versión inicial. Árboles comunes de tronco marrón y hojas verdes apagadas; rocas grises redondeadas con algo de musgo. El suelo mezcla suavemente tierra y hierba con senderos continuos, sin cuadrícula visible, y una viñeta ligera conserva el ambiente sombrío. Hay diez rocas grandes, dos máquinas abandonadas para obtener chatarra y una baliza. La semilla inicial es 73129. F2 la incrementa; la misma semilla reproduce la distribución. Los caminos y la zona inicial están despejados.

Cada familia tiene **30 variantes generadas en el juego**, combinando dos siluetas, cinco tamaños y tres tonos suaves de la misma especie/material. Se reutilizan los sprites originales con escala proporcional y tinte; no son 30 PNG separados. Los árboles miden 102–188 px de alto. Las rocas miden 12.8, 25.6, 44.8, 76.8 o 128 px de ancho: aproximadamente del 20% al 200% de la altura inicial del personaje, tomando 64 px como referencia en el mundo. La cámara aplica el mismo zoom a todos. El mapa inicial contiene las 30 variantes de cada familia; el catálogo se distribuye con una semilla estable, sin cambiar de aspecto durante la partida.

La única colisión del árbol es la **base del tronco**, adaptada a su tamaño. Puedes pasar por la zona de la copa. Cuando estás detrás y el árbol oculta al personaje, se dibuja por delante con una transición suave al 35% de opacidad. Recupera su opacidad al salir y se dibuja por detrás si el personaje está delante. Las rocas tienen una colisión pequeña o grande según su base visible; una piedrecita no bloquea una casilla entera. La cuadrícula sigue reservando espacio para distribuir recursos, mientras un índice espacial comprueba las colisiones de sus cuerpos. Recolectar libera el cuerpo y su reserva; reiniciar restaura variantes, sprites y colisiones.

## Comprobaciones

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/inventory.gd
godot --headless --path . --script res://tests/movement.gd
godot --headless --path . --script res://tests/turns.gd
godot --headless --fixed-fps 60 --path . --script res://tests/walk_cycle.gd
godot --headless --path . --script res://tests/world.gd
godot --headless --path . --script res://tests/nature.gd
godot --headless --path . --quit-after 120
```

En cloud, usa los directorios XDG escribibles indicados en las instrucciones del entorno bajo `/workspace/shared`. No se necesitan servicios ni credenciales para jugar.

## Archivos

- `scripts/main.gd`: personaje, acciones, selección de herramientas y habilidades.
- `scripts/inventory.gd`: 32 espacios, cinco piezas de equipo, apilado y usos.
- `scripts/inventory_panel.gd`: panel de inventario y selección de equipo.
- `scripts/item_icons.gd`: iconos de las cuatro herramientas; `scripts/arrow.gd`: proyectiles del arco.
- `scripts/harvesting.gd`: alcance, recursos, golpes, inventario y agotamiento.
- `scripts/test_world.gd`: generación y colisiones.
- `scripts/nature_variants.gd`: catálogo de tamaños, tonos y bases de colisión de árboles y rocas.
- `scripts/world_view.gd`: suelo y decorados; `scripts/world_minimap.gd`: minimapa.
- `scripts/turn_motion.gd`: giros (hasta 0.28 s; frenada máxima 35% en 180°, 8.75% en 90° y 2.19% en 45°).
- `scripts/survivor_frames.gd`: ocho vistas desde los atlas de caminar y reposo; giros mediante vistas intermedias.
- `assets/characters/survivor_regions.gd`: recortes y anclajes anatómicos de los fotogramas del nuevo personaje.
- `assets/environment/basic_forest_props.png`: árboles y rocas del primer bioma.
- `shaders/quarantine_ground.gdshader`: suelo natural continuo; `shaders/atmosphere.gdshader`: sombreado ligero de bordes.

Los atlas están en `assets/`; `.godot/` contiene cachés locales excluidas de Git. El atlas antiguo de suelos se conserva como recurso sin uso; del atlas original de decorados solo se usan la maquinaria y la baliza. Los materiales se almacenan en la mochila; no se sueltan en el suelo. Las comprobaciones automáticas validan lógica y carga; la sensación del movimiento y las animaciones requiere también jugar en el editor.
