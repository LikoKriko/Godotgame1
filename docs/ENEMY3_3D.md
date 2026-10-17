# Enemigo3: Sunny Sprout con su rig original

El FBX aportado por el usuario contiene una malla de **6791 vértices y 13582
triángulos**, un esqueleto de **35 huesos** (29 grupos de deformación) y ninguna
animación. Se conserva su geometría, proporciones, normales, UV y jerarquía,
incluidos los nombres de huesos. Altura original: aproximadamente **1,901 m**.
El frente mira hacia **+Z** en Godot. No se ha añadido IA, combate ni generación
del enemigo en el mundo: esta entrega permite revisar el modelo y su primera
caminata antes de esa integración.

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
- **Espacio** pausa/reanuda; **R** muestra la pose original; **W** camina.
- La escena reproduce el clip guardado, no una simulación distinta del horneado.

[Ver la caminata animada](previews/enemy3_walk.gif) ·
[Captura de la caminata](previews/enemy3_walk.png).

**`scenes/prototype_3d/enemy3.tscn`** es el modelo reutilizable, con
`AnimationPlayer`, `walk` en bucle y `RESET` para recuperar la pose suministrada.
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
