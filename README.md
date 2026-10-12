# Day Zero · Supervivencia y recolección 2D

Prototipo con Godot 4.6.3 estándar y GDScript. Esta versión se centra en el personaje, la recolección, el inventario y la supervivencia diaria. No hay enemigos ni oleadas; la espada y el arco permiten probar sus acciones.

## Jugar

Importa `project.godot` en Godot 4.6.3, pulsa F5 y elige **Jugar** en el menú de Day Zero. El menú conserva completa la nueva plantilla de ciudad en ruinas, con seis botones: Continuar, Jugar, Configuración, Salir, Tienda y sonido. Tienda está deshabilitada. Jugar inicia una partida nueva y solicita confirmación si hay una partida abierta o guardada. **Esc** abre pausa, que añade Menú principal y Guardar partida. El botón de sonido alterna silencio sin cambiar los volúmenes configurados.

La ventana y la resolución base son **1920 × 1080**. La cámara tiene un zoom de **1,95×**, un 30% más cercano que el anterior 1,5×, para mantener legibles el personaje y los decorados; la interfaz se adapta al tamaño de la ventana. El detalle del suelo se calcula en coordenadas del mundo a resolución de un píxel, con pequeñas briznas de hierba, hojas, piedrecitas y sombras suaves de relieve. Los senderos tienen curvas y bordes irregulares; la paleta permanece reducida para facilitar la lectura. El relieve es visual y no cambia el movimiento.

- WASD o flechas: movimiento.
- Ctrl caminando o quieto (mantener): agacharse y caminar más despacio.
- Espacio: saltar.
- Shift (mantener): correr a 1,6 veces la velocidad de caminar, sin cansancio por ahora.
- Ctrl mientras corres: deslizarse con frenada progresiva.
- 1–6: usar/equipar el objeto asignado a cada acceso rápido; 0: dejar las manos libres.
- Para asignar un acceso, selecciona un objeto en Inventario y elige su espacio en «Asignar a acceso rápido». Los espacios comienzan vacíos; siguen al objeto aunque cambie de posición al equiparlo.
- Apunta con el punto del cursor y mantén clic izquierdo o E para golpear o disparar.
- Árbol adulto: hacha; roca: pico; arbolito joven, máquina o piedra pequeña: manos libres (0).
- I: inventario, fabricación y reparación; I, Esc o ×: cerrar. Esc cierra primero la ventana de fabricación/reparación si está abierta. El inventario pausa el juego y los proyectiles.
- T: abrir Creación. Tab: abrir Habilidades. Z / X: activar Impulso / Golpe potenciado.
- Inventario, Creación, Habilidades y Perks se encuentran en las pestañas superiores del inventario; los paneles pausan el juego.
- R: reiniciar la prueba con la misma semilla. Restaura los recursos, herramientas y ropa inicial, y vacía los materiales.
- F2: generar otro mapa y reiniciar la prueba.

El recurso bajo el cursor muestra cuántos golpes faltan. El punto adopta un tono verde suave si la superficie está al alcance y un tono rojizo si queda lejos. Árboles adultos → madera; rocas → piedra; maquinaria abandonada → chatarra; arbolitos jóvenes → fibra vegetal y palos. Las balizas son decorativas. Una roca grande requiere seis golpes; un arbolito, dos (da tres fibras y dos palos); una piedra pequeña, dos (da una piedra); los otros recursos, tres. Las piedras de las dos bandas de tamaño menor se pueden recoger con las manos para fabricar la primera herramienta. Los materiales se añaden al inventario al agotar el objeto, que desaparece y libera su colisión. No se puede recolectar desde lejos ni a través de otro obstáculo.

El personaje es un superviviente humano sin camiseta, con barba, pantalón corto marrón y pies descalzos. La altura de referencia es de 64 unidades en el mundo; la cámara mantiene su zoom anterior de 1,95. La cabeza usa las vistas de estilo original de tamaño constante durante la marcha. Las extremidades y la ropa se exportan unidas en cada pose. Los giros mantienen la fase de marcha y la frenada proporcional al ángulo; al completarse recuperan la velocidad máxima permitida por habilidades y alimentación.

El personaje visible se reproduce mediante **sprites completos de cuerpo y herramienta**, exportados desde un cuerpo continuo. Cada caminata tiene 12 fotogramas en ocho orientaciones; cada categoría de herramienta, 16 fotogramas de acción en 16 orientaciones. Equipar y detenerse usan seis fotogramas dedicados. La parada conserva la fase exacta del último paso. Piel y ropa permanecen unidas a muslos y torso; no se recortan rodillas ni se montan brazos durante el juego. El hacha y el pico tienen dos agarres sobre el mismo mango y gestos diferentes; la profundidad de autoría oculta la herramienta cuando queda detrás del cuerpo. Cada ID mantiene su propio dibujo. La caminata base es de 70 unidades/s y equipar detiene brevemente el desplazamiento.

