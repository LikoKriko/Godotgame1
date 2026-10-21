# Aren: estado actual del sistema de animaciones

**Fase 1: locomoción (paso 5) y salto voluntario (paso 6) aprobados visualmente.**
Salto aprobado por el usuario en `343af25` (`Refine Aren jump timing and add continuous review transitions`).
Paso 7: caída automática en revisión de autoría, pendiente de aprobación visual.
Rama exclusiva: `test/animation-system-v1`. Commit de cierre funcional de locomoción: `651b81a97a0dfe652d3f6af09b38bd2c90e330a9`
(`Cache rig branches for identical Aren pose transforms`). El cierre posterior
es únicamente documental. No integrar en `main` sin autorización expresa.

## Arquitectura y herramientas

Sistema provisional de Godot 4, aislado del juego principal. Conservar las
animaciones, perfiles, rig, binds, materiales e identificadores aprobados.
Leer los `AGENTS.md` aplicables antes de editar; reutilizar los sistemas existentes.

- Modelo: `assets/characters/prototype_3d/composite/model.scn`.
  Rig nativo de 66 huesos: `data/animation/characters/survivor_native.tres`.
  Enlace: `scripts/animation/characters/native_survivor.gd`;
  utilidades compartidas: `scripts/animation/shared/`.
- Variante aprobada: `assets/characters/prototype_3d/generated/aren_run_balanced_v1/`
  (`aren.tscn`, `profile.json`). Herramientas de autoría en `tools/animation/`
  y `scripts/animation/authoring/`; evaluación mediante
  `aren_run_balanced_actor.gd`, `aren_run_balanced_sampler.gd` y
  `aren_transition_actor.gd` de este último directorio.
- En `scripts/animation/terrain/`, `aren_motion_driver.gd` comparte movimiento
  entre visor y escena jugable, reutilizando
  `scripts/prototype_3d/movement_response.gd`; `aren_turn_response.gd` adapta
  los giros. `aren_terrain_test.gd` gestiona física, cámara, entradas y HUD.
- `aren_terrain_actor.gd` resuelve pelvis, contactos e IK de longitudes fijas;
  `terrain_foot_support.gd` valida las suelas; `terrain_cycle_sampler.gd`
  reutiliza muestras; `terrain_test_patch.gd` construye los terrenos;
  `terrain_step.gd` valida escalones de hasta 26 cm. Cápsula de 1,65 m,
  radio de 22 cm y pendiente máxima de 42°.
- Evaluación: movimiento y colisiones → desplazamiento real → fase y pose
  aprobada → referencia corporal y pelvis → IK y suelas. Las correcciones
  parten de la pose fuente, sin acumularse entre fotogramas.

## Animaciones, estados y transiciones

- Reposo, caminata y carrera en `normal`, `cautious` y `tired`
  (normal, cauteloso y cansado), conservando sus diferencias de estilo y ritmo.
- Seis transiciones entre reposo, caminata y carrera, encadenables e
  interrumpibles. Se seleccionan por intención de movimiento; los cambios
  rápidos no dependen de alcanzar una velocidad nominal exacta.
- Aceleración, frenada, locomoción relativa a cámara y fase sincronizada con
  el desplazamiento físico real. El cambio de estado mezcla durante 0,3 s
  conservando la fase.
- Giros ágiles por el arco más corto, con diferencias angulares en [-π, π],
  sin vueltas acumuladas. Límites de 300°/s caminando y 360°/s corriendo,
  ajustados por estado. Los giros moderados conservan movimiento; las
  inversiones coordinan frenada breve, apoyo y recuperación sin pausa impuesta.
- Inclinación proporcional al giro y la velocidad, limitada a 2,5° caminando
  y 4° corriendo, distribuida entre pelvis y columna. Girar solo la cámara
  mantiene el comportamiento aprobado.
- Pies apoyados anclados en mundo; durante la transferencia siguen la dirección
  real, hasta 35° respecto al cuerpo. IK con límites anatómicos, superficies
  transitables y compensación de pelvis, conservando la oscilación natural.

## Escenas y validación

