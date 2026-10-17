# Sombreado y ciclos de animación

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
piernas y brazos; se conservan como referencias fijas del esqueleto.
Esto beneficia también a las acciones que siguen siendo procedurales.

Se generan keyframes compartidos para caminar, correr, sentarse, dormir,
guardia de boxeo y marcha de boxeo. Hay 256 intervalos iniciales por ciclo; se
subdividen donde la interpolación se separa más de 0,001 unidades de autoría de
la pose original, hasta un máximo de ocho subdivisiones. El esqueleto vuelve a resolver las cadenas de
brazos y piernas al interpolar, conservando la longitud de todos los huesos.

Los clips se preparan una sola vez, durante la pantalla de carga, y se
comparten entre instancias. Se generan desde las funciones actuales de autoría;
no hay un archivo horneado que quede obsoleto al modificar las animaciones.
El reposo utiliza su función procedural. Ataques, caídas y transiciones conservan sus funciones
originales, así como sus tiempos. Continúan las mezclas de pose existentes,
el reloj facial independiente, las colisiones y el guardado.
