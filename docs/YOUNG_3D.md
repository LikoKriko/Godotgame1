# Enemigo1: Mossclaw Boar

## Dimensiones y movimiento

| Parámetro | Valor actual |
| --- | --- |
| Altura | 0,875 m |
| Vida | 10 |
| Velocidad de deambulación | 0,85 m/s |
| Velocidad de persecución | 1,7 m/s |
| Detección diurna | 7,5 m |
| Detección nocturna y al despertar | 20 m |
| Alcance nominal | 0,65 m; el contacto considera también el radio corporal |
| Esqueleto corporal | 25 huesos originales SmartRigArmature |
| Malla fuente conservada | 7340 triángulos |
| Superficie corporal en runtime | 4036 triángulos, 5901 vértices con costuras UV |
| Superficie con apertura facial | 4148 triángulos, más el interior de boca |
| Relieve de superficie | Mapa de normales tangentes de 2048 × 2048 |

El movimiento habitual es cuadrúpedo. La marcha dura 0,64 s por ciclo, la
persecución 0,48 s y la marcha de boxeo 0,36 s. La cadencia se ajusta a la
velocidad física realmente recorrida; al bloquearse el desplazamiento, se
frena también el ciclo. Los apoyos se calibran sobre las superficies de piel
de patas y puños, con transferencia de peso, elevación durante el avance y
zancada correspondiente a 0,85 o 1,7 m/s. La marcha usa cuatro apoyos sucesivos;
la carrera alterna los dos lados. Usa una huella física que incluye el
hocico y separación entre criaturas; sus zonas de daño siguen cabeza, hocico
y puños. La percepción comprueba obstáculos.

## Rutina y memoria

Deambula, se sienta y busca árboles vivos, favoreciendo los grupos densos.
Se coloca a distancia del tronco según las colisiones de ambos. La alimentación
dura entre 2 y 10 s, con una pausa de 8–16 s antes de otra comida. La destrucción
del árbol interrumpe la acción. El descanso sentado dura 4–8 s.

Al detectar al jugador lo persigue; si lo pierde, conserva la última posición
vista y la investiga durante 2 s. La alerta y la memoria prevalecen sobre
actividades tranquilas. Los cambios de postura habituales duran 0,28 s.

Duerme de **23:00 a 06:00** si está tranquilo. Se acuesta, respira durante el
sueño y se incorpora al detectar al jugador o recibir daño. El sueño no
interrumpe una búsqueda activa.

## Ataques y boxeo

| Ataque | Duración | Contacto | Daño base |
| --- | --- | --- | --- |
| Puñetazo normal | 1 s | 0,5 s | 2 |
| Crochet | 1,2 s | 0,6 s | 4 |

Alterna los brazos y solo aplica daño una vez por golpe. El primer daño no
letal habilita una tirada de boxeo del 50 % y nuevas tiradas cada 10 s de juego.
Un éxito activa la guardia erguida durante 20 s; recibir más golpes no reinicia
el reloj ni prolonga una guardia activa. Durante la guardia persigue y usa
crochets. Sus puños quedan a los lados de la cabeza, con codos de 110°.

El descanso suspende el sorteo de boxeo. Un golpe que despierta al enemigo
permite resolver el sorteo pendiente después de incorporarse. El aturdimiento
interrumpe el ataque; al terminar vuelve a la guardia si aún queda tiempo.
Pausar congela los relojes de juego.

## Cara, muerte y botín

Mandíbula, mejillas y cavidad oral acompañan los ataques sin desplazar cuello
ni ojos. El hocico recibe una elevación leve. La cara se cierra gradualmente
al interrumpirse la acción.

La muerte dura 2 s: apoyo de rodillas, pérdida de equilibrio y caída. Después
queda un cadáver con inventario interactivo. El nodo desaparece al alcanzar
182 s desde el inicio de la muerte. La posición, acciones, temporizadores,
memoria, daño recibido y botín se conservan en el guardado.

La suspensión por distancia del enemigo1 comienza a 150 m; se conserva su
estado para reanudarlo al acercarse. Véase [DISTANCE_OPTIMIZATION.md](DISTANCE_OPTIMIZATION.md).

## Recursos y código

El modelo vigente es `Meshy_AI_Character_output.glb` de la Release
[modelo1_rig](https://github.com/LikoKriko/Godotgame1/releases/tag/modelo1_rig).
Su fuente se conserva en `entregables/enemigos/enemigo1/source/` con `.gdignore`.
El runtime carga `assets/enemies/first/rig/model.scn`, `face.res` y `motions.res`.
Los PNG originales se comparten desde `assets/enemies/first/meshy/`; la
procedencia y hashes están en `assets/enemies/first/rig/source.json`.

La fuente original se conserva intacta. La superficie de runtime se reduce
protegiendo cabeza, plantas de las patas y límites del modelo; mantiene las UV
y transfiere los pesos de piel existentes. El relieve del original, incluido
su mapa normal, se proyecta sobre `rig/surface_normal.png`. Albedo, rugosidad
y metal siguen usando los PNG originales. Se conservan el rig de 25 huesos,
su jerarquía, ejes de reposo y matrices de ligadura. La malla
facial derivada añade la abertura y el interior de boca, con cinco controles
y un gesto de 2 s. Todas las acciones corporales se hornean sobre ese mismo
esqueleto: referencia, reposo, marcha, carrera, incorporaciones, ataques
alternos, guardia y marcha de boxeo, crochets, sentado, alimentación, sueño,
despertar, aturdimiento, muerte y cadáver. Las transiciones mezclan poses
locales para mantener las longitudes óseas. La resolución de apoyos y el
ajuste al suelo se hacen al preparar los recursos, sin IK por enemigo en runtime.

Para regenerar la superficie optimizada desde la raíz del proyecto con
Blender 4.3 o posterior y Godot 4.7, sin modificar las animaciones existentes:

```sh
blender -b -t 6 --python tools/enemy1/optimize_surface.py -- /tmp/enemy1-surface
cp /tmp/enemy1-surface/normal.png assets/enemies/first/rig/surface_normal.png
godot --headless --editor --path . --import
godot --headless --path . --script tools/enemy1/bake_surface.gd -- /tmp/enemy1-surface
```

`import_rig.gd` prepara la escena completa de la fuente original;
`bake_motion.gd` prepara los clips corporales cuando cambia su autoría.
La reducción de superficie no requiere regenerar esos clips.

`young_enemy.gd` controla combate y movimiento; `creature_brain.gd`, las
rutinas y memoria; `young_rig_motion.gd`, la autoría de poses y apoyos;
`young_model.gd`, la reproducción nativa y sus transiciones; `young_face.gd`,
la expresión facial. Todos están en `scripts/prototype_3d/`.