- Jugable provisional: `scenes/prototype_3d/aren_terrain_test.tscn` (**F6**).
  Actor: `scenes/prototype_3d/aren_terrain_actor.tscn`.
  Incluye plano, rampas, baches, escalones de 5–25 cm, camino irregular y bosque.
  WASD mueve; Mayús corre; botón derecho y ratón controlan cámara;
  1/2/3 seleccionan estado; R reinicia; 4/5 llevan a camino/bosque.
  HUD con velocidad, error de apoyo, FPS y coste CPU de evaluación.
- Visor: `scenes/prototype_3d/aren_authoring_review.tscn`, opción
  **Carrera: pies coordinados**; cuatro vistas, comparación antes/después,
  estados, ciclos, transiciones, pausa y velocidad.
- Giros: `scenes/prototype_3d/aren_turn_review.tscn` o botón
  **Paso 3: comparar giros** del visor. Comparación de 45°/90°/135°/180°,
  cambios consecutivos, cámara fija/móvil y suelo irregular.
- Regresiones principales en `tests/`: `aren_locomotion_integration.gd`,
  `aren_turn_response.gd`, `aren_turn_review.gd`, `aren_stair_support.gd`,
  `aren_terrain_sampling.gd`, `aren_branch_cache.gd` y `aren_review_playback.gd`.
  Cubren transiciones e interrupciones, tres estados, cinco terrenos,
  escalones en distintas direcciones, apoyos, giros y equivalencia de poses.
  Ejemplo: `godot --headless --path . --fixed-fps 60 --script tests/aren_locomotion_integration.gd`.

## Correcciones y rendimiento integrados

- Apoyos estables en bordes y escalones, límites articulares y continuidad
  corporal. Las consultas de piel mezclan pesos en espacio del modelo y aplican
  una sola vez la transformación del personaje, manteniendo su coincidencia
  con la malla durante giros y desniveles.
- Consultas de suela con datos compactos precalculados, descarte conservador,
  consultas de planos, cajas e índices de triángulos estáticos; barrido detallado
  cuando la geometría lo requiere. Reutilización de muestras idénticas por
  evaluación, sin cuantizar el tiempo ni reducir la cadencia de contactos.
- `RigBinding` precalcula las ramas del esqueleto y las rotaciones reutilizan
  sus índices, conservando el orden y los resultados de las operaciones.
  Se mantienen animaciones, IK, sondeos necesarios y calidad de apoyos.
- Rendimiento comprobado por el usuario en i5-10400F, RTX 3060 y 16 GB RAM,
  ejecutando con F6 y monitor de 240 Hz: **160–180 FPS en suelo plano y
  140–160 FPS en terreno irregular**. Las mediciones con renderizado por
  software del entorno automatizado no son comparables a esta GPU.
- La escena provisional no aplica el límite de FPS del juego principal.
  F5 ejecuta otra escena; para comparar con ejecución independiente, mantener
  escena y resolución y comprobar V-Sync/límites del editor y del controlador.
  Ejemplo sin límite: `godot --path . --disable-vsync --max-fps 0 scenes/prototype_3d/aren_terrain_test.tscn`.

## Limitaciones pendientes y siguiente objetivo

- Alcance actual: locomoción terrestre sobre colisiones estáticas; plataformas
  móviles y locomoción aérea aún no implementadas en este sistema provisional.
  No existe generación universal de movimientos desde texto.
- Desfase histórico de hashes: `tests/aren_torso_coordination.gd` conserva
  cuatro discrepancias de procedencia de herramientas en los metadatos de
  `aren_walk_torso_v2`; no corresponden a fallos de poses o contactos.
  Conservar los hashes históricos y los clips aprobados; no regenerarlos para
  silenciar esa comprobación. Las demás regresiones del cierre pasan.
- **Objetivo actual: Fase 1, paso 7, caída automática de Aren**, presentada
  primero en el visor. Validar en la escena jugable con desniveles reales tras
  la aprobación visual. Los aterrizajes definitivos corresponden al paso 8.

### Paso 6: salto voluntario aprobado

El visor conserva **Paso 6: salto voluntario (aprobado)**, versión `343af25`.
`idle`/`walk`/`run` muestran un salto completo desde esa locomoción, con entrada
terrestre y recuperación provisional. Conserva los tres estados. El segundo
selector incluye **Reposo → Salto**, **Caminata → Salto**, **Carrera → Salto**,
**Salto → Reposo**, **Salto → Caminata**, **Salto → Carrera** y
**Saltos encadenados**. Las entradas terminan en el ápice; las salidas aisladas
parten de esa misma fase y terminan en su locomoción de destino. La cadena
alterna reposo → salto → caminata → salto → carrera → salto → reposo,
conservando pose, desplazamiento y contactos entre segmentos, sin cortes.

