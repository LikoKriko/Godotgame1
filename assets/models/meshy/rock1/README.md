# Material de roca1

`model.res` comparte `surface_material.tres` entre afloramientos e instancias
de piedra. Conserva el modelo de 11931 triángulos, las UV originales y su altura
de 1 m. `albedo.png`, `normal.png`, `roughness.png` y `metallic.png` son las
fuentes aprobadas; sus huellas permanecen en `source.json`.

El material usa el albedo original y dos mapas derivados de 2048 × 2048:

- `surface_normal.png`: normal tangente original con intensidad de 1,8 en
  piedra y 1,25 en musgo, más relieve fino de superficie. El detalle se calcula
  en coordenadas físicas del modelo, con alturas de 0,09 mm para piedra y
  0,22 mm para musgo; no desplaza vértices ni modifica la silueta.
- `surface_roughness.png`: canal rojo, piedra entre 0,72 y 0,84 y musgo entre
  0,91 y 0,98. Conserva variaciones del mapa fuente; el musgo es más mate.

`surface_profile.json` contiene los parámetros de generación. La pertenencia
al musgo se obtiene del tono y saturación verdes del albedo, con transición
suave; no se pinta color adicional. El material tiene metal nulo, intensidad
normal 1 y filtrado lineal anisotrópico con mipmaps. La importación de rugosidad
usa el normal derivado para reducir brillos a distancia. El atlas incluye
12 píxeles de extensión alrededor de las islas UV.

## Regeneración

Desde la raíz, con Godot 4.7.2 y Python con NumPy, Pillow y SciPy:

```sh
mkdir -p work
godot --headless --path . --script tools/meshy/rock_material.gd -- --export work/rock1-mesh.json
python tools/meshy/bake_rock_surface.py work/rock1-mesh.json
godot --headless --path . --editor --import
godot --headless --path . --script tools/meshy/rock_material.gd -- --apply
```

El horneado comprueba las huellas originales y actualiza solo los mapas
derivados y su procedencia. `--apply` asigna el material sin reconstruir la
malla; `bake_props.gd` también lo conserva al importar roca1 desde su fuente.
