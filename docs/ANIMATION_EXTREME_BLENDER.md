# Aren: caída extrema Blender (revisión visual)

Rama: `test/animation-system-v1`. Entrega exclusivamente en
`scenes/prototype_3d/aren_authoring_review.tscn`. No sustituye recepciones
aprobadas ni conecta esta secuencia a `aren_terrain_test.tscn`.

## Autoría

`assets/characters/prototype_3d/generated/aren_extreme_blender_v1/` contiene:

- `authoring/aren_extreme.blend`: rig original de 66 huesos, piel original,
  controles del piloto, decisiones de poses completas, acción FK editable,
  copia horneada de exportación y cámaras. Carpeta excluida del importador.
- `extreme.glb` / `extreme.res`: clip esquelético independiente, 60 Hz.
- `timing.json`: claves y marcadores de las cinco fases.

Se reutilizan el rig y la referencia del piloto; no se importa una secuencia
procedural. Los planos articulares se calibran con el rig original y las
poses resueltas se guardan como claves FK completas para evitar inversiones
del IK entre poses. La copia nativa se hornea con `blender_native_export.py`,
compartido con el piloto y conservando sus opciones anteriores por defecto.
La corrección de apoyos usa el solver nativo existente de Godot.

```sh
blender -b assets/characters/prototype_3d/generated/aren_extreme_blender_v1/authoring/aren_extreme.blend -t 4 --python tools/animation/retime_aren_extreme_getup.py
godot --headless --path . --script tools/animation/import_aren_blender_landing.gd -- --extreme
godot --headless --path . --script tests/aren_extreme_review.gd
```

Para hornear ediciones manuales sin reconstruir ni sobrescribir el `.blend`:

```sh
blender -b assets/characters/prototype_3d/generated/aren_extreme_blender_v1/authoring/aren_extreme.blend -t 4 --python tools/animation/author_aren_extreme_blender.py -- --bake-only
```

Conservar el rango 1–625 y sus marcadores al editar; después repetir la
importación nativa y las pruebas anteriores.

## Secuencia y sincronización

1. Pérdida de equilibrio: circunducción nueva desde los hombros. Un círculo
   moderado, cono de 15° y desfase de 0,45 rad entre lados; los codos permanecen
   en 20° ±1,2° y las muñecas mantienen su orientación local de reposo.
   Pelvis, torso y piernas conservan su animación. No hay impulso de salto.
2. Inclinación: empieza al alcanzar el 19 % del recorrido vertical real.
   El cuerpo gira completo hacia delante y prepara una recepción horizontal.
3. Impacto: lo activa `move_and_collide` contra el suelo físico del visor.
   Compresión, rebote pequeño y amortiguación se reproducen desde ese evento.
4. Boca abajo: postura relajada mantenida. El resultado «muere» no reproduce
   incorporación y conserva bloqueado el estado de recuperación.
5. Supervivencia: incorporación de ocho segundos (antes, cuatro). La palma izquierda
   llega al apoyo a los 0,433 s y la derecha a los 0,60 s. La pierna derecha
   comienza primero; la izquierda sigue unos 0,40 s después, con recorridos
   solapados y la misma colocación final de ambos pies. La pelvis comienza
   su giro durante el empuje y conserva el máximo de 11°; el torso acompaña
   inicialmente el 46 % de ese giro, conservando la curvatura. Durante la
   descarga de los brazos elimina gradualmente la torsión relativa:
   alineación con la pelvis a los 2,80 s y ambos hacia delante a los 3,20 s.
   Los pies se cargan antes de ceder el apoyo de las manos al 40 % del progreso.
   La salida se mezcla al Idle aprobado, sin trasladar ni girar al personaje.

El visor conoce el suelo y la altura inicial (8, 10, 12 y 16 m); mide el
recorrido, en vez de usar un temporizador para declarar el 19 %. El clip
adapta su reloj aéreo al recorrido real y separa el reloj posterior al
impacto. La envolvente de piel se normaliza a la base del controlador desde
el vuelo, evitando una corrección de posición repentina al contactar.

## Correcciones acotadas sobre la fuente