La cabeza conserva ocho vistas pintadas de tamaño fijo; el cuerpo y las herramientas se exportan en las 16 orientaciones de uso. Son imágenes estilizadas, no una copia exacta del original ni una simulación muscular. Los criterios, la regeneración y las limitaciones se documentan en [docs/COMPLETE_SPRITE_PLAN.md](docs/COMPLETE_SPRITE_PLAN.md). Los antiguos módulos de articulación todavía calculan contactos y mantienen compatibilidad con comprobaciones de lógica; sus piezas no se muestran. Las pruebas visuales nuevas son `complete_sprite_pipeline.gd`, `full_frame_runtime.gd` y `full_frame_render.gd`.


El impacto se aplica si el cursor está sobre la superficie visible del objeto y el personaje está a un máximo de 40 px de su base o huella física. Se usa el borde más próximo de la huella, también en rocas grandes. No es necesario apuntar al punto exacto alcanzado por la punta: señalar la copa de un árbol cercano también lo selecciona. La animación golpea una parte próxima de su silueta y conserva el límite natural de los brazos; se mantiene la comprobación de obstáculos interpuestos. Un fallo muestra el golpe al aire, conserva los usos de la herramienta y no mueve el objeto. Un contacto produce una sacudida breve y pequeñas partículas en el punto golpeado; una herramienta incorrecta no extrae materiales. Moverse, cambiar de equipo o abrir un panel cancela el trabajo pendiente; un golpe que ya impactó se conserva. Mantener pulsado repite el ciclo; soltar permite terminar la acción actual.

El sombreado de pantalla es muy leve: ocupa solo el último 2% de cada borde, con una transición suave hasta un 18% de opacidad en el extremo. A 1920 × 1080 equivale aproximadamente a 38 px a izquierda/derecha y 22 px arriba/abajo. El centro y la interfaz permanecen despejados.

La recolección da experiencia. Cada nivel concede **un punto de mejora** a un único saldo compartido: gastar puntos en una habilidad o perk los descuenta y ya no pueden gastarse en otro objeto. Las seis mejoras antiguas se han retirado.

**Habilidades:** Impulso aumenta un 25% la velocidad durante 5 s (20 s de espera, Z); Golpe potenciado aumenta un 50% el siguiente impacto de espada o arco dentro de 5 s (15 s de espera, X). Fallar un golpe o disparar al aire no consume el efecto; sí caduca. También pueden activarse desde su pestaña. Ahora solo está disponible el nivel 1; los costes previstos por nivel son 1, 2, 4, 8… hasta diez niveles.

**Perks:** Vitalidad añade un 10% de vida máxima, Ataque un 10% de daño base, y Probabilidad crítica 5 puntos porcentuales, por fase. Desbloquear un perk cuesta **2 puntos e incluye su fase 1**; la fase 2 cuesta otros 2, la fase 3 costará 3, y así hasta 30 fases. Actualmente están disponibles las fases 1 y 2. La base es de 20 de vida, 1% de crítico y daño crítico ×1,1. Los efectos de daño afectan a espada y arco; no cambian la recolección. La progresión y los tiempos de habilidades se reinician al comenzar otra partida.

**Creación:** recetas a la izquierda y, a la derecha, vista del objeto, materiales disponibles/necesarios y Crear. Se conservan las recetas actuales: pico (2 piedras, 2 palos, 1 m de cuerda), hacha (1 piedra, 2 palos, 1 m de cuerda) y cuerda (3 fibras por metro). Cada herramienta creada ocupa un slot propio. Fabricar comprueba espacio y materiales antes de consumirlos.


## Día, noche, alimentación e hidratación

Cada partida comienza en el día 1 a las 08:00. Un ciclo completo dura **24 minutos reales**; el sol sale a las 06:00 y se pone a las 20:00. Su altura, dirección y color cambian continuamente. Las sombras se proyectan al suelo a partir de la transparencia real de los sprites, incluidos cabeza, brazos, piernas y herramientas animados. El personaje se compone en una única máscara para evitar juntas más oscuras y saltos al detenerse. La penumbra aumenta suavemente con la distancia a la base y con el sol bajo. Cada objeto usa únicamente su región del atlas, sin mezclar siluetas de otros árboles o rocas. La sombra se ancla a la base visible del tronco o piedra, excluyendo césped y márgenes inferiores del dibujo, y acompaña las sacudidas del objeto; el tamaño de la colisión no desplaza ese anclaje. Se alargan con el sol bajo, se acortan al mediodía y son más visibles al mediodía y por la tarde que al amanecer o atardecer. De noche desaparece la luz solar y el terreno, la hierba y los objetos reciben una iluminación ambiental azulada tenue. La interfaz conserva su legibilidad. El panel inferior derecho muestra el reloj, recorrido del sol, necesidades y vida; el minimapa ocupa la esquina superior derecha.

