# Renderizado y optimización 2.5D

Se han retirado dos atlas sin uso (3.045.388 bytes), el dibujado duplicado de herramientas y el antiguo recorte de cabeza. Los dos atlas activos del personaje añaden 335.290 bytes de detalle; el ahorro neto de imágenes es 2.710.098 bytes, unos 2,58 MiB.

Los recortes anatómicos, UV normalizadas, contornos del torso, geometría de herramientas y presentaciones de decorados se reutilizan. Las cachés anatómicas están acotadas por las ocho vistas; la de decorados se vacía al regenerar el mapa. Las sombras de objetos conservan sus comandos hasta que cambia el sol, se desplaza la cámara, cambia el mapa o se produce un impacto. En pausa se suspende la actualización de la superficie del personaje.

El personaje y su sombra reutilizan una superficie RGBA de 384 × 384. El aumento de detalle se rasteriza una vez a escala interna 3; esta superficie tiene más coste gráfico que la máscara anterior, pero evita componer por separado el personaje y su sombra. La iluminación y las colisiones siguen siendo 2D.

## Medición local

Godot 4.6.3, ejecución headless en este entorno. Se instancia `scenes/main.tscn`, se desactiva su procesamiento automático y se establece la orientación derecha con `game.movement.step(Vector2.RIGHT, 1, 220)`. Después de 50 llamadas de calentamiento a `game._process(1.0/60)`, se cronometran 3.000 llamadas mediante `Time.get_ticks_usec()`. Se repite tres veces, alternando el código anterior (`b31d9d6`) y esta revisión, sin otras pruebas en ejecución.

| Coste de actualización de scripts | Antes | Esta revisión |
| --- | ---: | ---: |
| Media de tres ejecuciones | 963,46 µs | 763,73 µs |
| Intervalo observado | 950,65–986,98 µs | 733,76–785,70 µs |

Esta muestra reduce el tiempo de actualización de scripts aproximadamente un 21%. Es una escena en reposo con el reloj avanzando y el hacha equipada: no mide GPU, rasterizado, FPS ni rendimiento de todos los estados. El mayor zoom también reduce el área del mundo visible. El coste gráfico deberá medirse en el equipo del jugador.

Las pruebas `clothing_volume.gd`, `tool_depth_render.gd` y `visual_integrity.gd` comprueban diversidad de poses, cachés acotadas, resolución interna, ocultación por píxeles y continuidad de partes. Las pruebas de sombras, movimiento, recolección, inventario y supervivencia completan la validación funcional.
