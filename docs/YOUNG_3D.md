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
| Esqueleto corporal | 15 huesos, incluida la cola |
| Malla fuente | 7340 triángulos |

El movimiento habitual es cuadrúpedo. Usa una huella física que incluye el
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

Mandíbula, mejillas y cavidad oral acompañan los ataques sin desplazar cuello,
ojos ni nariz. La cara se cierra gradualmente al interrumpirse la acción.

La muerte dura 2 s: apoyo de rodillas, pérdida de equilibrio y caída. Después
queda un cadáver con inventario interactivo. El nodo desaparece al alcanzar
182 s desde el inicio de la muerte. La posición, acciones, temporizadores,
memoria, daño recibido y botín se conservan en el guardado.

La suspensión por distancia del enemigo1 comienza a 150 m; se conserva su
estado para reanudarlo al acercarse. Véase [DISTANCE_OPTIMIZATION.md](DISTANCE_OPTIMIZATION.md).

## Recursos y código

El modelo original es `Meshy_AI_Mossclaw_Boar_1016001519_texture.fbx`, de la
Release `modelo-enemigo1/enemigo1_3d.zip`. El runtime carga
`assets/enemies/first/meshy/mossclaw_skin.res` y sus PNG originales.
Los datos de procedencia están en `assets/enemies/first/meshy/source.json`.

`young_enemy.gd` controla combate y movimiento; `creature_brain.gd`, las
rutinas y memoria; `young_pose.gd` y `young_model.gd`, las poses y el esqueleto;
`young_face.gd`, la expresión facial. Todos están en `scripts/prototype_3d/`.