El personaje parte de **60 kg**, con una referencia diaria de **1600 kcal**. En el inventario, selecciona un alimento y pulsa **Comer**, o selecciona agua y pulsa **Beber**. Cada pulsación consume una unidad del slot seleccionado. Para probar el sistema, cada nueva partida incluye 4 manzanas (95 kcal cada una), 10 porciones de bayas (40 kcal), 8 raciones (400 kcal) y 8 botellas de agua (500 ml y 0 kcal). Los iconos y las cantidades aparecen en sus slots. Esta provisión inicial permite probar el consumo; todavía no hay una fuente renovable de alimentos en el mapa.

| Calorías consumidas ese día | Reducción de velocidad |
| --- | --- |
| Menos de 1600 | 0% |
| 1600–1799 | 1% |
| 1800–1999 | 3% |
| 2000–2200 | 6% |
| 2201–2399 | 10% |
| 2400 o más | 24% |

El tramo del 10% comienza al superar las 600 kcal de exceso, tal como indica la regla. La reducción multiplica la velocidad de movimiento, los efectos de velocidad y el ritmo visual de la caminata. A medianoche se reinician las calorías y el contador de agua consumida del día; el peso permanece en 60 kg. La hidratación empieza con **2000 ml**, baja gradualmente a razón de dos litros por ciclo completo y se recupera al beber, hasta ese máximo. No se gasta una botella si la reserva está llena. La reserva no se rellena automáticamente al cambiar de día. Por ahora la falta de agua se muestra en el indicador, sin añadir daño ni otras penalizaciones no definidas. Los menús, inventario y habilidades pausan tanto el reloj como la pérdida de hidratación. R y F2 reinician ambos sistemas.

El hacha y el pico tienen una dimensión visible máxima de **32 px**; la espada también mide **32 px**, la mitad de la altura de referencia del personaje (64 px). El arco mide 28 px. El tamaño visible y el alcance se calculan con la misma escala, conservando el agarre y el contacto de la hoja.

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

