# Day Zero · Supervivencia y recolección 2D

Prototipo con Godot 4.6.3 estándar y GDScript. Esta versión se centra en el personaje, la recolección, el inventario y la supervivencia diaria. Incluye un primer enemigo joven para probar la espada, el arco y el parry; todavía no hay oleadas.

## Jugar

Importa `project.godot` en Godot 4.6.3, pulsa F5 y elige **Jugar** en el menú de Day Zero. El menú conserva completa la nueva plantilla de ciudad en ruinas, con seis botones: Continuar, Jugar, Configuración, Salir, Tienda y sonido. Tienda está deshabilitada. Jugar inicia una partida nueva y solicita confirmación si hay una partida abierta o guardada. **Esc** abre pausa, que añade Menú principal y Guardar partida. El botón de sonido alterna silencio sin cambiar los volúmenes configurados.

La ventana y la resolución base son **1920 × 1080**. La cámara tiene un zoom de **1,95×**, un 30% más cercano que el anterior 1,5×, para mantener legibles el personaje y los decorados; la interfaz se adapta al tamaño de la ventana. El terreno utiliza cuatro texturas mediante chunks de 512 × 512 unidades, cargados alrededor de la cámara y reutilizados en caché. El ruido y las transiciones usan coordenadas globales: los bordes no modifican el dibujo. Los senderos tienen curvas y bordes irregulares. Hay cuatro plataformas físicas de 9,6 unidades de altura; se puede subir caminando o saltando. Los parámetros y pruebas del sistema están en [docs/terrain.md](docs/terrain.md).

- WASD o flechas: movimiento.
- Ctrl caminando o quieto (mantener): agacharse y caminar más despacio.
- Espacio: saltar.
- K: catálogo de prueba con búsqueda y cantidad; añade objetos a la mochila sin fabricarlos y pausa la partida.
- Shift (mantener): correr a 1,6 veces la velocidad de caminar, sin cansancio por ahora.
- Ctrl mientras corres: deslizarse con frenada progresiva.
- 1–6: usar/sacar el objeto de cada acceso rápido. Repetir la tecla del arma activa la guarda y deja las manos libres, conservando el objeto y sus usos en la barra. 0: dejar las manos libres.
- El hueco Manos del inventario es exclusivo para guantes; las armas no son piezas de armadura. Equipar desde la mochila traslada el arma a un hueco libre de la barra rápida; si está llena, primero hay que liberar uno.
- La barra rápida añade seis espacios físicos: sus objetos no ocupan la mochila. Arrastra entre mochila, equipo y barra para mover o intercambiar objetos. Shift + clic desde la mochila equipa primero una armadura si su hueco está vacío; si no, la pasa al primer espacio rápido disponible. Desde barra o equipo, Shift + clic devuelve el objeto a la mochila. Los materiales compatibles se apilan sin duplicarse; las herramientas y armaduras siguen ocupando un espacio cada una.
- Apunta con la mira del cursor y mantén clic izquierdo para golpear o disparar. E se reserva para interactuar: recoge bardana y piedras pequeñas con las manos libres, o rellena la botella seleccionada apuntando al agua y estando cerca.
- Árbol adulto: hacha; roca grande: pico; arbolito joven: golpes con manos libres. Bardana y piedras pequeñas: E con manos libres.
- F: parry, con cuatro segundos de recuperación.
- I: inventario, fabricación y reparación; I, Esc o ×: cerrar. Esc cierra primero la ventana de fabricación/reparación si está abierta. El inventario pausa el juego y los proyectiles.
- T: abrir Creación. Tab: abrir Habilidades. Z / X: activar Impulso / Golpe potenciado.
- Inventario, Creación, Habilidades y Perks se encuentran en las pestañas superiores del inventario; los paneles pausan el juego.
- R: reiniciar la prueba con la misma semilla. Restaura los recursos, herramientas y ropa inicial, y vacía los materiales.
- F2: generar otro mapa y reiniciar la prueba.

El recurso bajo el cursor muestra cuántos golpes faltan. La mira nueva mide 24 píxeles de alto en pantalla, en partida y en todos los menús; su centro coincide con el punto de clic y de selección, también al cambiar resolución. Árboles adultos dan madera; arbolitos jóvenes, fibra y palos; sus cinco diseños nuevos tienen la misma altura; rocas, piedra. Las pequeñas se recogen con E y dan entre una y tres piedras. Las que requieren pico pasan progresivamente de cuatro golpes/cuatro piedras a doce golpes/quince piedras. La bardana se recoge con E: su versión 1 da cinco hojas y la 2, tres. Las balizas y máquinas antiguas se han retirado, también de sus colisiones y de los guardados anteriores.

