# Godotgame1 · Survival procedural 2D

Prototipo jugable con Godot 4.6.3 (edición estándar) y GDScript.

## Primera versión

- Mundo generado por coordenadas y ruido con semilla fija: tres biomas y árboles con colisión. Se dibuja el entorno alrededor del jugador sin almacenar todo el mapa.
- Dos tipos de enemigos, oleadas progresivamente más frecuentes, vida, muerte y reinicio.
- Seis armas seleccionables: espada, hacha, lanza, arco, bastón y dagas. Distintos daños, alcances y cadencias; combate cuerpo a cuerpo y proyectiles.
- Experiencia y niveles; seis ramas de habilidades con cinco rangos cada una (30 mejoras). Cada rango requiere el anterior. El panel pausa la partida.

Es una base para ampliar: todavía no incluye un árbol enorme de nodos ramificados, inventario, fabricación, recolección, guardado, animaciones ni arte final. Los enemigos no esquivan los árboles. La elección de armas está disponible desde el inicio para probarlas.

## Ejecutar

Importa `project.godot` en Godot 4.6.3 y pulsa F5.

- WASD o flechas: movimiento.
- Clic izquierdo o espacio: atacar hacia el cursor.
- Teclas 1–6: cambiar arma.
- Tab: abrir/cerrar habilidades; pulsa una rama para gastar un punto.
- R: nueva partida después de morir.

## Terminal

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --quit-after 120
godot --headless --path . --script res://tests/smoke.gd
```

En el entorno cloud se usan directorios XDG escribibles bajo `/workspace/shared` (ver instrucciones de inicio del entorno). No se necesitan servicios ni credenciales para ejecutar el juego.

## Estructura

`scenes/main.tscn` contiene la escena inicial. `scripts/main.gd` contiene generación, combate, progresión y presentación del prototipo. El siguiente paso es separar estos sistemas y definir los nodos del árbol y el catálogo de armas como recursos de datos.

Los gráficos se dibujan por código. `.godot/` contiene cachés locales y se excluye de Git. Las comprobaciones headless validan carga y lógica; el aspecto visual y los controles requieren prueba manual en el editor.
