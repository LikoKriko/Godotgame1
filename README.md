# Day Zero · Supervivencia en tercera persona 3D

Juego desarrollado con **Godot 4.7.2 estándar y GDScript**. La rama principal
es **`main`**. El juego 2D se ha retirado; se conservan los sistemas compartidos
y las imágenes que todavía usa el 3D para texturas, iconos e interfaz.

## Jugar

Descarga o clona `main`, importa `project.godot` en Godot 4.7.2 y pulsa **F5**.
La escena inicial `scenes/prototype_3d/day_zero.tscn` abre el menú principal:
Jugar inicia una partida y Continuar recupera la última partida guardada.

- **WASD**: moverse; **ratón**: mirar y apuntar.
- **Shift**: correr; **Ctrl**: agacharse o deslizarse al correr; **Espacio**: saltar.
- **Clic izquierdo**: usar el objeto o arma; **E**: interactuar y recoger.
- **1–6**: accesos rápidos; **F**: parry.
- **I**: inventario; **T**: creación; **M**: mapa.
- **K**: catálogo de objetos y criaturas; **Esc**: pausa y opciones de guardado.

El mundo mide **6,4 × 6,4 km (40,96 km²)** y se genera alrededor del personaje.
Configuración → Gráficos → Generación de mundo permite elegir **100, 200 o
400 metros**; 200 es el valor inicial. Incluye optimización de detalle por
distancia, suspensión de enemigos lejanos, máscaras de terreno en caché y
keyframes compartidos para los ciclos del enemigo.

## Documentación

- [Estado, controles y sistemas 3D](docs/PROTOTYPE_3D.md).
- [Mundo procedural y persistencia](docs/WORLD_STREAMING.md).
- [Modelos originales Meshy y regeneración](docs/MESHY_ASSETS.md).
- [Funcionamiento de las animaciones](docs/ANIMATION_AREA.md).
- [Modelo y caminata de enemigo3](docs/ENEMY3_3D.md).
- [Optimización de sombreado y animación](docs/SHADING_ANIMATION_OPTIMIZATION.md).
- [Recursos compartidos](docs/SHARED_RESOURCES.md).
- [Entregables de los departamentos](entregables/README.md).

Los modelos vigentes proceden de los FBX aportados por el usuario. Sus PNG,
UV y geometría originales se conservan. `entregables/` contiene fuentes y
referencias de los departamentos; los recursos integrados están en `assets/`.