Los botones inferiores aíslan preparación, impulso, ascenso, fase aérea,
descenso y recuperación provisional. El deslizador, pausa, velocidad y
**Reiniciar** permiten inspección individual. Cambiar a una salida durante el
vuelo conserva el salto actual; los otros cambios se encolan hasta recuperar
el suelo. **Reiniciar** inicia explícitamente la opción elegida. Las opciones
individuales se detienen al terminar, sin reinicios automáticos.

`aren_jump_actor.gd` extiende el actor aprobado y conserva sus bibliotecas.
Reutiliza el rig nativo, las transformaciones de ramas, el solver de longitudes
fijas y los correctivos de rodilla. La entrada y recuperación reutilizan el
reloj y los contactos del actor terrestre, incluidos sus cambios de velocidad.
Durante la preparación la pelvis desciende hasta 6,5 cm y la inclinación de
11° se reparte entre pelvis (30 %) y columna (16/24/30 %), con flexión local
progresiva. El impulso conserva 4° hacia delante; la espalda se endereza de
forma continua durante el ascenso, hasta la postura neutral cerca del ápice.

`aren_jump_motion.gd` define preparación de 0,50 s, impulso de 0,105 s,
velocidad inicial de 3,8 m/s y gravedad de 9,8 m/s². El vuelo balístico dura
aproximadamente 0,78 s y conserva la velocidad horizontal de salida. La
recuperación provisional mezcla durante 0,34 s; devuelve antes los objetivos
de pie y pelvis para alcanzar el siguiente apoyo sin prolongar su anclaje.
El descenso prepara un apoyo adelantado al moverse y conserva flexión de
rodilla para el contacto. El apoyo consume el solver terrestre existente y una compresión pequeña de
carga; no constituye el catálogo de aterrizajes del paso 8. La pose aérea
consume velocidad vertical y tiempo de vuelo, sin ejecutar apoyos ni sondeos
terrestres. La previsualización todavía no usa colisiones del personaje.

**Salto aprobado visualmente.** Sus poses y bibliotecas se conservan.
`aren_terrain_test.tscn` conecta ahora el salto completo al cuerpo físico mediante
`aren_air_motion.gd`, utilizando los mismos tiempos, impulso y gravedad del visor.


### Paso 7: caída automática y contacto provisional

`aren_authoring_review.tscn` abre **Paso 7: caída automática (revisión)**. El
segundo selector ofrece **Reposo → Caída**, **Caminata → Caída**, **Carrera →
Caída**, **Caída corta**, **Caída prolongada** y **Caídas encadenadas**. Conserva
los tres estados y las cuatro vistas, pausa, velocidad, reinicio y deslizador.
Los botones aíslan pérdida de apoyo, reacción, caída, preparación de contacto y
recuperación provisional. Las opciones individuales se detienen al finalizar;
la cadena alterna los tres orígenes en niveles sucesivamente inferiores, sin
reiniciar la posición del personaje. Las actualizaciones del rango temporal no
deben emitir la señal de búsqueda manual ni pausar la cadena.

El selector de altura permite 0,55/1,5/3/8 m en las entradas y cadenas. Las
opciones corta y prolongada fijan 0,55 y 8 m. El soporte superior es una referencia
visual; en reposo se retira al iniciar la caída. Una guía vertical acompaña la
inspección de altura. No son colisiones ni un nivel jugable nuevo.

`aren_fall_actor.gd` extiende el actor de salto sin modificar sus poses. Reutiliza sus
objetivos aéreos de descenso, el rig, el solver de longitudes fijas, los
correctivos, la copia de poses entre vistas y la recuperación provisional.
Congela la última pose de locomoción al perder apoyo, libera sus anclajes y
mezcla progresivamente una reacción de equilibrio: inclinación contenida,
brazos más abiertos y asimétricos, y piernas recogidas. La respuesta aumenta con
la velocidad vertical real; la proximidad del suelo adapta los objetivos de pie.
No contiene preparación ni impulso ascendente ni un ciclo de gestos repetidos.
La muestra neutral se conserva por estado y no se realizan sondeos de terreno
durante la pose aérea. La gravedad del visor es 9,8 m/s², compartida con el salto.