Disponible desde el menú principal y el de pausa. **Juego** contiene **Tamaño del HUD**, una barra de seis posiciones. El nivel 1 es el predeterminado y ocupa un 40% del área previa; los siguientes ocupan 48%, 56%, 64%, 72% y 80%. El ancho y alto se escalan por la raíz cuadrada de esas proporciones; no se escalan los menús ni el mapa completo. El ajuste se guarda y se aplica a la partida actual. También contiene Correr automáticamente: activado, correrás al moverte sin mantener Shift. **Audio** permite guardar el volumen general, de música y de efectos; los tres controles están conectados a sus buses aunque aún no haya pistas de audio. **Gráficos** permite elegir MSAA 2×/4× si el renderizador admite MSAA 2D; con Compatibilidad esas opciones están deshabilitadas y se conserva el pixel art sin suavizado. También permite activar la sincronización vertical y limitar los fotogramas a 30, 60, 120, 144 o dejarlos sin límite. Dentro de **Gráficos**, las opciones de pantalla permiten ventana, pantalla completa o ventana sin bordes, con 1280×720, 1600×900, 1920×1080 o 2560×1440. **Aplicar** guarda los valores en `user://day_zero_settings.cfg`; volver sin aplicar descarta los cambios pendientes.

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
godot --headless --path . --script res://tests/motion_polish.gd
godot --headless --path . --script res://tests/locomotion.gd
godot --headless --path . --script res://tests/clothing_volume.gd
godot --headless --path . --script res://tests/workshop.gd
godot --headless --path . --quit-after 120
```

`tests/baked_tool_occlusion.gd` comprueba los píxeles ocultos de las cuatro herramientas en vistas laterales y superiores, la oclusión dambos brazos del arco, el sentido de su cuerda y la cabeza integrada. `tests/menu_hit_areas.gd` verifica interiores y exteriores de botones a tres resoluciones. `tests/running.gd` verifica carrera manual/automática y Control. `tests/locomotion_render.gd` comprueba Ctrl/Espacio/Shift reales y las poses renderizadas. `tests/visual_integrity.gd` requiere pantalla gráfica y comprueba los píxeles de cada sombra de objeto, el origen de la piel lateral, la visibilidad de los brazos con hacha/pico en reposo y caminando y los anclajes de cadera.

Con una pantalla gráfica disponible, `godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/aimed_render.gd` comprueba la animación renderizada, los impactos y el cursor, sin guardar capturas. `tests/day_zero_ui.gd`, ejecutado del mismo modo, prueba los clics reales de equipar, desequipar, reparar y fabricar, las cantidades de los iconos y la configuración guardada.

En cloud, usa los directorios XDG escribibles indicados en las instrucciones del entorno bajo `/workspace/shared`. No se necesitan servicios ni credenciales para jugar.

Agacharse flexiona las piernas y baja el torso. El salto tiene un arco de 0,66 s y 24 px de altura visual; la posición y las colisiones del suelo siguen activas, por lo que esta versión no salta a través de árboles o rocas. Caminar agachado tiene 12 fotogramas propios en ocho direcciones. Deslizarse fija la dirección durante 0,46 s y frena hasta detenerse; entre 0,23 y 0,46 s se puede cancelar con un salto que recorre un 15% más bajo la misma entrada de movimiento, manteniendo sus 0,66 s y altura. La ventaja termina al aterrizar; hay una recuperación de 0,9 s desde el inicio. Los paneles pausan estos estados y reiniciar los restablece. Saltar o deslizarse cancela la recolección y el equipamiento en curso; no se pueden iniciar golpes durante estos movimientos.

## Archivos

- `scripts/locomotion.gd`: agacharse, salto, deslizamiento y curvas de movimiento.
- `scripts/character_parts.gd`: contornos de piernas y pies por orientación.
- `scripts/clothing_poses.gd` y `scripts/clothing_rig.gd`: catálogo de fases y deformación de la ropa.

- `scenes/day_zero.tscn` y `scripts/day_zero.gd`: entrada al juego, menú y pausa.
- `scripts/day_zero_menu.gd`: opciones a la izquierda y título a la derecha.
- `scripts/settings_panel.gd` y `scripts/game_settings.gd`: preferencias de sonido, gráficos y pantalla.
- `scripts/main.gd`: personaje, acciones, selección de herramientas y habilidades.
- `scripts/inventory.gd`: 32 espacios, cinco piezas de equipo, apilado y usos.
- `scripts/inventory_panel.gd`: panel de inventario y selección de equipo.
- `scripts/workshop.gd`: recetas exactas y reparación.
- `scripts/tool_sprites.gd`: sprites de las herramientas y geometría compartida de los agarres.
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
- `scripts/survivor_frames.gd`: ocho vistas desde los atlas de reposo y cuerpo; un reloj de marcha compartido sin cargar imágenes de caminar antiguas; giros mediante vistas intermedias.
- `assets/characters/survivor_regions.gd`: recortes y anclajes anatómicos de los fotogramas del nuevo personaje.
- `assets/environment/basic_forest_props.png`: árboles y rocas del primer bioma.
- `assets/environment/forest_details.png`: arbolito joven y charco.
- `assets/environment/grass_groups.png`: diez grupos de césped; `shaders/ground_foliage.gdshader`: paleta y contornos suaves del suelo.
- `assets/characters/survivor_body_8dir.png`: cuerpo del personaje para golpes articulados.
- `shaders/quarantine_ground.gdshader`: suelo natural continuo; `shaders/atmosphere.gdshader`: sombreado ligero de bordes.

Los atlas están en `assets/`; `.godot/` contiene cachés locales excluidas de Git. Se han eliminado los atlas antiguos de suelos y caminata, el dibujado duplicado de herramientas y el recorte de cabeza anterior. Del atlas de decorados se usan la maquinaria y la baliza. Contornos, geometría de herramientas y presentaciones de decorados se almacenan en cachés acotadas. Las sombras estáticas no reconstruyen sus comandos si el sol, la cámara y los objetos no han cambiado de forma perceptible; los impactos fuerzan su actualización. Los materiales se almacenan en la mochila; no se sueltan en el suelo. Las comprobaciones automáticas validan lógica y carga; la sensación del movimiento y las animaciones requiere también jugar en el editor.

Comprobación de cobertura: `godot --headless --path . --script tests/ground_cover.gd` valida diez variantes, caminos despejados, charcos y zonas de piedra en cuatro semillas.

Pruebas de esta versión:

- `tests/survival.gd`: límites calóricos, consumo, hidratación, medianoche, pausas, movimiento y dimensiones.
- `tests/proximity_harvesting.gd`: cercanía a la huella y cursor sobre cualquier parte visible del objeto.
- `tests/articulated_walk.gd`: cabeza constante, alternancia de pies, longitudes de huesos y transición al reposo.
- `tests/motion_polish.gd`: límites de codo, inercia, rebote por material, hombros unidos al torso, dirección tras el contacto y continuidad de marcha.
- `tests/solar_render.gd`: sombra visible, oscuridad nocturna de todo el terreno y dirección del sol (requiere pantalla gráfica).
- `tests/day_zero_ui.gd`: clics reales en menú, equipo, reparación, fabricación, comida y agua.

Los contornos comparten la política de [AGENTS.md](AGENTS.md): un píxel de rasterización del personaje, escalado con el dibujo. `visual_style.gd` normaliza bordes de objetos, materiales e iconos; el cuerpo y las herramientas usan el mismo contorno en la exportación. La cabeza forma parte de la malla de piel, comparte su paleta y transmite solo un 45% del balanceo de marcha. Los menús usan coordenadas nativas de la ventana y rectángulos de interacción sin expansión; el zoom conserva el encuadre al cambiar de resolución. El manifiesto de animación guarda únicamente los anclajes que utiliza el disparo, sin miles de entradas vacías.

En pantalla solo se muestran los atajos **Inventario (I), Crear (T) y Mapa (M)**, en marcos abajo a la derecha. La vida, las calorías y la hidratación están abajo a la izquierda; calorías y agua quedan pegadas. El peso aparece pequeño abajo a la derecha. El minimapa conserva el marco e icono de la segunda plantilla, con día y hora debajo. Ajustes y pausa están arriba a la izquierda. Las barras inferiores contienen seis accesos rápidos y cuatro espacios de habilidades (Z/X y dos vacíos). Solo se usan los elementos de interfaz de la segunda plantilla; el terreno sigue siendo el mapa procedural. M abre el mapa completo del terreno y muestra la posición actual sin niebla de exploración; M, Esc o × lo cierran. El mapa pausa el juego y no se superpone al inventario. Los avisos de recolección siguen siendo mensajes informativos, sin otros atajos. `tests/hud_map.gd` comprueba las seis áreas y anclajes; `tests/bow_back_occlusion.gd` revisa ambos brazos y la piel de la espalda en los PNG exportados. `tests/native_menu_input.gd` usa `native_pointer.py` y XTest para mover y pulsar el ratón del sistema en X11, incluyendo escalas de 100%, 125% y 150%.

La resolución seleccionada establece el tamaño real del renderizado también en pantalla completa y sin bordes; se conserva la proporción de la imagen. Los cambios de tamaño, modo y posición se aplican mediante el nodo `Window`, para mantener sincronizados el renderizado y la entrada. `scripts/pointer_coordinates.gd` convierte la posición física del cursor mediante el mismo transformado del viewport y corrige los eventos desfasados antes de enviarlos a los menús. Apuntar en el mundo y dibujar el cursor usan esa misma posición. Los MSAA no admitidos se deshabilitan en el selector. `tests/settings_application.gd` comprueba cambios efectivos de HUD, audio, límite de FPS, modos, resolución, persistencia y clics nativos después de Aplicar. Las pruebas gráficas se ejecutan en X11; el funcionamiento en Windows requiere una comprobación en ese sistema.

En la pantalla X11 sin gestor de ventanas del entorno, la prueba de Aplicar verifica que pantalla completa cubra físicamente el escritorio y conserve resolución y clics. Solo se omite la confirmación del indicador EWMH de pantalla completa, que necesita ese gestor; se identifica como SKIP, no como prueba pasada.

## Guardado manual

Desde pausa pulsa **Guardar partida**. No hay autoguardado: salir sin guardar descarta los cambios posteriores al último guardado. **Continuar** recupera la partida abierta o, después de cerrar el juego, `user://day_zero_save.cfg`. Se conserva una partida con semilla y recursos recogidos o golpeados, posición, inventario, equipo, usos, accesos rápidos, nivel, puntos, habilidades, perks, vida, hora, calorías e hidratación. La escritura sustituye el archivo de forma atómica; los datos incompatibles o inválidos se rechazan.

La espada básica usa `assets/items/basic_sword.png`, procedente del PNG original entregado. Sus iconos y todos los clips completos se regeneran desde el mismo dibujo, con el grosor fino compartido y un tamaño de referencia de 32 unidades. El menú y el HUD toman sus plantillas de `assets/ui/title_template.png` y `assets/ui/hud_template.png`; los valores de vida, comida, agua y mapa son datos reales de la partida, no los valores de ejemplo impresos en la referencia.