Recoger del suelo utiliza seis poses durante 0,36 s, con la velocidad al 40%; el material se entrega al contacto. Después la velocidad se recupera durante 0,5 s. Sacar un objeto de la barra aplica una reducción del 5% que desaparece progresivamente durante un segundo. El deslizamiento mantiene la reducción anterior del 15%; el salto encadenado recorre un 30% menos que antes de esta actualización, manteniendo su duración y altura.

El primer enemigo utiliza únicamente Day_Zero_Enemigo_Joven_4_Vistas.png, con 32 unidades de altura, 16 direcciones, 12 fotogramas de caminata y 16 por puñetazo para cada mano. Camina sobre cuatro patas con apoyos alternados y balanceo leve, y se levanta para golpear. Tiene 10 de vida, camina a 56 unidades/s, detecta al jugador a 250 y alterna puños cada segundo con 2 de daño. Aparece fuera de la zona inicial de detección. El parry con F acepta intentos hasta 0,5 s antes del contacto y 0,2 s después: anula ese golpe y aturde 1,5 s. El daño pendiente se aplica 0,35 s después del contacto. El combate se pausa en los menús; estado del enemigo, golpe pendiente y recuperación del parry se guardan en disco. La espada tiene una preparación más corta, una estela fina que sigue la punta real de su sprite y un destello al impactar.

El personaje es un superviviente humano sin camiseta, con barba, pantalón corto marrón y pies descalzos. La altura de referencia es de 64 unidades en el mundo; la cámara mantiene su zoom anterior de 1,95. La cabeza usa las vistas de estilo original de tamaño constante durante la marcha. Las extremidades y la ropa se exportan unidas en cada pose. Los giros mantienen la fase de marcha y la frenada proporcional al ángulo; al completarse recuperan la velocidad máxima permitida por habilidades y alimentación.

El personaje visible se reproduce mediante **sprites completos de cuerpo y herramienta**, exportados desde un cuerpo continuo. Cada caminata tiene 12 fotogramas en ocho orientaciones; cada categoría de herramienta, 16 fotogramas de acción en 16 orientaciones. Equipar y detenerse usan seis fotogramas dedicados. La parada conserva la fase exacta del último paso. Piel y ropa permanecen unidas a muslos y torso; no se recortan rodillas ni se montan brazos durante el juego. El hacha y el pico conservan el agarre zurdo: mano izquierda cerca de la cabeza de la herramienta y derecha en la parte inferior del mango. Tienen dos agarres sobre el mismo mango y gestos diferentes; la profundidad de autoría oculta la herramienta cuando queda detrás del cuerpo. Cada ID mantiene su propio dibujo. La caminata base es de 70 unidades/s y sacar una herramienta mantiene el desplazamiento: hay poses completas combinadas con caminar, correr y caminar agachado.

La cabeza conserva ocho vistas pintadas de tamaño fijo; el cuerpo y las herramientas se exportan en las 16 orientaciones de uso. Son imágenes estilizadas, no una copia exacta del original ni una simulación muscular. Los criterios, la regeneración y las limitaciones se documentan en [docs/COMPLETE_SPRITE_PLAN.md](docs/COMPLETE_SPRITE_PLAN.md). El juego ya no crea ni calcula el antiguo sistema de extremidades separadas. El contacto lógico usa `tool_contact.gd`, sin cargar atlas viejos ni construir miembros ocultos. Las pruebas visuales nuevas son `complete_sprite_pipeline.gd`, `full_frame_runtime.gd` y `full_frame_render.gd`.


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

