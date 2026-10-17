# Animación de Personajes y Enemigos

## Personajes

`scripts/animation/characters/humanoid_profile.gd` define una anatomía humanoide
común: raíz, torso, cabeza, dos brazos y dos piernas. El recurso del superviviente
está en `data/animation/characters/survivor.tres`; el rig real lo enlaza al
prepararse y conserva sus 24 huesos, incluidos tela y volúmenes articulares.

Los modelos humanoides compatibles pueden compartir clips y adaptar sus
referencias de altura, anchura y profundidad. `adapt_contact(offset, target)`
convierte un desplazamiento respecto de un anclaje corporal acordado a las
proporciones del destino. Las medidas están en unidades del rig: el superviviente
usa 64 unidades de altura, con conversión a 1,75 m en el juego. Los destinos
conservan la longitud de sus propios huesos y sus anclajes de herramientas.
No aplicar una deformación global del modelo para corregir una mano o un pie.

## Enemigos

`scripts/animation/enemies/enemy_profile.gd` declara una familia de locomoción,
huesos por función, cadenas de tres o cuatro articulaciones y fases de apoyo
para marcha/carrera. No presupone que todos los enemigos tengan el mismo número
de patas o una anatomía humanoide. Los recursos `enemy1.tres` y `enemy3.tres`
describen sus rigs originales, respectivamente cuadrúpedo y bípedo digitígrado.

Los generadores de animación de ambos enemigos usan `RigBinding` para medir
extremidades y resolver IK. Los perfiles controlan sus fases de apoyo; los clips
bakeados existentes y sus velocidades siguen siendo los del runtime. No se
regeneran automáticamente al modificar un perfil de autoría.

## Núcleo compartido

- `rig_profile.gd`: mapa entre funciones anatómicas y nombres originales; valida
  huesos presentes, cadenas y dimensiones.
- `rig_binding.gd`: captura padres, transformaciones de referencia, longitudes y
  offsets una sola vez. `solve_metres` usa las tolerancias del solver actual para
  rigs en metros; el rig humanoide mantiene su solver en unidades de autoría.
- `skeleton_pose.gd`: convierte poses globales a locales reutilizando una inversa
  por padre. La entrada antigua de `prototype_3d/` mantiene compatibilidad.
- `animation_retargeter.gd`: adapta rotaciones de un clip usando funciones
  anatómicas y ejes de referencia, creando un `Animation` separado.

La adaptación requiere ambos rigs en su pose de referencia. Conserva duración,
loop, tiempos e interpolación; cambia nombres de pistas al esqueleto destino.
El movimiento de raíz es opcional y escala con la altura de referencia. Las
traslaciones de extremidades y las escalas no se copian para evitar estiramientos.
Tampoco se transfieren automáticamente expresiones faciales, eventos, sonido,
trayectorias de armas ni huesos sin una función equivalente.

La transferencia automática exige la misma categoría y familia. La API permite
un override explícito revisado para transferencias parciales entre familias;
no convierte por sí sola una marcha cuadrúpeda en una bípeda. Si el destino mira
hacia otro eje, proporcionar una base de alineación a `configure`. El resultado
es una base editable: revisar apoyos, silueta, límites articulares y agarres antes
de publicarlo. Los FBX, UV, skin y jerarquías originales permanecen intactos.

## Herramienta de adaptación

```sh
godot --headless --path . --script res://tools/animation/retarget_clip.gd -- \
  --source-scene res://assets/enemies/first/rig/model.scn \
  --target-scene res://assets/enemies/first/rig/model.scn \
  --source-profile res://data/animation/enemies/enemy1.tres \
  --target-profile res://data/animation/enemies/enemy1.tres \
  --animation res://assets/enemies/first/rig/motions.res \
  --clip walk --output user://adapted_walk.res
```

Para otro modelo compatible, sustituir la escena y el perfil de destino. El
archivo de entrada puede ser un `Animation` o una `AnimationLibrary` con `--clip`.
La herramienta necesita un solo esqueleto por escena y escribe un archivo nuevo;
no reemplaza las fuentes ni incorpora el resultado al catálogo del juego. Informa
las pistas omitidas para que el departamento complete lo específico del modelo.
