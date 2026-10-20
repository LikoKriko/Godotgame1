# Sistemas reutilizables

El mundo y las animaciones se definen mediante recursos editables de Godot.
Los perfiles actuales conservan el terreno, las especies y los rigs originales.

| Área | Definiciones editables | Herramientas compartidas |
| --- | --- | --- |
| Biomas | `data/world/biomes/`, `data/world/terrain/` | Densidad, población, texturas, muestreo determinista y copias para workers |
| Árboles Twisted Oak | `data/world/trees/twisted_oak.json` | Edición radial offline, corteza transferida, malla y colisiones compartidas; ver [TREES_3D.md](TREES_3D.md) |
| Modelado de mundo | `data/world/recipes/` | Caminos, rampas, montículos, baches, apoyos y escenas existentes |
| Personajes | `data/animation/characters/` | Anatomía humanoide, adaptación de proporciones y contactos |
| Enemigos | `data/animation/enemies/` | Anatomía por especie, cadenas de extremidades y fases de apoyo |
| Viento | `data/weather/soft_north_wind.tres` | Campo compartido en metros, ráfagas locales y entradas para materiales preparados |
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

## Contratos de reutilización

Consultar `docs/REUSABLE_SYSTEMS.md`. Definir nuevos terrenos mediante recetas
y perfiles de `data/world/`; reutilizar los generadores y comprobar las reservas
completas de historia. Mantener separados los perfiles de animación de Personajes
y Enemigos en `data/animation/characters/` y `data/animation/enemies/`, usando
las herramientas de `scripts/animation/shared/`. Conservar las fuentes originales
y revisar las adaptaciones de clips antes de incorporarlas al runtime.

## Fabricación y desbloqueos

Toda herramienta o arma nueva que no sea básica necesita como mínimo una mesa
de fabricación básica y no debe aparecer en Crear desde el inventario. Marcar
las básicas mediante `basic_tool`; el requisito se comprueba también al fabricar,
no solo en la interfaz. Las recetas de mesa deben respetar los desbloqueos.

La definición de herramientas y desbloqueos está en `scripts/inventory.gd`.
`scripts/workshop.gd` calcula `required_station_for` y filtra `recipe_ids`;
`craft` vuelve a comprobar desbloqueo y nivel de mesa. La presentación de
`scripts/creation_page.gd` no sustituye esa validación. Conservar también las
excepciones existentes de botella y mesa en `required_station_for`.
La prueba específica es `tests/workbench_station_rules.gd`.
Para elegir contexto y comprobaciones consultar [TASK_ROUTING.md](TASK_ROUTING.md).