Panel centrado que usa la plantilla `entregables/interfaces/Inventario.png`, conservando su proporción y un área cercana al 60% de la pantalla. Se limita su altura para dejar accesible la barra rápida. La mochila conserva 32 huecos en cuatro filas de ocho; las pestañas son Inventario, Crear, Habilidades, Perks y Mapa. El mapa se muestra dentro del panel. Mejorar y Desmontar permanecen deshabilitados hasta definir esas mecánicas. Muestra el personaje con cinco espacios fijos alrededor: cabeza, torso, piernas, manos y pies. Debajo hay 32 espacios de mochila. Arrastra los objetos entre mochila, equipo y barra rápida para equipar o desequipar; también funciona Shift + clic. Comer y Beber conservan un botón propio al seleccionar consumibles. Manos está reservado para guantes; herramientas y armas se guardan físicamente en la barra rápida. Los materiales se apilan hasta 99 unidades por espacio. **Las armas y herramientas ocupan una unidad por espacio**, tienen identidades y desgaste independientes y nunca se acumulan. Piedra, palo y cuerda tienen iconos basados en las herramientas primitivas; cada espacio muestra su cantidad en pequeño en la esquina inferior derecha. En las herramientas se muestra un «1»; los usos aparecen en la descripción al seleccionarlas.

| Objeto básico | Uso permitido | Usos iniciales |
| --- | --- | --- |
| Espada | Ataque cuerpo a cuerpo | 40 |
| Arco | Disparar flechas | 60 |
| Pico | Extraer piedra de rocas | 30 |
| Hacha | Cortar árboles | 30 |

La espada causa 3 de daño base y pierde un uso solo al contactar con enemigo, árbol o roca; no daña recursos. Pico y hacha causan 1 de daño: pierden un uso al recolectar correctamente y dos al golpear un enemigo o usar la herramienta equivocada. Los golpes al aire no gastan usos. El arco causa 3 de daño y gasta un uso al comenzar a tensar, incluso si se cancela. El objeto conserva su desgaste al guardarlo o equiparlo. A cero usos queda roto y no funciona. Por ahora solo existe rareza Básico; los valores están en las definiciones de objetos. El arco requiere una flecha en mochila o barra rápida. Tensa durante seis fotogramas en 0,5 s y después dispara, consumiendo una flecha. Sin munición no inicia animación y muestra «Necesitas flechas para disparar el arco». El icono, proyectil y flecha cargada usan el nuevo diseño de flecha1.png.

Si no cabe la recompensa en la mochila, el último golpe no destruye el recurso; el contacto físico sí desgasta la herramienta. El intercambio de equipo tampoco pierde objetos cuando la mochila está llena. La partida tiene guardado manual en pausa; la configuración también se guarda. La armadura de hojas se dibuja sobre el torso y acompaña las poses completas; las demás piezas todavía no tienen apariencia propia.

## Fabricación y reparación

En el inventario, **Fabricar** abre la lista de recetas con el objeto a la izquierda y las cantidades necesarias/disponibles a la derecha. El resultado entra en la mochila con sus usos completos:

| Receta | Piedras | Palos | Cuerda | Fibra |
| --- | --- | --- | --- | --- |
| Pico básico | 2 | 2 | 1 metro | — |
| Hacha básica | 1 | 2 | 1 metro | — |
| 5 flechas básicas | 1 | 1 | 1 metro | — |
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

Primer bioma: bosque sencillo con un claro central, pequeño y procedural, de 48 × 32 casillas (3072 × 2048 px), con el doble de superficie que la versión inicial. Árboles comunes de tronco marrón y hojas verdes apagadas; rocas grises redondeadas con algo de musgo. El suelo mezcla suavemente tierra y hierba con senderos continuos, sin cuadrícula visible, y una viñeta ligera conserva el ambiente sombrío. Hay diez rocas grandes, veinte arbolitos jóvenes repartidos entre cinco diseños de igual altura. Doce diseños de césped forman una cobertura con un 35% más de grupos, colocados más próximos entre sí, con posiciones, tamaños y formas variadas. Sus contornos gris verdoso oscuro y su capa inferior mantienen legibles al personaje y los decorados. Los senderos y charcos quedan libres de césped; se han retirado las zonas grises antiguas de piedra expuesta. Solo aparecen entre tres y cinco charcos pequeños por mapa, separados al menos 600 px entre sí; césped y charcos son decorativos y no bloquean el paso. La semilla inicial es 73129. F2 la incrementa; la misma semilla reproduce la distribución. Los caminos y la zona inicial están despejados.

Cada familia tiene **30 variantes generadas en el juego**, combinando dos siluetas, cinco tamaños y tres tonos suaves de la misma especie/material. Se reutilizan los sprites originales con escala proporcional y tinte; no son 30 PNG separados. Los árboles miden 102–188 px de alto. Las rocas miden 12.8, 25.6, 44.8, 76.8 o 128 px de ancho: aproximadamente del 20% al 200% de la altura inicial del personaje, tomando 64 px como referencia en el mundo. La cámara aplica el mismo zoom a todos. El mapa inicial contiene las 30 variantes de cada familia; el catálogo se distribuye con una semilla estable, sin cambiar de aspecto durante la partida.

