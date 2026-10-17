# Enemigo3: Sunny Sprout con su rig original

El FBX aportado por el usuario contiene una malla de **6791 vértices y 13582
triángulos**, un esqueleto de **35 huesos** (29 grupos de deformación) y ninguna
animación. Se conserva su geometría, proporciones, normales, UV y jerarquía,
incluidos los nombres de huesos. Altura original: aproximadamente **1,901 m**.
El frente mira hacia **+Z** en Godot. El menú **K → Añadir enemigo3** crea una
instancia de **0,9 m de altura** con una patrulla temporal de 20 metros de ida
y 20 de vuelta, en bucle. No tiene persecución, ataques ni aparición automática.

## Texturas

Los materiales del FBX apuntaban a rutas locales de Windows bajo
`C:/Users/nayel/Desktop/.../texture.fbm/`, ausentes en el repositorio. La escena
nativa enlaza los PNG suministrados: albedo y normal de 2048×2048; rugosidad y
metal de 4096×4096, cada uno con su canal rojo. Se conserva también el mapa
combinado metálico/rugosidad, sin aplicarlo a la vez que los mapas separados.
Los cinco PNG de `assets/enemies/third/sprout` son copias byte a byte de los
originales; sus SHA-256 y el del FBX constan en `source.json`.

Muestreo nearest con mipmaps, superficie opaca y mapa normal activo. No se
repintan ni reproyectan las texturas. La carpeta de entregables lleva
`.gdignore` para no importar otra copia del FBX con rutas rotas; el juego usa
la escena nativa de 35 huesos y sus texturas externas.

[Cuatro vistas con las texturas enlazadas](previews/enemy3_textures.png).

## Probar la caminata

Abrir **`scenes/prototype_3d/enemy3_review.tscn`** y pulsar **F6**:

- Cuatro vistas simultáneas con luz, suelo y sombras.
- **Espacio** pausa/reanuda; **R** muestra la pose original; **W** camina; **C** corre.
- La escena reproduce el clip guardado, no una simulación distinta del horneado.

[Ver la caminata animada](previews/enemy3_walk.gif) ·
[Captura de la caminata](previews/enemy3_walk.png).

**`scenes/prototype_3d/enemy3.tscn`** es el modelo reutilizable, con
`AnimationPlayer`, `walk`/`run` en bucle y `RESET` para recuperar la pose suministrada.
La animación tiene **1,25 segundos**, 61 muestras y 70 pistas de posición/rotación.
Camina en el sitio; al desplazarlo por un suelo plano, **0,2533 m/s** hacia +Z
coincide con la velocidad de apoyo de los pies. La raíz no se desplaza por el
clip. Hay un ajuste común de +0,015508 m para colocar la planta original sobre
el suelo; no se cambia su escala.

El generador `sprout_model.gd` reutiliza `continuous_body_pose.stance_swing` y
su IK de dos segmentos para muslo/rodilla/corvejón, conservando el segmento
inferior de la pata digitígrada. Los apoyos alternan cada medio ciclo, con
60 % de apoyo y 4,5 cm de elevación máxima. Brazos y cola acompañan suavemente.
Los cuatro huesos raíz independientes del FBX comparten la oscilación del
cuerpo. No se estiran los huesos; se conserva la pequeña pose original de la
muñeca al volver a `RESET`.

Godot admite un máximo de ocho influencias por vértice. La mayor parte del
rig original cabe sin recorte; **dos vértices tienen nueve pesos**. Solo se
omite su noveno peso, con una pérdida máxima de **0,018375** antes de
normalizar. No se recalculan los pesos ni se realiza una nueva ligadura.

## Regenerar y comprobar

Desde la raíz del repositorio, con Blender 4.3+ y Godot 4.7.2 disponibles:

```sh
mkdir -p /workspace/work/enemy3
blender -b -t 2 --python tools/enemy3/export.py -- /workspace/work/enemy3/rig.glb
godot --headless --editor --path . --import
godot --headless --path . --script tools/enemy3/bake.gd -- /workspace/work/enemy3/rig.glb
godot --headless --path . --script tools/enemy3/bake_walk.gd
godot --headless --path . --script tests/prototype_3d_enemy3.gd
```

El exportador selecciona solo la malla y el esqueleto; excluye cámara, luz y
círculo auxiliar del FBX. La escena nativa comparte malla/materiales entre
instancias y mantiene un esqueleto independiente para cada criatura.

Verificación realizada:

- Comparación independiente del FBX en Blender contra las matrices nativas de
  Godot: **error cero de posiciones y UV**; mismos 13582 triángulos, comparando
  sus esquinas sin depender del orden de índices.
- SHA-256 y comparación binaria de los cinco PNG originales.
- Pesos normalizados, enlaces válidos y conservación de los 35 huesos.
- Ciclo muestreado en 241 fases: longitudes constantes, trayectorias continuas,
  apoyos y elevación del pie. Piel deformada comprobada en 25 fases; el punto
  inferior queda aproximadamente a 0,0000006 m del suelo, sin penetración.
- Clip guardado probado en 121 fases contra el generador: tolerancia 0,8 mm;
  cierre de bucle, longitudes y restauración de la pose original.
- Render real de Godot Compatibility/OpenGL: cuatro vistas y 48 fotogramas.

El GIF se captura ejecutando la escena de revisión con
`-- --capture /workspace/work/enemy3/frames`; son capturas del motor.

## Aparición desde K y recorrido de prueba

`item_catalog.gd` añade el botón **Añadir enemigo3** junto al enemigo joven.
`world.spawn_sprout_near_player()` busca una posición a tres metros del jugador,
con un corredor completo libre de obstáculos y dentro de los límites del mundo.
Si no encuentra espacio para los veinte metros, el menú lo indica sin crear una
criatura dentro de una pared o árbol. Al cerrar K se reanuda la marcha.

