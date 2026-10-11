# Godotgame1 · Exploración y recolección 2D

Prototipo con Godot 4.6.3 estándar y GDScript. Esta versión se centra en el personaje y la recolección: los enemigos, las oleadas y el combate están retirados temporalmente.

## Jugar

Importa `project.godot` en Godot 4.6.3 y pulsa F5.

- WASD o flechas: movimiento.
- Mantén E cerca de un árbol, roca o máquina para trabajar con la multiherramienta.
- Tab: abrir/cerrar el panel de habilidades; pausa el juego.
- R: reiniciar la prueba con la misma semilla. Restaura los recursos y vacía el inventario.
- F2: generar otro mapa y reiniciar la prueba, también vaciando el inventario.

El recurso al alcance se resalta y muestra cuántos golpes faltan. Árboles → madera; rocas → mineral; maquinaria abandonada → chatarra. Las balizas son decorativas. Una roca grande requiere seis golpes; los otros recursos, tres. Los materiales se añaden al inventario al agotar el objeto, que desaparece y libera su colisión. No se puede recolectar desde lejos ni a través de otro obstáculo.

El golpe tiene cuatro fotogramas por dirección: preparación, herramienta levantada, impacto y recuperación. El personaje se orienta al recurso y se queda quieto durante la acción. Moverse cancela el trabajo pendiente; un golpe que ya impactó se conserva. Mantener E repite el ciclo; soltarla permite terminar el golpe actual. El movimiento conserva sus cuatro animaciones, reposo por dirección y giros con frenada proporcional al ángulo.

La recolección da experiencia y puntos de habilidad. Hay seis ramas de cinco rangos: Silvicultura (+1 madera por árbol), Minería (+1 mineral por roca), Agilidad (+22 velocidad), Reciclaje (+1 chatarra por máquina), Ritmo (+12% velocidad de trabajo) y Sabiduría (+20% experiencia). No hay guardado persistente, fabricación, herramientas diferenciadas ni equipo todavía.

## Mapa

Patio procedural pequeño de 32 × 24 casillas (2048 × 1536 px), con suelo continuo gris carbón sin cuadrícula visible, decorados oscuros, árboles secos y cinco rocas grandes. La semilla inicial es 73129. F2 la incrementa; la misma semilla reproduce la distribución. Los caminos y la zona inicial están despejados. Las rocas grandes tienen colisión de 2 × 2 casillas, que se libera completamente al agotarlas. La cuadrícula es interna para navegación y colisión.

## Comprobaciones

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/smoke.gd
godot --headless --path . --script res://tests/movement.gd
godot --headless --fixed-fps 60 --path . --script res://tests/walk_cycle.gd
godot --headless --path . --script res://tests/world.gd
godot --headless --path . --quit-after 120
```

En cloud, usa los directorios XDG escribibles indicados en las instrucciones del entorno bajo `/workspace/shared`. No se necesitan servicios ni credenciales para jugar.

## Archivos

- `scripts/main.gd`: personaje, acciones, inventario visible y habilidades.
- `scripts/harvesting.gd`: alcance, recursos, golpes, inventario y agotamiento.
- `scripts/test_world.gd`: generación y colisiones.
- `scripts/world_view.gd`: suelo y decorados; `scripts/world_minimap.gd`: minimapa.
- `scripts/turn_motion.gd`: giros (hasta 0.28 s; frenada máxima 35% en 180°, 8.75% en 90° y 2.19% en 45°).
- `scripts/survivor_frames.gd`: animaciones desde los atlas de caminar y recolectar. Las diagonales usan la vista cardinal más cercana.
- `shaders/quarantine_ground.gdshader`: suelo uniforme continuo; `shaders/atmosphere.gdshader`: sombreado de bordes.

Los atlas están en `assets/`; `.godot/` contiene cachés locales excluidas de Git. El atlas antiguo de suelos se conserva como recurso sin uso. Los materiales son contadores de inventario provisional, no objetos soltados en el suelo. Las comprobaciones automáticas validan lógica y carga; la sensación del movimiento y las animaciones requiere también jugar en el editor.
