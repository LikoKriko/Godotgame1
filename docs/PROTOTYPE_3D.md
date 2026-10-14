# Prototipo 3D de Day Zero

Esta primera prueba vive en `prototype/third-person-3d`. `main` conserva el juego
2D. Descargar el ZIP **después de seleccionar esta rama**, importar
`project.godot` en Godot 4.7.2 y ejecutar con F5.

La escena inicial es `scenes/prototype_3d/day_zero_3d.tscn`. Incluye:

- Personaje con cuerpo y ropa de superficies continuas, cabeza, cabello y rostro
  con volumen. Conserva los colores, pantalones, barba y marca azul del diseño.
- Hacha sólida con madera partida, cuerda cruzada y hoja de piedra extruida.
- Cámara en perspectiva sobre el hombro derecho, inspirada en la vista de
  Deadlock. El ratón gira cámara y orientación del personaje; WASD mueve respecto
  a la cámara. Una esfera detecta paredes y árboles y acerca la cámara.
- Caminata, carrera, agacharse, caminar agachado, deslizamiento y salto, con
  transiciones suaves. Sacar el hacha permite seguir desplazándose.
- Árboles con tronco, ramas, raíces y copa. Tres golpes cercanos, apuntando con
  la mira al tronco, entregan cuatro unidades de madera al inventario existente.
- Sombras 3D reales y un suelo que reutiliza la textura del terreno actual.

**Controles:** WASD, ratón, Shift para correr, Ctrl para agacharse (o deslizarse
si estás corriendo), Espacio para saltar, 1 para alternar
hacha/manos, clic para talar, Esc para pausa y liberar el ratón. Desde pausa puede
abrirse la escena 2D original. Este prototipo no escribe ni modifica partidas 2D.

Los modelos son una primera base para probar volumen, cámara y movimiento;
todavía no representan la migración completa del juego. Inventario visual,
campamento, criaturas, crafteo, guardado y generación del mundo se trasladarán
tras revisar esta base.

## Arquitectura

`scripts/prototype_3d/` separa mundo, controlador físico, cámara y modelos.
`survivor_model.gd` reutiliza anatomía e IK de `tools/continuous_actor.gd`; cambia
la cabeza plana y las herramientas por superficies 3D. `humanoid_rig.gd` crea
una única malla con pesos normalizados y un `Skeleton3D` de 16 articulaciones;
las poses animan los huesos, sin reconstruir geometría. Los objetivos se mezclan
de forma continua y después se resuelven las extremidades para conservar su
longitud. Se reutiliza `locomotion.gd` para Ctrl y la inercia del salto encadenado.
La escala es 1,8 metros / 64 unidades del dibujo original.

El personaje utiliza un atlas de materiales pintados: piel, tela, pelo y cuerda.
Las coordenadas se calculan una vez en la pose de reposo y permanecen unidas a
la piel durante la animación. Los rasgos de la cara conservan sus colores propios.
El torso es una superficie continua, sin las esferas separadas de músculo de
la primera prueba. Estas animaciones son una primera pasada para revisar.

Cámara: distancia 3,6 m, hombro 0,60 m, FOV 75°, sensibilidad 0,0025 rad/píxel,
inclinación −60° a +65°. Personaje: caminar 2 m/s y correr ×1,6. Árboles: tres
impactos y alcance máximo de 2,4 m. Estos parámetros están en los controladores.

## Comprobaciones

Ejecutar con Godot 4.7.2:

```sh
godot --headless --path . --script tests/prototype_3d.gd
godot --headless --path . --script tests/prototype_3d_movement.gd
```

Comprueban pesos de piel, longitud de huesos, agarres, persistencia de malla,
desplazamiento lateral y hacia atrás, alcance, desgaste, cámara y controles con
la física real. El renderizado de las poses también se revisa en modo gráfico.