La única colisión del árbol es la **base del tronco**, adaptada a su tamaño. Puedes pasar por la zona de la copa. Cuando estás detrás y el árbol oculta al personaje, se dibuja por delante con una transición suave al 35% de opacidad. Recupera su opacidad al salir y se dibuja por detrás si el personaje está delante. Las rocas tienen una colisión pequeña o grande según su base visible; una piedrecita no bloquea una casilla entera. La cuadrícula sigue reservando espacio para distribuir recursos, mientras un índice espacial comprueba las colisiones de sus cuerpos. Recolectar libera el cuerpo y su reserva; reiniciar restaura variantes, sprites y colisiones.

## Comprobaciones

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/inventory.gd
godot --headless --path . --script res://tests/movement.gd
godot --headless --path . --script res://tests/world.gd
godot --headless --path . --script res://tests/nature.gd
godot --headless --path . --script res://tests/aimed_harvesting.gd
godot --headless --path . --script res://tests/locomotion.gd
godot --headless --path . --script res://tests/workshop.gd
godot --headless --path . --quit-after 120
```

`tests/baked_tool_occlusion.gd` comprueba anatomía, oclusión y cabeza integrada; `tool_back_exports.gd` revisa los sprites exportados. `full_frame_runtime.gd` y `equipment_motion.gd` comprueban movimiento y equipamiento. `running.gd` verifica carrera manual/automática y Control.

`impact_durability.gd` comprueba daños y desgaste por contacto; `bow_ammunition.gd` comprueba la ausencia de animación sin flechas y la liberación a los 0,5 s. `bow_craft_capacity.gd` verifica los lotes de cinco flechas y el límite de las pilas. `sword_tip_trail.gd` comprueba la punta de la estela en las 16 direcciones y con armadura. `cursor_alignment.gd`, `menu_hit_areas.gd` y `settings_application.gd` ejercitan el cursor y los ajustes con una pantalla nativa disponible. `native_cursor.gd` comprueba el tamaño y centro del cursor del sistema, y que los textos emergentes no intercepten el movimiento sobre los botones.

Con una pantalla gráfica disponible, `godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/aimed_render.gd` comprueba la animación renderizada, los impactos y el cursor, sin guardar capturas. `tests/day_zero_ui.gd`, ejecutado del mismo modo, prueba los clics reales de equipar, desequipar, reparar y fabricar, las cantidades de los iconos y la configuración guardada.

En cloud, usa los directorios XDG escribibles indicados en las instrucciones del entorno bajo `/workspace/shared`. No se necesitan servicios ni credenciales para jugar.

Agacharse flexiona las piernas y baja el torso. El salto tiene un arco de 0,66 s y 24 px de altura visual; se pueden superar objetos cuya altura física no exceda 19,2 unidades (30% de la altura del personaje). Los árboles, edificios y rocas más altos siguen bloqueando el paso. Se puede aterrizar y permanecer sobre una roca pequeña, bajando al salir de su superficie. Caminar agachado tiene 12 fotogramas propios en ocho direcciones. Deslizarse fija la dirección durante 0,46 s y frena hasta detenerse; se puede saltar en cualquier momento conservando la velocidad y dirección actuales del deslizamiento, con una pose propia de impulso hacia delante. El giro en el aire está limitado a 70° a cada lado de la dirección de despegue, manteniendo los 0,66 s y la altura habituales. La inercia termina al aterrizar; hay una recuperación de 0,9 s desde el inicio. Los paneles pausan estos estados y reiniciar los restablece. Saltar o deslizarse cancela la recolección y el equipamiento en curso; no se pueden iniciar golpes durante estos movimientos.

## Archivos

- `scripts/locomotion.gd`: agacharse, salto, deslizamiento y curvas de movimiento.

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
- `scripts/hit_meshes.gd`: mallas de las siluetas, transparencia y selección por cursor.
- `scripts/aim_cursor.gd`: punto del ratón y alcance visual.
- `scripts/test_world.gd`: generación y colisiones.
- `scripts/nature_variants.gd`: catálogo de tamaños, tonos y bases de colisión de árboles y rocas.
- `scripts/world_view.gd`: suelo y decorados; `scripts/styled_hud.gd`: HUD y minimapa con terreno almacenado en caché.
- `scripts/turn_motion.gd`: giros (hasta 0.28 s; frenada máxima 35% en 180°, 8.75% en 90° y 2.19% en 45°).
- `assets/environment/basic_forest_props.png`: árboles y rocas del primer bioma.
- `assets/environment/forest_details.png`: arbolito joven y charco.
- `assets/environment/imported/`: doce grupos de césped, diez dibujos de roca y referencias de terreno; `shaders/ground_foliage.gdshader`: paleta y contornos suaves del suelo.
- `scripts/terrain_chunks.gd`, `terrain_sampler.gd`, `terrain_profile.gd` y `shaders/chunk_ground.gdshader`: terreno procedural por chunks; `shaders/atmosphere.gdshader`: sombreado ligero de bordes.

Los atlas están en `assets/`; `.godot/` contiene cachés locales excluidas de Git. Se han eliminado los atlas antiguos de suelos y caminata, el dibujado duplicado de herramientas y el recorte de cabeza anterior. El atlas de maquinaria y balizas se ha retirado. Contornos, geometría de herramientas y presentaciones de decorados se almacenan en cachés acotadas. Las sombras estáticas no reconstruyen sus comandos si el sol, la cámara y los objetos no han cambiado de forma perceptible; los impactos fuerzan su actualización. Los materiales se almacenan en la mochila; no se sueltan en el suelo. Las comprobaciones automáticas validan lógica y carga; la sensación del movimiento y las animaciones requiere también jugar en el editor.

Comprobación de cobertura: `godot --headless --path . --script tests/ground_cover.gd` valida diez variantes, caminos despejados, charcos y zonas de piedra en cuatro semillas.

Pruebas de esta versión:

- `tests/survival.gd`: límites calóricos, consumo, hidratación, medianoche, pausas, movimiento y dimensiones.
- `tests/proximity_harvesting.gd`: cercanía a la huella y cursor sobre cualquier parte visible del objeto.
- `tests/solar_render.gd`: sombra visible, oscuridad nocturna de todo el terreno y dirección del sol (requiere pantalla gráfica).
- `tests/day_zero_ui.gd`: clics reales en menú, equipo, reparación, fabricación, comida y agua.

Los contornos comparten la política de [AGENTS.md](AGENTS.md): un píxel de rasterización del personaje, escalado con el dibujo. `visual_style.gd` normaliza bordes de objetos, materiales e iconos; el cuerpo y las herramientas usan el mismo contorno en la exportación. La cabeza forma parte de la malla de piel y comparte su paleta. Cuello y torso se desplazan juntos; la inclinación del cráneo respecto al cuello es muy leve. El giro del torso parte de la cadera para evitar estirar la cabeza al correr. Los menús usan coordenadas nativas de la ventana y rectángulos de interacción sin expansión; el zoom conserva el encuadre al cambiar de resolución. El manifiesto de animación guarda únicamente los anclajes que utiliza el disparo, sin miles de entradas vacías.

En pantalla solo se muestran los atajos **Inventario (I), Crear (T) y Mapa (M)**, en marcos abajo a la derecha. La vida, las calorías y la hidratación están abajo a la izquierda; calorías y agua quedan pegadas. El peso aparece pequeño abajo a la derecha. El minimapa conserva el marco e icono de la segunda plantilla, con día y hora debajo. Ajustes y pausa están arriba a la izquierda. Las barras inferiores contienen seis accesos rápidos y cuatro espacios de habilidades (Z/X y dos vacíos). Solo se usan los elementos de interfaz de la segunda plantilla; el terreno sigue siendo el mapa procedural. M abre el mapa completo del terreno y muestra la posición actual sin niebla de exploración; M, Esc o × lo cierran. El mapa pausa el juego y no se superpone al inventario. Los avisos de recolección siguen siendo mensajes informativos, sin otros atajos. `tests/hud_map.gd` comprueba las seis áreas y anclajes; `tests/bow_back_occlusion.gd` revisa ambos brazos y la piel de la espalda en los PNG exportados. `tests/native_menu_input.gd` usa `native_pointer.py` y XTest para mover y pulsar el ratón del sistema en X11, incluyendo escalas de 100%, 125% y 150%.

La resolución seleccionada establece el tamaño real del renderizado también en pantalla completa y sin bordes; se conserva la proporción de la imagen. Los cambios de tamaño, modo y posición se aplican mediante el nodo `Window`, para mantener sincronizados el renderizado y la entrada. `scripts/pointer_coordinates.gd` convierte la posición física del cursor mediante el mismo transformado del viewport y corrige los eventos desfasados antes de enviarlos a los menús. Apuntar en el mundo y dibujar el cursor usan esa misma posición. Los MSAA no admitidos se deshabilitan en el selector. `tests/settings_application.gd` comprueba cambios efectivos de HUD, audio, límite de FPS, modos, resolución, persistencia y clics nativos después de Aplicar. Las pruebas gráficas se ejecutan en X11; el funcionamiento en Windows requiere una comprobación en ese sistema.

En la pantalla X11 sin gestor de ventanas del entorno, la prueba de Aplicar verifica que pantalla completa cubra físicamente el escritorio y conserve resolución y clics. Solo se omite la confirmación del indicador EWMH de pantalla completa, que necesita ese gestor; se identifica como SKIP, no como prueba pasada.

## Guardado manual

Desde pausa pulsa **Guardar partida**. No hay autoguardado: salir sin guardar descarta los cambios posteriores al último guardado. **Continuar** recupera la partida abierta o, después de cerrar el juego, `user://day_zero_save.cfg`. Se conserva una partida con semilla y recursos recogidos o golpeados, posición, inventario, equipo, usos, accesos rápidos, nivel, puntos, habilidades, perks, vida, hora, calorías e hidratación. La escritura sustituye el archivo de forma atómica; los datos incompatibles o inválidos se rechazan.

