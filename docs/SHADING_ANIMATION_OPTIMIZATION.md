# Primera optimización de sombreado y animación

16 de octubre de 2026. Comparativas completas en
[la galería de antes/después](previews/shading-animation-2026-10-16/README.md).
Los FBX, PNG originales y recursos de geometría permanecen intactos.

## Terreno: máscaras en caché

`terrain_mask_cache.gd` prepara los pesos de biomas, caminos e influencias en un
hilo secundario. Usa la misma semilla, umbrales y sampler del mundo. Guarda los
cuatro pesos en RGBA de media precisión, en una cuadrícula global de ocho
unidades de autoría (0,21875 m), con borde para interpolar entre chunks. Un
chunk normal de 28 m usa 131×131 texels: aproximadamente 134 KiB de datos de
máscara sin mipmaps, además de la textura y metadatos del motor.

`chunk_ground_cached.gdshader` consulta esa máscara, conservando el muestreo de
las cuatro texturas originales y el detalle procedural que distribuye sus
muestras. La iluminación, material rugoso y coordenadas de píxel siguen
calculándose como antes. Los mipmaps y presupuestos visuales por distancia
continúan funcionando: la máscara usa LOD 0 para conservar la distribución de
biomas, mientras que las texturas de detalle reciben su sesgo de distancia.

Mientras una máscara está pendiente se utiliza el shader original. Las zonas
próximas tienen prioridad; al cambiar influencias se invalidan los resultados
anteriores. Al descargar definitivamente un chunk se elimina su máscara, y los
trabajos caducados no pueden volver a publicarla. Las imágenes se calculan en
CPU y las texturas de render se crean en el hilo principal. La caché permanece
limitada por los chunks activos y la corona de retención del renderer.

## Enemigo: keyframes compartidos y referencias del esqueleto

Se reutilizan las matrices inversas de los ocho segmentos de referencia de
piernas y brazos; sus valores coinciden exactamente con el cálculo anterior.
Esto beneficia también a las acciones que siguen siendo procedurales.

Se generan keyframes compartidos para caminar, correr, sentarse, dormir,
guardia de boxeo y marcha de boxeo. Hay 256 intervalos iniciales por ciclo; se
subdividen donde la interpolación se separa más de 0,001 unidades de autoría de
la pose original, hasta un máximo de ocho subdivisiones. Los clips medidos
contienen entre 257 y 309 poses. El esqueleto vuelve a resolver las cadenas de
brazos y piernas al interpolar, conservando la longitud de todos los huesos.

Los clips se preparan una sola vez, durante la pantalla de carga, y se
comparten entre instancias. Se generan desde las funciones actuales de autoría;
no hay un archivo horneado que quede obsoleto al modificar las animaciones.
El reposo permanece en su función original porque la prueba de keyframes por
sí sola no lo aceleraba. Ataques, caídas y transiciones conservan sus funciones
originales, así como sus tiempos. Continúan las mezclas de pose existentes,
el reloj facial independiente, las colisiones y el guardado.

## Mediciones

Godot 4.7.2, Compatibility/OpenGL, Linux y Mesa llvmpipe. Se miden escenas y
llamadas aisladas; estos resultados no son una medición de FPS en el PC del
usuario ni garantizan una mejora equivalente del juego completo.

Terreno a 640×640 píxeles, cámara y luz fijas. Mediana de cinco bloques de 30
fotogramas por modo, alternando el orden antes/después dentro de la misma
sesión, tras calentar los shaders y terminar las máscaras:

| Escena | Antes | Después | Menos tiempo |
| --- | --- | --- | --- |
| Terreno y camino | 30,04 ms | 21,84 ms | 27,3 % |
| Coordenadas negativas | 31,82 ms | 23,16 ms | 27,2 % |
| Coordenadas lejanas | 24,49 ms | 17,75 ms | 27,5 % |

Animación del enemigo con `delta=1/60`, incluyendo las mezclas existentes:
mediana de cinco bloques alternados de 3000 llamadas por modo. El conjunto
muestra un 9,8–16,1 % menos de tiempo de CPU; caminar pasa de 75,88 a 68,43 µs,
correr de 80,38 a 68,76 µs y la marcha de boxeo de 79,50 a 66,71 µs. La
preparación inicial queda fuera de estas cifras y se mide por separado: unos
30–40 ms por clip, durante la carga. Los datos completos están en los JSON de
la galería.

## Comparación visual y comprobaciones

37 parejas de PNG sin pérdidas, a 640×640: nueve capturas del terreno —tres
ubicaciones a calidad 100/65/35 %—, 24 poses de seis ciclos y cuatro muestras de
una transición con mezcla. Se comparan las funciones originales con las cachés
activadas, con idénticas cámaras, fases e iluminación.

En terreno, el error medio por canal de las nueve capturas está entre 0,004 y
0,033 sobre 255; el máximo es de cuatro niveles y ningún píxel supera ocho.
Las cuatro capturas de reposo del enemigo coinciden píxel a píxel. En las
otras poses y mezclas cambia como máximo el 0,129 % de los píxeles de la imagen;
los cambios de más de ocho niveles afectan como máximo al 0,0083 %. Hay pequeñas
diferencias en píxeles de bordes y detalle al interpolar; no se declara identidad
visual absoluta. En las pruebas densas de articulaciones, el máximo desvío es
0,001086 unidades de autoría y el error de longitud ósea es menor que 0,00001.

Pruebas: keyframes/anatomía **126372**, máscaras y descarga **11**, rutina
**3691**, cara **248391**, boxeo **4465**, distancia **43**, guardado **44**,
mundo ampliado **207**, pulido de animación **5733** y contactos de herramientas
**1983**. Revisión nativa del terreno y de los shaders a los tres niveles de
calidad. La prueba de continuidad espera ahora expresamente las máscaras.

Se descartaron dos prototipos de caché del ruido: preservaban mejor los valores
intermedios, pero añadían lecturas de textura sin una mejora de tiempo útil. La
versión publicada guarda solo las máscaras lentas. También se corrigió el
orden de las declaraciones del nuevo shader para que los helpers de calidad
por distancia compilen antes de sus llamadas.

## Reproducción

```sh
godot --path . --headless --script tests/prototype_3d_keyframe_cache.gd
godot --path . --headless --script tests/prototype_3d_terrain_mask_cache.gd
godot --path . --headless --script tools/optimization/profile_enemy_animation.gd -- /tmp/enemy-timing.json
godot --path . --rendering-method gl_compatibility --script tools/optimization/compare_shading_animation.gd -- /tmp/shading-comparison
```

La última orden necesita renderizador nativo y genera ambas series y los tiempos.
Los controles internos de referencia de estos scripts sirven para comparar el
cálculo original; no añaden opciones nuevas al menú del juego.