`sprout_enemy.gd` controla un CharacterBody3D con gravedad y cápsula de 0,9 m.
Escala uniformemente el modelo por `0.9 / 1.9013426`, sin cambiar el FBX ni su rig.
`sprout_patrol.gd` separa los dos extremos, la dirección y el giro de la física;
los extremos siempre distan veinte metros. El giro de 180° dura 0,65 segundos.
La distancia usa metros reales del mundo, sin multiplicarla por la escala del
modelo; cada tramo termina antes de cambiar de dirección, sin teletransporte.

La fase de la caminata sigue el desplazamiento físico real y se detiene al
pausar, girar o quedar bloqueado. Se conserva la cadencia inicial del clip:
aproximadamente 0,12 m/s a esta escala. Es una caminata lenta de prueba.
La presentación nativa de referencia conserva los metros originales; la altura
de 0,9 m se aplica a las instancias del mundo.

Los enemigos3 usan el grupo propio `prototype_sprouts`, separado de los sistemas
de combate, cadáveres y conducta del enemigo joven. El guardado conserva posición,
fase, extremos, dirección y progreso del giro; las partidas anteriores sin este
campo siguen siendo válidas y se cargan sin crear enemigos3 adicionales.

[Botón del menú K](previews/enemy3_k_menu.png) ·
[Altura dentro del juego junto al superviviente](previews/enemy3_in_game.png).

Pruebas de integración: `tests/prototype_3d_sprout_patrol.gd` acciona el botón
real, comprueba corredores bloqueados, escala, pausa, tres tramos consecutivos
de veinte metros, vueltas, ausencia de saltos de posición y restauración de estado.
`tests/prototype_3d_saves.gd` añade el caso de guardado/carga real durante un giro.
`tools/enemy3/review_patrol.gd` reproduce las capturas del menú y del mundo.


## Carrera y ciclo temporal de prueba (17-10-2026)

Se añade `run.res` a la escena reutilizable y **C** a la revisión F6. Conserva
los 35 huesos, geometría, pesos, UV y PNG originales. `animate_run()` genera
la referencia; `tools/enemy3/bake_run.gd` hornea 70 pistas y 259 muestras adaptativas,
incluidos los instantes exactos de entrada/salida del apoyo y refinamiento
de la interpolación alrededor de la extensión de rodillas. El runtime reproduce
el clip guardado con AnimationPlayer; no ejecuta IK ni deforma vértices en CPU.

Torso y cabeza inclinan **60°** respecto a su pose original, con bisagra lumbar
en `Hueso.001`, sin inclinar las raíces de las piernas. El apoyo baja suavemente
la pelvis; rodillas, corvejones y pies resuelven una zancada amplia sin alargar
huesos. Brazos acompañan el paso contrario y la cola contrapesa. Ciclo de
**0,60 s**, apoyo del **42 %**, amplitud de zancada de **0,3192 m** por delante
y detrás a escala fuente, frente a los 0,095 m de la caminata. A escala de 0,9 m,
la velocidad de marcha es **0,119915 m/s** y la carrera **1,199153 m/s**,
exactamente diez veces mayor. La fase sigue la distancia física recorrida;
si se bloquea o gira, no sigue pedaleando. Se amplía solo el AABB de presentación
para cubrir el cuerpo inclinado, sin cambiar malla ni cápsula física.

Por la aclaración del usuario, las tres modalidades se prueban sobre la misma
patrulla de **20 m por tramo**, sin perseguir criaturas ni huir realmente del
jugador. `sprout_run_cycle.gd` separa el reloj de la física:

| Intervalo desde aparición | Conducta de prueba |
| --- | --- |
| 0–5 s | Marcha por la patrulla |
| 5–15 s | Carrera libre, 10 s |
| 15–20 s | Descanso, 5 s |
| 20–40 s | Carrera de persecución simulada, 20 s |
| 40–45 s | Descanso, 5 s |
| 45–85 s | Carrera de huida simulada, 40 s totales |
| 85–90 s | Descanso, 5 s; vuelve a carrera libre |

La prueba de huida alterna **8 s corriendo y 2 s parado**, cuatro veces:
32 s de carrera + 8 s de descanso dentro de sus 40 s. Los descansos generales
no se solapan con los internos. Los cambios de clip mezclan la pose durante
0,18 s. Los giros conservan su parada de 0,65 s y los relojes de prueba siguen
avanzando; la velocidad de carrera se refiere a los tramos en movimiento.
La pausa del juego congela movimiento y todos los temporizadores.

K comprueba ahora el corredor completo de veinte metros y sus extremos antes
de aparecer. Guardado opcional: fase de carrera, habilitación de la prueba,
modalidad, etapa y tiempo transcurrido; restaura descansos parciales y admite
archivos anteriores sin esos campos. `run_preview_enabled=false` conserva la
patrulla de marcha para comprobarla aisladamente. No se añaden objetivos,
percepción, ataques ni apariciones automáticas.

Pruebas: `prototype_3d_enemy3_run.gd`, `prototype_3d_enemy3.gd`,
`prototype_3d_sprout_patrol.gd` y `prototype_3d_saves.gd`. Cubren inclinación,
longitudes, bucle, apoyo real de piel, sincronía del clip horneado, temporizadores
a 30/60/120 FPS, saltos grandes de tiempo, velocidad física, pausas, menú,
corredores, recorrido de 20 m y guardado/carga real. La prueba de sesiones usa
el radio admitido de 100 m para aislar persistencia del coste del streaming.
