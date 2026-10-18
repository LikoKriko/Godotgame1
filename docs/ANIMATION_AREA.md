# Animación: funcionamiento actual

## Anatomía y continuidad

El superviviente conserva el rig original en T de 66 huesos, guiado por los
24 controles compartidos de contactos; enemigo1, sus 25 huesos originales;
enemigo3 conserva sus 35 huesos originales. Las animaciones mantienen longitudes
óseas, agarres y unión de piel y vestimenta. Los cambios de estado parten de la
pose visible y mezclan de forma continua con la siguiente acción.

La matemática compartida está en `scripts/continuous_body_pose.gd`. Los modelos,
poses, IK y controladores están en `scripts/prototype_3d/`. Los anclajes de
herramientas proceden de `assets/models/meshy/*/anchors.gd`.

## Superviviente

Puede caminar, correr, agacharse, deslizarse en ocho direcciones, saltar,
equipar/desequipar, recoger, comer, beber, bloquear, recibir daño y morir.
Las familias de objetos son manos libres, hacha, pico, espada, arco, botella,
comida y objetos transportados. La pose se adapta al desplazamiento y a la mira.

| Acción o ciclo | Duración |
| --- | --- |
| Caminar | 0,78 s |
| Correr, ciclo de referencia | 0,585 s |
| Caminar agachado | 1,625 s |
| Deslizarse | 0,46 s |
| Saltar | 0,66 s |
| Recoger | 0,72 s |
| Comer o beber | 1,2 s |
| Tensar arco | 0,5 s |
| Seguimiento de suelta del arco | 0,24 s |
| Ataque de espada | 1,0125 s |
| Ataque de hacha o pico | 0,75 s |
| Equipar/desequipar pico | 0,5 s |
| Equipar/desequipar otras familias | 0,42 s |
| Morir | 3 s |

Los tiempos proceden de `survivor_animation.gd`. Las trayectorias de marcha,
carrera, salto, deslizamiento, herramientas y caída usan las curvas compartidas
reducidas de `motion/controls.res`. Ver [ANIMATION_SYSTEMS.md](ANIMATION_SYSTEMS.md)
para tolerancias y regeneración. La muerte apoya rodillas y termina boca abajo.
El cuerpo nuevo y la cabeza aprobada comparten una transición cerrada de cuello
y los pesos del rig nativo. La orientación de mira usa
`facing_delay.gd`; la respuesta de movimiento, `movement_response.gd`.
Los golpes fijan el objetivo al iniciarse; el arco sigue la mira al tensar.
La velocidad base es 2 m/s caminando y 4,48 m/s corriendo, antes de modificadores.
Arranque de 0,16 s, aceleración durante 1 s y frenada de 0,24 s. La cadencia
visual sigue la distancia real para acompañar el sprint; el ciclo de referencia
frontal se reproduce aproximadamente en 0,418 s al alcanzar el máximo sin
modificadores. Caminando a 2 m/s, el ciclo diagonal dura unos 0,471 s y el
lateral 0,343 s. La cadencia usa la distancia efectiva de la zancada y conserva
los apoyos durante la aceleración y la frenada.

## Criaturas

- [Enemigo1](YOUNG_3D.md): locomoción cuadrúpeda, cambios de postura, sentado,
  alimentación, sueño, puñetazos alternos, boxeo, aturdimiento y muerte.
- [Enemigo3](ENEMY3_3D.md): caminata y carrera con su rig original, torso/cabeza a 60°
  al correr y velocidad diez veces mayor; patrulla de veinte metros por tramo
  con ciclo temporal de carreras de 10/20/40 s y descansos.

Enemigo1 comparte una biblioteca nativa de animaciones horneadas sobre el rig
aportado. Los apoyos siguen la piel original y la distancia física recorrida.
La IK se resuelve al hornear; el runtime reproduce y mezcla las poses locales.
La expresión facial tiene su propio reloj y acompaña los contactos.

## Trabajo entre departamentos

La rama de integración es `main`. Mantener la documentación de parámetros y
comportamientos al día con el código. Conservar los FBX, PNG, UV y rigs
originales. Una modificación de animación no debe cambiar sin motivo la
velocidad física, la percepción, las colisiones, el daño ni los tiempos.
No publicar informes de pruebas, capturas comparativas ni historiales de cambios.
