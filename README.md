# Day Zero · Supervivencia y recolección 2D

Prototipo con Godot 4.6.3 estándar y GDScript. Esta versión se centra en el personaje, la recolección y el inventario. No hay enemigos ni oleadas; la espada y el arco permiten probar sus acciones.

## Jugar

Importa `project.godot` en Godot 4.6.3, pulsa F5 y elige **Jugar** en el menú de Day Zero. Las opciones se sitúan a la izquierda; el título ocupa el panel derecho, que abarca el 60% de la pantalla. **Esc** abre el menú de pausa con Continuar, Configuración y Menú principal.

La ventana y la resolución base son **1920 × 1080**. La cámara tiene un zoom de 1.5 para mantener legibles el personaje y los decorados; la interfaz se adapta al tamaño de la ventana. El detalle del suelo se calcula en coordenadas del mundo a resolución de un píxel, con pequeñas briznas de hierba, hojas, piedrecitas y sombras suaves de relieve. Los senderos tienen curvas y bordes irregulares; la paleta permanece reducida para facilitar la lectura. El relieve es visual y no cambia el movimiento.

- WASD o flechas: movimiento.
- 1: espada; 2: arco; 3: pico; 4: hacha; 0: dejar las manos libres.
- Apunta con el punto del cursor y mantén clic izquierdo, E o Espacio para golpear o disparar.
- Árbol adulto: hacha; roca: pico; arbolito joven, máquina o piedra pequeña: manos libres (0).
- I: inventario, fabricación y reparación; I, Esc o ×: cerrar. Esc cierra primero la ventana de fabricación/reparación si está abierta. El inventario pausa el juego y los proyectiles.
- Tab: abrir/cerrar el panel de habilidades; pausa el juego.
- R: reiniciar la prueba con la misma semilla. Restaura los recursos, herramientas y ropa inicial, y vacía los materiales.
- F2: generar otro mapa y reiniciar la prueba.

El recurso bajo el cursor muestra cuántos golpes faltan. El punto adopta un tono verde suave si la superficie está al alcance y un tono rojizo si queda lejos. Árboles adultos → madera; rocas → piedra; maquinaria abandonada → chatarra; arbolitos jóvenes → fibra vegetal y palos. Las balizas son decorativas. Una roca grande requiere seis golpes; un arbolito, dos (da tres fibras y dos palos); una piedra pequeña, dos (da una piedra); los otros recursos, tres. Las piedras de las dos bandas de tamaño menor se pueden recoger con las manos para fabricar la primera herramienta. Los materiales se añaden al inventario al agotar el objeto, que desaparece y libera su colisión. No se puede recolectar desde lejos ni a través de otro obstáculo.

El personaje sigue la nueva referencia: humano más delgado, sin camiseta, con barba, marca azul grisácea junto al ojo, pantalón corto marrón y pies descalzos. Tiene el pelo castaño corto, tomando aproximadamente 6 cm arriba y 2 cm a los lados como guía real. Hay ocho vistas de reposo y caminata, incluidas las diagonales, con cuatro fotogramas de caminar por dirección. Los giros pasan por las vistas intermedias de 45°; hay transiciones de 45°, 90° y 180° en ambos sentidos. La duración y frenada dependen del ángulo, y al completar el giro vuelve la velocidad máxima. La altura visible es de 64 px en el mundo y los pies mantienen su apoyo durante las transiciones. El inventario muestra el mismo personaje.

