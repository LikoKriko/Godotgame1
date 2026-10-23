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
blender -b assets/characters/prototype_3d/generated/aren_extreme_blender_v1/authoring/aren_extreme.blend -t 4 --python tools/animation/coordinate_aren_extreme_support.py
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
5. Supervivencia: incorporación de ocho segundos, editada sobre las poses de
   `653c927f`. La palma izquierda se coloca a los 0,433 s y la derecha a los
   0,60 s. El hombro izquierdo inicia el empuje y el derecho estabiliza antes
   de colaborar. La pelvis se eleva y desplaza sobre las palmas; su inclinación
   se compensa progresivamente en la columna para abrir el pliegue de la cadera.
   La derecha avanza desde 1,10 s y su planta queda apoyada a los 3,10 s.
   La izquierda se extiende durante la colocación inicial de palmas, enlazando
   con la postura tumbada existente sin cambiarla; permanece extendida hasta
   3,25 s y coloca su planta a los 4,85 s. Se conserva así el enlace inicial
   con la flexión que ya tenía la pierna en la postura boca abajo aprobada.
   Las manos mantienen sus contactos hasta la base estable de ambos pies;
   descargan entre 5,00 y 5,60 s. La masa vuelve progresivamente hacia los pies.
   Los pasos de recolocación final ocurren con cada pie descargado, antes del
   cierre al Idle. El tramo que antes ocupaba el último segundo se reproduce
   entre 7,70 y 8,00 s: **0,30 s**, conservando ocho segundos en total.

El visor conoce el suelo y la altura inicial (8, 10, 12 y 16 m); mide el
recorrido, en vez de usar un temporizador para declarar el 19 %. El clip
adapta su reloj aéreo al recorrido real y separa el reloj posterior al
impacto. La envolvente de piel se normaliza a la base del controlador desde
el vuelo, evitando una corrección de posición repentina al contactar.

## Correcciones acotadas sobre la fuente

La acción activa `ArenExtreme_SequentialSupport_WholeBodyPoses` contiene
625 poses completas a 60 Hz. La base de esta edición se conserva como
`ArenExtreme_SupportBase_653c927f`, sin sobrescribir sus curvas. La herramienta
`coordinate_aren_extreme_support.py` edita exclusivamente la quinta fase,
remuestreando las decisiones existentes de torso, arcos de colocación de manos,
trayectorias de entrada de pies y el cierre al Idle. Sus ajustes de altura,
inclinación, distribución de masa y planos de flexión resuelven los apoyos de
cuerpo completo en Blender. No hay generación de poses corporales en Godot.

Los planos de rodilla y el giro axial se calibran con el Idle del rig original,
para que la tibia no gire rápidamente respecto al tobillo al cambiar el apoyo.
Los pies cargados conservan la orientación mundial de la planta del Idle;
los huesos de antepié y dedos no reciben correcciones nuevas. Las palmas se
colocan 0,15 m más delante para permitir el desplazamiento de masa con alcance
real de los brazos. Los controles antiguos del piloto quedan como referencias;
la fuente editable actual es la acción FK completa.

`author_aren_extreme_shoulders.py` construye desde el reposo del rig los ocho
huesos de clavículas, húmeros, antebrazos y muñecas en 1–34. Excluye los
canales antiguos de esos huesos de las muestras de entrada de esa fase:
no reutiliza ni mezcla sus curvas. Los hombros generan la circunducción;
la flexión del codo solo varía 2,4° en total y las muñecas no giran por su cuenta.
Se conserva la proporción de manos de 0,90 y los canales de dedos existentes.

El enlace de hombros ocupa 35–45, durante los primeros 0,20 s de inclinación.
Sus rotaciones igualan la velocidad angular a ambos lados de los fotogramas
34 y 46. Esta edición conserva ese enlace, el resto de las cuatro primeras
fases y la variante de muerte. La incorporación cambia únicamente después
del fotograma 145 y conserva el final del clip en 10,4 s.

`retime_aren_extreme_getup.py` conserva la ampliación anterior de cuatro a ocho
segundos desde `ArenExtreme_GetupTimingBase_d69986ad`; reconstruye aquella versión
anterior, no esta coordinación. La herramienta actual usa su propia base guardada
para evitar acumular cambios en ejecuciones sucesivas. Los generadores anteriores
de hombros y coordinación reconstruyen también sus versiones históricas.

Godot reproduce el clip horneado y utiliza `getup_contacts` de `timing.json`
para fijar palmas y plantas únicamente durante sus apoyos. Conserva el solver
existente de longitudes nativas y envolventes de piel. La mezcla final al Idle
ocupa los mismos 0,30 s del cierre Blender. El importador obtiene el número de
muestras de `timing.json`; el horneado manual respeta el final del rango Blender.
Las cuatro primeras fases y el resultado de muerte conservan sus tiempos.

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
