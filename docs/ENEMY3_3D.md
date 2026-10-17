# Enemigo3: Sunny Sprout

## Parámetros en partida

| Parámetro | Valor actual |
| --- | --- |
| Altura | 0,9 m |
| Velocidad de marcha | Aproximadamente 0,120 m/s |
| Velocidad de carrera | Aproximadamente 1,199 m/s |
| Distancia entre extremos | 20 m |
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
el campo `sprouts`.

## Modelo y materiales

El FBX original es `entregables/enemigos/enemigo3/modelo_enemigo3.fbx`.
Se mantienen geometría, UV, PNG y rig propios. La altura del modelo fuente es
1,9013426 m; la escala de partida es `0.9 / 1.9013426`. Su velocidad sin esa
escala es 0,253333 m/s, por lo que en partida resulta aproximadamente 0,120 m/s.
El frente mira hacia +Z en Godot.

Albedo y normal son de 2048×2048; metal y rugosidad, de 4096×4096. Se utiliza
muestreo nearest con mipmaps. Materiales y procedencia están en
`assets/enemies/third/sprout/source.json`.

`scenes/prototype_3d/enemy3.tscn` expone `walk` y `RESET` mediante AnimationPlayer, además del clip `run`.
`sprout_model.gd` define las poses; `sprout_enemy.gd`, movimiento y física;
`sprout_patrol.gd`, extremos y giros. La animación usa 61 muestras y 70 pistas
sobre su rig original. No sustituirlo por el esqueleto de otra criatura.

## Carrera y ciclo de presentación

La carrera dura 0,60 s por ciclo, con apoyo del 42 %. Torso y cabeza se
inclinan 60° y la velocidad física es diez veces la marcha. La fase sigue
la distancia recorrida. Las transiciones entre clips se mezclan durante 0,18 s.

Al aparecer camina 5 s. Después alterna estas modalidades sobre la misma
patrulla, con descansos de 5 s entre ellas:

| Modalidad | Duración | Movimiento |
| --- | --- | --- |
| Carrera libre | 10 s | Carrera continua |
| Persecución simulada | 20 s | Carrera continua, sin objetivo de persecución |
| Huida simulada | 40 s | 8 s corriendo y 2 s parado, repetidos cuatro veces |

El ciclo se repite desde carrera libre. Los giros duran 0,65 s, con el actor
parado y el reloj de modalidad avanzando. La pausa congela todos los relojes.
El guardado conserva modalidad, fase, etapa y tiempo transcurrido.
`run_preview_enabled=false` deja únicamente la marcha por la patrulla.
Estas modalidades no añaden detección, objetivos de combate ni apariciones
automáticas. El modelo reutilizable conserva `walk`, `run` y `RESET`.