Los brazos de las acciones reutilizan los píxeles de piel del propio atlas de reposo. Los hombros se anclan a la posición anatómica de cada vista; las longitudes físicas del brazo y el antebrazo permanecen fijas. Los codos se resuelven en tres dimensiones, con las manos delante del pecho y un plano de flexión estable que evita inversiones repentinas o estiramientos. Al equipar y usar el hacha o el pico, ambas manos se fijan a puntos concretos del mango; el alcance corresponde a la intersección de los dos brazos, sin soltar el agarre. En reposo las herramientas se sujetan con dos manos; al caminar se transportan en una mano. El hacha tiene un gesto lateral de corte y el pico una preparación elevada seguida de un golpe descendente. Cada herramienta tiene también su gesto de equipar; se ve en la mano en reposo y al caminar, siguiendo los anclajes de cada fotograma. La preparación y la recuperación enlazan con la misma posición de agarre de reposo. Un atlas de ocho vistas del cuerpo sin brazos evita duplicarlos durante la acción. La preparación, el contacto y la recuperación siguen el cursor en tiempo real; no se estiran los brazos para alcanzar puntos lejanos. Cada árbol, arbolito, roca y máquina tiene una malla de impacto adaptada a su silueta, independiente de la pequeña colisión de movimiento. Se comprueba también la transparencia del sprite: el rectángulo que lo contiene no basta para acertar.

El impacto solo se aplica si el cursor está sobre una superficie y la mano o la punta de la herramienta llega hasta ese punto sin atravesar otro cuerpo. Un fallo muestra el golpe al aire, conserva los usos de la herramienta y no mueve el objeto. Un contacto produce una sacudida breve y pequeñas partículas en el punto golpeado; una herramienta incorrecta no extrae materiales. Moverse, cambiar de equipo o abrir un panel cancela el trabajo pendiente; un golpe que ya impactó se conserva. Mantener pulsado repite el ciclo; soltar permite terminar la acción actual.

El sombreado de pantalla es muy leve: ocupa solo el último 2% de cada borde, con una transición suave hasta un 18% de opacidad en el extremo. A 1920 × 1080 equivale aproximadamente a 38 px a izquierda/derecha y 22 px arriba/abajo. El centro y la interfaz permanecen despejados.

La recolección da experiencia y puntos de habilidad. Hay seis ramas de cinco rangos: Silvicultura (+1 madera o fibra por árbol), Minería (+1 piedra por roca), Agilidad (+22 velocidad), Reciclaje (+1 chatarra por máquina), Ritmo (+12% velocidad de trabajo) y Sabiduría (+20% experiencia).

## Inventario y objetos

Panel cuadrado centrado, con un área aproximada del 60% de la pantalla. En ventanas muy alargadas se limita al 95% del lado menor para permanecer visible. Muestra el personaje con cinco espacios fijos alrededor: cabeza, torso, piernas, manos y pies. Debajo hay 32 espacios de mochila. Selecciona un objeto y pulsa **Equipar**, o selecciona una pieza equipada y pulsa **Desequipar**. Las herramientas y armas ocupan Manos; la ropa ocupa su espacio correspondiente. Los materiales se apilan hasta 99 unidades por espacio. **Las armas y herramientas ocupan una unidad por espacio**, tienen identidades y desgaste independientes y nunca se acumulan. Piedra, palo y cuerda tienen iconos basados en las herramientas primitivas; cada espacio muestra su cantidad en pequeño en la esquina inferior derecha. En las herramientas se muestra un «1»; los usos aparecen en la descripción al seleccionarlas.

| Objeto básico | Uso permitido | Usos iniciales |
| --- | --- | --- |
| Espada | Ataque cuerpo a cuerpo | 40 |
| Arco | Disparar flechas | 60 |
| Pico | Extraer piedra de rocas | 30 |
| Hacha | Cortar árboles | 30 |

Cada impacto válido con una herramienta, ataque de espada o disparo consume un uso. Un intento con la herramienta incorrecta o una cancelación antes del impacto no consume usos. El objeto conserva su desgaste al guardarlo o equiparlo. A cero usos queda roto y no funciona. Por ahora solo existe rareza Básico; los valores están en las definiciones de objetos. El arco no requiere munición separada en esta versión.