`terrain/aren_fall_response.gd` es el detector reutilizable conectado
al controlador de la escena de pruebas. Se alimenta **después de mover el cuerpo** con contacto físico,
velocidad vertical, distancia al suelo y apoyo de escalón validado. No acepta
contactos del IK como prueba de suelo. Confirma la caída tras 0,10 s sin apoyo,
8 cm de descenso y un desnivel superior a 28 cm (margen sobre los escalones
aprobados de 26 cm). La pérdida de apoyo libera el peso terrestre durante 0,12 s;
la recuperación lo devuelve progresivamente. Un evento de impulso voluntario
mantiene la clasificación de salto hasta recuperar contacto físico, incluso si
se alcanza después una velocidad descendente. El evento representa un salto
realmente ejecutado, no la mera pulsación de la entrada.

El visor conserva sus opciones y la recuperación provisional. La absorción de
contacto y su recuperación aumentan respecto a los parámetros anteriores:

| Altura | Multiplicador de absorción y recuperación | Carga de referencia | Recuperación |
| --- | --- | --- | --- |
| 0,55 m | 1,10 | 0,0308 m | 0,374 s |
| 1,50 m | 1,20 | 0,0336 m | 0,408 s |
| 3,00 m | 1,30 | 0,0364 m | 0,442 s |

La referencia de carga era 0,028 m y la mezcla de recuperación 0,34 s.
La retención inicial de carga pasa de 0,22 s a 0,242/0,264/0,286 s.
`aren_fall_motion.gd` comparte estos factores con el controlador e interpola
las alturas intermedias; por encima de 3 m limita el factor a 1,30.
**8 m: caída al suelo pendiente.** Conserva únicamente la recuperación
provisional, identificada explícitamente en el visor y al tocar suelo en la
escena jugable. No se ha creado una pose de desplome ni el aterrizaje definitivo
del paso 8.

### Conexión aérea de la escena jugable de pruebas

Abrir `scenes/prototype_3d/aren_terrain_test.tscn` y ejecutar con F6.
**Espacio** inicia el salto desde reposo, caminata o carrera; WASD y Mayús
conservan los controles terrestres. Sin entrada aérea se conserva la velocidad
horizontal; con entrada se permite una aceleración máxima de 2,5 m/s².
**1/2/3** seleccionan normal/cauteloso/cansado; una selección en vuelo se aplica
al recuperar suelo. **4/5** sitúan al actor
en el camino irregular y el terreno forestal. **6/7/8/9** lo sitúan en plataformas
reales de 0,55/1,50/3/8 m; avanzar con W para abandonar el borde o con Mayús+W
para hacerlo corriendo. R vuelve al inicio y botón derecho+ratón controla la cámara.

El controlador existente opta por `aren_air_motion.gd` mediante `aerial_enabled`;
el visor comparativo de giros conserva su ruta terrestre. Se aplica primero la
respuesta física y el movimiento con colisiones; después se clasifica el
contacto y se evalúa la pose. El salto recibe un único evento de impulso real.
Las pérdidas breves con suelo a menos de 28 cm conservan el evaluador terrestre
y su filtro de altura, sin activar la animación de caída. Los escalones siguen
usando `terrain_step.gd` y el contacto físico de su aterrizaje validado.

El actor de terreno hereda las poses aprobadas de salto/caída. Durante el vuelo
omite los sondeos de pies, la compensación terrestre de pelvis y sus anclajes;
conserva el solver anatómico de longitudes fijas. La caída libera los apoyos
previos en coordenadas mundiales durante 0,12 s. La postura recibe velocidad
vertical real y distancia física al suelo; la gravedad aérea es 9,8 m/s².
Al contactar, el IK de terreno recupera los apoyos reales mediante una mezcla
de pose y objetivos de pie, más una carga amortiguada proporcional a la altura.
La diferencia entre velocidad horizontal real e intención de locomoción se
libera durante 0,16 s para evitar una frenada instantánea al soltar el control
en vuelo. La altura del impacto procede del apoyo físico y del contacto final,
conservando la referencia del borde durante los contactos redondeados de la cápsula.