La espada básica usa `assets/items/basic_sword.png`, procedente del PNG original entregado. Sus iconos y todos los clips completos se regeneran desde el mismo dibujo, con el grosor fino compartido y un tamaño de referencia de 32 unidades. El menú y el HUD toman sus plantillas de `assets/ui/title_template.png` y `assets/ui/hud_template.png`; los valores de vida, comida, agua y mapa son datos reales de la partida, no los valores de ejemplo impresos en la referencia.

## Bardana y primera receta de armadura

Se generan 24 plantas individuales en zonas de césped transitables y despejadas. Las dos imágenes se reparten por el terreno: `bardana1` da exactamente 5 hojas, `bardana2` da 3. Se recolectan con E y las manos libres, apuntando a la superficie y estando cerca. Desaparecen tras recogerlas y su estado se conserva al guardar. Los guardados anteriores reciben las nuevas plantas. El material utiliza el PNG original de la hoja.

**Armadura de hojas:** 15 hojas de bardana + 3 metros de cuerda + 20 de fibra. Se puede equipar en el torso y aparece también en el retrato del inventario. Su tejido de hojas sigue el movimiento de la piel en todas las poses, incluidas carrera, agachado, salto y herramientas. Todavía no aporta protección ni estadísticas y no tiene reparación. La fabricación puede usar materiales de mochila y barra rápida.

