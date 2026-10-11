# Godotgame1 · Survival procedural 2D

Prototipo jugable con Godot 4.6.3 (edición estándar) y GDScript.

## Primera versión

- Mapa de prueba procedural de 32 × 24 casillas (2048 × 1536 px): un patio de cuarentena industrial oscuro, con tres tipos de suelo, maquinaria abandonada, obsidiana, árboles muertos y balizas rojas. Perímetro cerrado, plataforma inicial despejada y caminos conectados. Minimap para orientarse; F2 cambia la semilla y reinicia la partida.
- Dos tipos de enemigos, oleadas progresivamente más frecuentes, vida, muerte y reinicio.
- Seis armas seleccionables: espada, hacha, lanza, arco, bastón y dagas. Distintos daños, alcances y cadencias; combate cuerpo a cuerpo y proyectiles.
- Experiencia y niveles; seis ramas de habilidades con cinco rangos cada una (30 mejoras). Cada rango requiere el anterior. El panel pausa la partida.

Es una base para ampliar: todavía no incluye un árbol enorme de nodos ramificados, inventario, fabricación, recolección, guardado, animaciones de combate ni arte final. Los enemigos siguen rutas por el terreno y respetan los obstáculos; los proyectiles se detienen al impactar con el entorno. La elección de armas está disponible desde el inicio para probarlas.

## Ejecutar

Importa `project.godot` en Godot 4.6.3 y pulsa F5.

- WASD o flechas: movimiento.
- Clic izquierdo o espacio: atacar hacia el cursor.
- Teclas 1–6: cambiar arma.
- Tab: abrir/cerrar habilidades; pulsa una rama para gastar un punto.
- R: reiniciar la misma distribución después de morir.
- F2: generar otro mapa de prueba y reiniciar la partida.

## Terminal

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 120
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/movement.gd
godot --headless --path . --script res://tests/world.gd
```

En el entorno cloud se usan directorios XDG escribibles bajo `/workspace/shared` (ver instrucciones de inicio del entorno). No se necesitan servicios ni credenciales para ejecutar el juego.

## Estructura

`scenes/main.tscn` contiene la escena inicial. `scripts/main.gd` coordina combate, progresión y movimiento. `scripts/test_world.gd` genera el mapa, calcula colisiones y rutas. `scripts/world_view.gd` dibuja el suelo y las piezas de entorno de `assets/environment/quarantine_props.png`; `scripts/world_minimap.gd` presenta el minimapa. El siguiente paso es separar estos sistemas y definir los nodos del árbol y el catálogo de armas como recursos de datos.

El protagonista usa sprites en pixel art con traje y casco gris oscuro y detalles amarillos, creado a partir de la referencia visual del proyecto. Tiene ciclos de caminar de cuatro fotogramas para izquierda, derecha, arriba y abajo, y una pose de reposo por dirección. El ciclo se detiene al chocar o dejar de moverse. Los giros interpolan la orientación en hasta 0.28 segundos: la frenada máxima es del 35% para 180°, 8.75% para 90° y 2.19% para 45°. Al terminar, se recupera la velocidad máxima (incluyendo Agilidad); las diagonales no aumentan la velocidad. Un cambio de dirección durante el giro parte de la orientación actual. El entorno combina un atlas de suelos desgastados y otro de objetos en pixel art, con un sombreado suave en los bordes de pantalla; los enemigos conservan gráficos provisionales. `.godot/` contiene cachés locales y se excluye de Git. Las comprobaciones headless validan carga y lógica; el aspecto visual y los controles requieren prueba manual en el editor.

El movimiento se configura en `scripts/turn_motion.gd` (`MAX_TURN_TIME` y `MAX_SLOWDOWN`). Las animaciones se construyen desde `assets/characters/survivor_walk.png` en `scripts/survivor_frames.gd`, con alineación de pies para evitar saltos entre fotogramas. Las diagonales usan la vista cardinal más cercana. El personaje cambia de vista durante el giro sin rotar el sprite completo en el plano del suelo.

## Mapa de prueba

La semilla inicial es 73129. La misma semilla reproduce el mismo mapa; F2 la incrementa. El ruido distribuye los tres ambientes y una secuencia aleatoria por semilla coloca los obstáculos. Los caminos centrales y la zona inicial permanecen libres, y se comprueba la conectividad al generar. El tamaño está en `SIZE` y el origen en `FIRST` de `scripts/test_world.gd`. El patio tarda unos nueve segundos en cruzarse horizontalmente sin obstáculos a velocidad base. No hay zonas exteriores accesibles.

Los decorados son obstáculos, no recursos recolectables todavía. La atmósfera usa grises oscuros, púrpura apagado, amarillo industrial y rojo de alarma, manteniendo el terreno legible. La generación es deliberadamente pequeña y de un único patio; edificios con interiores y otros biomas quedan para futuras iteraciones.
