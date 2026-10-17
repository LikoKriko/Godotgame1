# Day Zero: estado actual del juego 3D

La rama principal es `main`. Abrir `project.godot` con Godot 4.7.2 y pulsar F5.
El menú inicial permite iniciar una partida, continuar, configurar y salir.

## Personaje y cámara

| Parámetro | Valor |
| --- | --- |
| Altura | 1,75 m |
| Peso de referencia | 60 kg |
| Velocidad de caminar | 2 m/s |
| Velocidad de correr | 3,2 m/s |
| Distancia de cámara | 3,6 m |
| Desplazamiento al hombro | 0,30 m |
| Campo de visión | 75° |
| Inclinación de cámara | −90° a +90° |

El personaje puede caminar, correr, agacharse, deslizarse, saltar, recoger,
equipar objetos, comer, beber, bloquear y usar armas. La cámara evita atravesar
paredes y copas. El modelo tiene un esqueleto de 24 huesos, con controles de
ropa y volumen de articulaciones. Las colisiones mantienen sus dimensiones
independientemente del detalle visual.

## Controles

| Entrada | Acción |
| --- | --- |
| WASD | Movimiento relativo a la cámara |
| Ratón | Mirar y apuntar |
| Shift | Correr |
| Ctrl | Agacharse; al correr, deslizarse |
| Espacio | Saltar |
| Clic izquierdo | Usar el objeto o arma |
| E | Interactuar, recoger o rellenar una botella cercana al agua |
| 1–6 | Seleccionar acceso rápido |
| F | Parry |
| I / T | Inventario / creación |
| M | Mapa |
| K | Catálogo de objetos y aparición manual de criaturas |
| Z / X | Impulso / golpe potenciado |
| Esc | Pausa |

## Criaturas

| Criatura | Altura en partida | Velocidad | Comportamiento |
| --- | --- | --- | --- |
| [Enemigo1](YOUNG_3D.md) | 0,875 m | 0,85 m/s al deambular; 1,7 m/s al perseguir | Cuadrúpedo, agresivo, memoria, alimentación, descanso, sueño y boxeo |
| [Enemigo3](ENEMY3_3D.md) | 0,9 m | Aproximadamente 0,120 m/s | Patrulla de diez metros de ida y vuelta; aparición manual desde K |

## Inventario e interacciones

La mochila tiene 32 huecos, el equipo cinco y el acceso rápido seis huecos
físicos. Arrastrar mueve o intercambia objetos; Shift + clic transfiere entre
mochila y equipo/acceso rápido. El retrato del inventario es un render del
personaje 3D con su vestimenta. Abrir inventario, creación o catálogo pausa
la partida. Hay fabricación, reparación, habilidades y perks con puntos
compartidos. Las herramientas avanzadas requieren mesa de fabricación.

Los árboles adultos requieren hacha; las rocas de la familia roca1 requieren
pico y miden un metro de alto. Los arbolitos admiten golpes con manos libres.
Bardana y piedras pequeñas se recogen con E y manos libres. La botella se
rellena cerca del agua. Los objetos tirados tienen representación física.

Los golpes se dirigen al contacto de la mira, respetando alcance, obstáculos y
agarres. El desgaste se aplica según la acción y el contacto. El arco necesita
una flecha y 0,5 s de tensado. El parry tiene 4 s de recuperación, acepta
intentos desde 0,5 s antes hasta 0,2 s después del contacto y aturde 1,5 s.
El daño enemigo se resuelve con 0,35 s de retraso.

## Mundo y supervivencia

El mundo mide 6,4 × 6,4 km: **40,96 km²**. Se genera por proximidad con semilla
persistente. Incluye árboles, rocas, bardanas, césped, agua, elevaciones y seis
edificios de campamento. Los interiores se cargan al aproximarse a sus puertas.
Las puertas permiten al jugador entrar y mantienen a las criaturas fuera.

La partida comienza a las 08:00 del día 1. Un día dura 16 minutos reales;
el amanecer es a las 06:00 y el anochecer a las 20:00. El personaje consume
alimentos y agua; comer o beber tarda 1,2 s y aplica el consumo al terminar.
Puede caminar durante esas acciones.

## Configuración

- Juego: correr automáticamente y cinco tamaños del HUD.
- Gráficos: VSync, límite de FPS, Mostrar FPS, antialiasing 3D y generación de
  mundo a 100, 200 o 400 metros; 200 es el valor predeterminado.
- Audio: volumen general, música, efectos y silencio.

Mostrar FPS está desactivado de inicio. Al activarlo aparece a la izquierda
del nivel, con el mismo tamaño del HUD y lectura cada 0,25 s. Los ajustes
se aplican y se guardan al cambiarlos. Resolución y modo de pantalla están
bloqueados temporalmente.

## Partidas

El guardado manual se realiza desde la pausa. Conserva semilla, posición,
recursos modificados, inventario, progreso, reloj, nutrición, objetos, mesas y
estado de las criaturas, incluida la patrulla de enemigo3. Usa datos validados,
archivo temporal y copia de respaldo. Algunas acciones en curso deben terminar
o cancelarse antes de guardar. Continuar prepara directamente la zona guardada.

## Documentación específica

- [Generación del mundo](WORLD_STREAMING.md).
- [Detalle por distancia](DISTANCE_OPTIMIZATION.md).
- [Sombreado y animaciones](SHADING_ANIMATION_OPTIMIZATION.md).
- [Modelos, tamaños y materiales](MESHY_ASSETS.md).
- [Animación](ANIMATION_AREA.md) y [armas](WEAPON_ANIMATIONS_3D.md).
- [Árboles](TREES_3D.md) y [recursos compartidos](SHARED_RESOURCES.md).