Si no cabe la recompensa en la mochila, el último golpe no destruye el recurso ni consume un uso. El intercambio de equipo tampoco pierde objetos cuando la mochila está llena. La partida todavía no tiene guardado persistente; la configuración sí se guarda. La ropa puede equiparse y retirarse del inventario; por ahora el sprite del personaje conserva su aspecto original.

## Fabricación y reparación

En el inventario, **Fabricar** abre la lista de recetas con el objeto a la izquierda y las cantidades necesarias/disponibles a la derecha. El resultado entra en la mochila con sus usos completos:

| Receta | Piedras | Palos | Cuerda | Fibra |
| --- | --- | --- | --- | --- |
| Pico básico | 2 | 2 | 1 metro | — |
| Hacha básica | 1 | 2 | 1 metro | — |
| 1 metro de cuerda | — | — | — | 3 |

Cada unidad de cuerda representa un metro. Los arbolitos y las piedras pequeñas permiten obtener los materiales iniciales con las manos. Fabricar comprueba el conjunto de ingredientes y el espacio final: si falla, no consume materiales; puede aprovechar el espacio liberado al consumir el último objeto de una pila.

Selecciona un arma, herramienta o pieza de armadura, equipada o en la mochila, y pulsa **Reparar**. La ventana muestra su estado actual, el estado tras la reparación y los materiales disponibles. Confirmar restaura todos sus usos o su durabilidad. Los objetos en perfecto estado no consumen recursos.

| Objeto | Materiales de reparación |
| --- | --- |
| Pico / hacha | 1 piedra + 1 palo |
| Espada | 2 piedras + 1 palo |
| Arco | 1 palo + 1 metro de cuerda |
| Casco | 2 piedras + 1 metro de cuerda |
| Traje / pantalón / botas | 2 fibras + 1 metro de cuerda |

Las piezas de armadura usan durabilidad: casco 80, traje 100, pantalón y botas 60. El prototipo sin enemigos no les aplica daño automático todavía. La reparación conserva la identidad y la ubicación del objeto.

## Configuración

Disponible desde el menú principal y el de pausa. **Sonido** permite guardar el volumen general, de música y de efectos; los tres controles están conectados a sus buses aunque aún no haya pistas de audio. **Gráficos** permite desactivar el suavizado o usar MSAA 2×/4×, activar la sincronización vertical y limitar los fotogramas a 30, 60, 120, 144 o dejarlos sin límite. **Pantalla** permite ventana, pantalla completa o ventana sin bordes, con 1280×720, 1600×900, 1920×1080 o 2560×1440. **Aplicar** guarda los valores en `user://day_zero_settings.cfg`; volver sin aplicar descarta los cambios pendientes.

## Mapa

