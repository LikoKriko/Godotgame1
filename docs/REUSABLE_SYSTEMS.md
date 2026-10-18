# Sistemas reutilizables

El mundo y las animaciones se definen mediante recursos editables de Godot.
Los perfiles actuales conservan el terreno, las especies y los rigs originales.

| Área | Definiciones editables | Herramientas compartidas |
| --- | --- | --- |
| Biomas | `data/world/biomes/`, `data/world/terrain/` | Densidad, población, texturas, muestreo determinista y copias para workers |
| Modelado de mundo | `data/world/recipes/` | Caminos, rampas, montículos, baches, apoyos y escenas existentes |
| Personajes | `data/animation/characters/` | Anatomía humanoide, adaptación de proporciones y contactos |
| Enemigos | `data/animation/enemies/` | Anatomía por especie, cadenas de extremidades y fases de apoyo |
| Acabado de iluminación | `data/rendering/lighting_finish_trial.tres` | Paleta natural estilizada, relleno, cielo y atmósfera ligados al reloj |
| Sombras del sol | `data/rendering/sun_shadows_trial.tres` | Perfil compartido de cascadas, sesgos y filtrado; comparación en Gráficos |
| Animación compartida | `scripts/animation/shared/` | Enlace de huesos, IK en metros, escritura de poses y adaptación de clips |

El uso del modelador se describe en [WORLD_AUTHORING.md](WORLD_AUTHORING.md).
La separación de animación y sus herramientas se describen en
[ANIMATION_SYSTEMS.md](ANIMATION_SYSTEMS.md).

Los generadores consultan las reservas de historia antes de colocar la huella
completa de una parte o modelo. Los IDs y las semillas permanecen estables.
No se modifican FBX, UV, skin ni geometría originales para adaptar una animación.
Las escenas exportadas por las herramientas son resultados de autoría; el
mundo jugable mantiene su carga por proximidad y sus presupuestos de fotograma.
