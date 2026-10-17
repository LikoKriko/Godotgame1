# Enemigo3: Sunny Sprout

## Parámetros en partida

| Parámetro | Valor actual |
| --- | --- |
| Altura | 0,9 m |
| Velocidad de patrulla | Aproximadamente 0,120 m/s |
| Distancia entre extremos | 20 m |
| Velocidad de carrera | Aproximadamente 1,199 m/s; diez veces la marcha |
| Ciclo de carrera | 0,60 s |
| Inclinación de torso y cabeza al correr | 60° respecto a la pose original |
| Tiempo de giro | 0,65 s |
| Ciclo de caminata | 1,25 s |
| Esqueleto | 35 huesos originales |
| Malla fuente | 6791 vértices; 13582 triángulos |
| Aparición | K → Añadir enemigo3 |

Patrulla veinte metros de ida y veinte de vuelta, en bucle. Se detiene para girar,
usando la pose de reposo, y reanuda la caminata en la dirección contraria.
La fase de los pies depende de la distancia realmente recorrida. Tiene gravedad,
colisiones y cápsula de 0,9 m de alto y 0,19 m de radio. Pausar detiene la marcha.
No tiene persecución, combate ni apariciones automáticas.

Al añadirlo se busca una posición a tres metros del jugador y un corredor libre
para la patrulla. Si no hay espacio, se indica en el catálogo sin crear la
criatura. El guardado conserva posición, fase, extremos, dirección y giro en
el campo `sprouts`. También conserva fase de carrera, modalidad y tiempo
transcurrido, incluidos los descansos parciales.

## Modelo y materiales

El FBX original es `entregables/enemigos/enemigo3/modelo_enemigo3.fbx`.
Se mantienen geometría, UV, PNG y rig propios. La altura del modelo fuente es
1,9013426 m; la escala de partida es `0.9 / 1.9013426`. Su velocidad sin esa
escala es 0,253333 m/s, por lo que en partida resulta aproximadamente 0,120 m/s.
El frente mira hacia +Z en Godot.

Albedo y normal son de 2048×2048; metal y rugosidad, de 4096×4096. Se utiliza
muestreo nearest con mipmaps. Materiales y procedencia están en
`assets/enemies/third/sprout/source.json`.

`scenes/prototype_3d/enemy3.tscn` expone `walk`, `run` y `RESET` mediante AnimationPlayer.
`sprout_model.gd` define las poses; `sprout_enemy.gd`, movimiento y física;
`sprout_patrol.gd`, extremos y giros. La caminata usa 61 muestras y la carrera 259 muestras adaptativas,
ambas con 70 pistas sobre su rig original. No sustituirlo por el esqueleto de otra criatura.


## Ciclo de carrera para revisión

La aparición desde K inicia cinco segundos de marcha y después alterna estas
modalidades sobre la patrulla, sin detección ni objetivos reales:

| Modalidad de prueba | Duración |
| --- | --- |
| Carrera libre | 10 s |
| Carrera de persecución simulada | 20 s |
| Carrera de huida simulada | 40 s totales |

Entre modalidades descansa cinco segundos. La huida alterna ocho segundos
corriendo y dos parado, cuatro veces: 32 s de carrera y 8 s de pausa dentro
de los 40 s. Tras el último descanso vuelve a carrera libre. Los giros conservan
su parada de 0,65 s; el reloj del ciclo sigue avanzando durante ellos. La pausa
del juego congela todos los relojes y el movimiento. Los cambios de pose mezclan
durante 0,18 s. `run_preview_enabled=false` permite revisar solo la marcha.

La carrera baja el apoyo de pelvis y usa zancada amplia, rodillas/corvejones
resueltos con longitudes fijas, brazos alternos y cola de contrapeso. El runtime
reproduce el clip horneado; la referencia está en `animate_run()` y el generador
en `tools/enemy3/bake_run.gd`. No modifica malla, pesos, UV ni texturas.
En `enemy3_review.tscn`, W muestra caminata, C carrera y R la pose original;
Espacio pausa/reanuda las cuatro vistas.