Primer bioma: bosque sencillo con un claro central, pequeño y procedural, de 48 × 32 casillas (3072 × 2048 px), con el doble de superficie que la versión inicial. Árboles comunes de tronco marrón y hojas verdes apagadas; rocas grises redondeadas con algo de musgo. El suelo mezcla suavemente tierra y hierba con senderos continuos, sin cuadrícula visible, y una viñeta ligera conserva el ambiente sombrío. Hay diez rocas grandes, veinte arbolitos jóvenes, dos máquinas abandonadas para obtener chatarra y una baliza. Diez grupos de césped forman una cobertura uniforme con posiciones, tamaños y formas variadas. Sus contornos gris verdoso oscuro y su capa inferior mantienen legibles al personaje y los decorados. Cuatro zonas de piedra expuesta interrumpen la hierba; los senderos, charcos y zonas pedregosas quedan libres de césped. Solo aparecen entre tres y cinco charcos pequeños por mapa, separados al menos 600 px entre sí; césped y charcos son decorativos y no bloquean el paso. La semilla inicial es 73129. F2 la incrementa; la misma semilla reproduce la distribución. Los caminos y la zona inicial están despejados.

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
godot --headless --path . --script res://tests/aimed_harvesting.gd
godot --headless --path . --script res://tests/character_actions.gd
godot --headless --path . --script res://tests/workshop.gd
godot --headless --path . --quit-after 120
```

Con una pantalla gráfica disponible, `godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/aimed_render.gd` comprueba la animación renderizada, los impactos y el cursor, sin guardar capturas. `tests/day_zero_ui.gd`, ejecutado del mismo modo, prueba los clics reales de equipar, desequipar, reparar y fabricar, las cantidades de los iconos y la configuración guardada.

En cloud, usa los directorios XDG escribibles indicados en las instrucciones del entorno bajo `/workspace/shared`. No se necesitan servicios ni credenciales para jugar.

## Archivos

- `scenes/day_zero.tscn` y `scripts/day_zero.gd`: entrada al juego, menú y pausa.
- `scripts/day_zero_menu.gd`: opciones a la izquierda y título a la derecha.
- `scripts/settings_panel.gd` y `scripts/game_settings.gd`: preferencias de sonido, gráficos y pantalla.
- `scripts/main.gd`: personaje, acciones, selección de herramientas y habilidades.
- `scripts/inventory.gd`: 32 espacios, cinco piezas de equipo, apilado y usos.
- `scripts/inventory_panel.gd`: panel de inventario y selección de equipo.
- `scripts/workshop.gd`: recetas exactas y reparación.
- `scripts/tool_sprites.gd` y `scripts/held_tool.gd`: sprites de las herramientas, agarres y seguimiento de la mano.
- `assets/items/stone_tools.png` y `assets/items/basic_materials.png`: hacha, pico, palos, cuerda y piedra.
- `scripts/item_icons.gd`: iconos de herramientas y materiales; `scripts/arrow.gd`: proyectiles del arco.
- `scripts/harvesting.gd`: contacto, recursos, golpes, inventario y agotamiento.
- `scripts/arm_rig.gd`: brazos articulados y alcance natural de cada herramienta.
- `scripts/hit_meshes.gd`: mallas de las siluetas, transparencia y selección por cursor.
- `scripts/aim_cursor.gd`: punto del ratón y alcance visual.
- `scripts/test_world.gd`: generación y colisiones.
- `scripts/nature_variants.gd`: catálogo de tamaños, tonos y bases de colisión de árboles y rocas.
- `scripts/world_view.gd`: suelo y decorados; `scripts/world_minimap.gd`: minimapa.
- `scripts/turn_motion.gd`: giros (hasta 0.28 s; frenada máxima 35% en 180°, 8.75% en 90° y 2.19% en 45°).
- `scripts/survivor_frames.gd`: ocho vistas desde los atlas de caminar y reposo; giros mediante vistas intermedias.
- `assets/characters/survivor_regions.gd`: recortes y anclajes anatómicos de los fotogramas del nuevo personaje.
- `assets/environment/basic_forest_props.png`: árboles y rocas del primer bioma.
- `assets/environment/forest_details.png`: arbolito joven y charco.
- `assets/environment/grass_groups.png`: diez grupos de césped; `shaders/ground_foliage.gdshader`: paleta y contornos suaves del suelo.
- `assets/characters/survivor_body_8dir.png`: cuerpo del personaje para golpes articulados.
- `shaders/quarantine_ground.gdshader`: suelo natural continuo; `shaders/atmosphere.gdshader`: sombreado ligero de bordes.

Los atlas están en `assets/`; `.godot/` contiene cachés locales excluidas de Git. El atlas antiguo de suelos se conserva como recurso sin uso; del atlas original de decorados solo se usan la maquinaria y la baliza. Los materiales se almacenan en la mochila; no se sueltan en el suelo. Las comprobaciones automáticas validan lógica y carga; la sensación del movimiento y las animaciones requiere también jugar en el editor.

Comprobación de cobertura: `godot --headless --path . --script tests/ground_cover.gd` valida diez variantes, caminos despejados, charcos y zonas de piedra en cuatro semillas.