La acción activa `ArenExtreme_SlowGetup_WholeBodyPoses` conserva las
385 poses completas de origen y se hornea en 625 muestras a 60 Hz. `ArenExtreme_BodyBase_fc492dc8` retiene la
fuente anterior para conservar el cuerpo y las fases posteriores.

`author_aren_extreme_shoulders.py` construye desde el reposo del rig los ocho
huesos de clavículas, húmeros, antebrazos y muñecas en 1–34. Excluye los
canales antiguos de esos huesos de las muestras de entrada de esa fase:
no reutiliza ni mezcla sus curvas. Los hombros generan la circunducción;
la flexión del codo solo varía 2,4° en total y las muñecas no giran por su cuenta.
Se conserva la proporción de manos de 0,90 y los canales de dedos existentes.

El enlace modifica únicamente los brazos en 35–45, durante los primeros
0,20 s de inclinación. Las rotaciones interpoladas igualan la velocidad
angular a ambos lados de los fotogramas 34 y 46. Desde 46 se recuperan
exactamente las poses anteriores; el resto del cuerpo, la incorporación,
la variante de muerte y los contactos permanecen iguales. El retiming posterior
aumenta el clip de 6,4 a 10,4 s, exclusivamente después del fotograma 145.
No se añaden curvas corporales ni sistemas nuevos a Godot.

`retime_aren_extreme_getup.py` escala por dos únicamente el tiempo de las
claves y sus manejadores posteriores al fotograma 145, desde la base conservada
`ArenExtreme_GetupTimingBase_d69986ad`. Mantiene los valores de las claves,
trayectorias, orden y solapamientos; no añade esperas. Los controles y marcadores
siguen el mismo tiempo. Es idempotente respecto a esa base; para conservar nuevas
ediciones manuales se debe usar `--bake-only`.

La preparación, el empuje, la colocación de piernas, la carga y el enderezamiento
reciben el mismo factor dos. La mezcla final al Idle pasa de 0,45 a 0,90 s.
Godot reproduce el clip ya ralentizado; únicamente convierte su reloj al tiempo
original para el IK de apoyos y la mezcla final existentes. El importador obtiene
el número de muestras de `timing.json`, y el horneado manual utiliza el final del
rango de Blender. Las cuatro primeras fases y el resultado de muerte conservan
sus tiempos. La duración total visible sigue dependiendo de la altura de caída.

Los generadores anteriores de hombros y coordinación reconstruyen sus versiones
anteriores y sus tiempos originales. Para conservar esta incorporación, editar
la acción activa y hornear sin reconstruir.

Después de editar manualmente la acción activa en Blender, usar el horneado
existente para conservar esas ediciones:

```sh
blender -b assets/characters/prototype_3d/generated/aren_extreme_blender_v1/authoring/aren_extreme.blend -t 4 --python tools/animation/author_aren_extreme_blender.py -- --bake-only
```

Volver a importar el clip tras hornear. Ejecutar el autor original sin
`--bake-only` reconstruye la primera versión y sobrescribe la fuente actual.
La prueba `tests/aren_extreme_review.gd` admite `-- --probe --quarter` para
repetir el escenario de 8 m a 0,25×, además de sus escenarios completos a 1×.

## Revisión y futura integración

F6 abre el catálogo y selecciona la caída extrema. Conserva las animaciones
anteriores, las cuatro cámaras y los controles 1× / 0,25×. Los cinco botones
permiten revisar fases; la barra temporal y Pausa permiten inspeccionar
contactos. El selector de resultado previsualiza supervivencia o muerte.

El selector representa un resultado de revisión, **no calcula daño ni crea
vida paralela**. La futura integración, pendiente de aprobación visual,
deberá aplicar el daño mediante el sistema vigente y consultar
`game.player_health` (usado por `scripts/prototype_3d/player.gd`) antes de
permitir la incorporación. Deberá trasladar `controls_locked` al controlador
real de acciones. No se añaden reglas de daño ni umbrales de muerte aquí.

La detección jugable con altura incierta también queda para esa integración:
se debe conservar el detector físico existente, confirmar el suelo previsto
mediante consultas fiables y mantener el perfil aprobado mientras no pueda
confirmarse una caída extrema. Este visor solo presenta escenarios de altura
conocida y no afirma resolver anticipadamente geometría desconocida.