Todos los menús comparten la fuente del juego, excepto textos diminutos que priorizan legibilidad; abrir Configuración mantiene la fuente del menú de pausa detrás. Los avisos aparecen justo encima de la vida. El suelo usa textura fina de tonos próximos al césped y los grupos de hierba tienen menor contraste; se han retirado los parches grises rocosos antiguos.

Las barras inferiores se recortan siguiendo la silueta de marco y cabecera para que los píxeles de escenario de la plantilla no se dibujen en las esquinas. Pausa usa una fuente de mapa de bits creada a partir de las letras de sus botones originales, con letras acentuadas y tamaño ajustado al texto. El nuevo arco conserva su PNG, con cuerda, agarre e iconos propios. Hacha, pico y espada abren la trayectoria en vistas de frente, espalda y diagonales sin cambiar el ritmo ni la longitud de los huesos; ambos brazos quedan ocultos detrás de la espalda cuando corresponde.

La plantilla `tools/torso_armor.gd` envuelve el torso con una superficie de armadura ligada al mismo transform que la piel; cada armadura normal especifica su dibujo y perfil. El juego usa sprites completos ya exportados. Las animaciones combinadas de equipamiento se reparten en seis atlas por movimiento, cada uno de 2304×1536; la caché aplica un límite de 128 MiB. La máscara del personaje solo se redibuja cuando cambia la pose, y las mallas de impacto estáticas no actualizan sus transformaciones cada fotograma.

## Botella, rocas y terreno de referencia

La botella se fabrica con **3 cueros y 1 metro de hilo**. Estos materiales todavía no aparecen en el mundo; K permite conseguirlos para probar la receta. Cada botella usa un slot, se crea vacía y conserva su identidad al beber. Con la botella seleccionada, E sobre la superficie visible de un charco cercano la llena con 500 ml. Clic izquierdo o Beber en el inventario consume 250 ml por uso. Si la hidratación ya está llena no se desperdicia agua. Se muestra en la mano con sprites completos, también al caminar, correr o agacharse, con y sin armadura de hojas. Los guardados anteriores conservan sus botellas y el progreso de las rocas al migrar al formato 4.

Las piedras pequeñas se recogen con E y manos libres y dan entre 1 y 3 piedras. Las cuatro tallas de roca restantes requieren respectivamente 4, 7, 9 y 12 golpes de pico y dan 4, 8, 11 y 15 piedras. Se usan los diez PNG originales, dos siluetas por talla con tonos suaves.

El suelo toma las texturas de las referencias de terreno y las mezcla con rotaciones y offsets compartidos para evitar bordes de cuadrícula. Los senderos continuos forman curvas y cruces como las referencias, y cuatro manchas de tierra interrumpen la hierba. Los doce dibujos de césped válidos aparecen en la capa inferior; la distribución evita caminos, charcos, zonas de piedra y tierra y bases de objetos. `entregables/entorno/cesped/cesped_13.png` está truncado y no se incorpora hasta recibir un PNG válido. Los originales de entregables se conservan.

`tests/containers.gd` verifica la receta, volumen, identidad, límites de almacenamiento, migración y catálogo; `tests/container_ui.gd` usa clics nativos para probar el catálogo, Beber y la botella en la mano. `tests/interactions.gd` comprueba las manos libres, E, la superficie visible del agua y la distancia; `tests/ground_cover.gd` comprueba reproducibilidad y zonas despejadas en distintas semillas.

Los menús comparten la fuente de pausa. Solo los textos de 14 puntos o menos usan una fuente básica para mantener su legibilidad. Las piedras del mundo y su icono tienen un 10% menos de ancho y alto en el raster, conservando su tamaño físico; el relieve muscular del torso se ha reducido un 10%.


### Choza, estados y progresión

La primera choza usa `entregables/edificio/choza1.png`, con puerta proporcionada al
personaje. Acércate a la puerta y pulsa **E** para cambiar a la pantalla del interior:
una habitación vacía de madera, sin muebles. Su interior no se ve desde fuera.
La salida requiere E junto a la puerta interior y devuelve al punto de entrada.
El enemigo permanece fuera; el guardado manual conserva si estás dentro.

El joven tiene un abdomen un 35% más estrecho y una cabeza un 15% menor en sus tres
dimensiones. Mantiene la cabeza hacia delante al caminar sobre cuatro patas.
El stun dura **1,5 s**: seis poses de caída durante 0,24 s, 1,02 s en el suelo y
seis poses de recuperación durante 0,24 s. Un círculo amarillo pastel de 10 unidades,
con borde fino oscuro y separación de 3 unidades sobre la silueta, se vacía en
sentido horario. `status_effects.gd` y `enemy_status_indicator.gd` permiten compartir
esta presentación entre futuros enemigos y estados. Las alturas de los sprites
se guardan en el manifiesto para evitar leer las imágenes durante la animación.

La primera armadura de hojas conserva su tamaño y tiene un 25% más de resolución
en ancho y alto de textura e icono, con mayor definición local de hojas y ataduras.
Todas sus poses completas siguen el movimiento del torso.

**Misiones** y **Logros** aparecen a la derecha de Mapa. Están vacíos, pendientes de
contenido y recompensas definidos por el usuario. Solo se registran cinco fuentes
posibles de experiencia: misiones principales, misiones secundarias, logros, jefes
y fabricación. Recolectar o derrotar al joven no da experiencia. Las recompensas
nuevas aún no tienen valores automáticos. Se conserva la curva de nivel existente
y el único saldo de puntos compartido entre habilidades y perks.

Los menús y HUD utilizan los marcos y el relleno nuevos: variantes de menú para
los botones principal/pausa y configuración; variantes de juego para paneles,
inventario, mapa y HUD. Los botones con texto ajustan sus dimensiones a la etiqueta,
con un margen del 15% de la altura de texto por cada lado. Los slots conservan su
forma de almacenamiento. El marco NIVEL queda arriba a la izquierda del minimapa.
