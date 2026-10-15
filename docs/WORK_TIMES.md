# Registro de tiempos de trabajo

Los tiempos se usan para comparar tareas parecidas y mejorar las estimaciones.
Anotar las pruebas y los cambios de alcance junto a cada intervalo. No contar
una estimación como duración real. Las fechas de este documento usan UTC;
los informes al usuario se expresan en Europe/Madrid.

## 2026-10-15 — Correcciones del prototipo 3D

Alcance: cuerpo y pelo del superviviente, menor flexión al golpear, armas
facetadas, arco alineado con mira y alcance 100 m, árboles, armadura de hojas.
Se añadió adaptar el joven usando sus cuatro vistas originales.

Estimación comunicada durante el trabajo: **45–75 minutos restantes**, ya con
el enemigo incluido. El usuario ha facilitado la hora de inicio: **08:10 Europe/Madrid**
(06:10 UTC). A las 08:26 llevábamos 16 minutos. El intervalo completo usa esa
hora aportada por el usuario; los hitos posteriores llevan marca del entorno.

| Hito | UTC | Estado |
| --- | --- | --- |
| Inicio de la tanda, hora confirmada por el usuario | 2026-10-15 06:10:00 | Confirmado |
| Inicio del registro del entorno; comprobación y ajustes visuales | 2026-10-15 06:25:12 | En curso |

A este primer hito ya estaban hechas la primera pasada de geometría, la
adaptación inicial de la armadura y la proyección de las cuatro vistas del
joven; 69 comprobaciones del arco habían pasado. Ese trabajo previo pertenece al intervalo desde las 08:10 confirmado
por el usuario; no hay desglose exacto de cada subparte previa.

| Hito adicional | UTC | Estado |
| --- | --- | --- |
| Referencias nuevas del pico y joven integradas desde GitHub; revisión de brazos y armadura | 2026-10-15 06:45:02 | Pruebas de brazos, agarres, arco y catálogo pasadas |
| Revisión visual del joven y refinamiento de ojos, colmillos y cresta | 2026-10-15 06:48:39 | En curso |

Cambios de alcance: el usuario añadió codos de 75° en los brazos libres al correr
y una referencia nueva del pico. GitHub incorporó también una versión nueva de
las cuatro vistas del joven durante esta tanda. Las 35 min 2 s hasta el hito de
06:45 son tiempo transcurrido desde el inicio confirmado; no atribuirlos como
35 minutos exclusivos de modelado ni sumarlos a intervalos superpuestos.

| Cierre de implementación y revisión | UTC | Duración desde el inicio confirmado |
| --- | --- | --- |
| Modelos, carrera, arco, nuevas referencias y documentación listos | 2026-10-15 06:50:54 | 40 min 54 s |

La tanda se cerró antes del intervalo estimado de 45–75 minutos **restantes**.
Esa estimación resultó conservadora; para próximas previsiones separar refinado
geométrico con rig existente de modelado y animación desde cero. No extrapolar
esta duración a terminar toda la migración ni al sistema del PDF.

Validación: 8588 comprobaciones del catálogo, 326 de carrera/agarres, 69 de arco,
24 de cuerpo/armadura, 65 de equipo y 6532 de criatura; prueba de movimiento y
27 comprobaciones de población. Revisión renderizada con Compatibility del
superviviente equipado/corriendo, el pico nuevo, joven y árboles. La prueba de
población pasó pero emitió al cerrar un aviso de una instancia RefCounted sin
liberar, con cargas de interiores en segundo plano; queda anotado para el
barrido de ciclo de vida/streaming, sin atribuirlo a un fallo visual.

## 2026-10-15 — Guardado y partidas 3D, con correcciones de anatomía

Alcance solicitado: una sola partida manual; menú principal, nueva partida,
pausa y Continuar; persistir personaje y mundo. Durante el trabajo se añadieron
reposo a 165°, unión continua de hombros, más planos en espalda y cabeza/torso
del joven. No se dio una estimación previa para esta tanda.

| Hito | UTC | Estado |
| --- | --- | --- |
| Primer registro del entorno tras la petición | 2026-10-15 06:56:17 | Revisión de arquitectura y comienzo de la implementación |
| Prueba entre procesos y revisión nativa en marcha | 2026-10-15 07:13:16 | Guardado/carga integrados |
| Pruebas funcionales y nativas pasadas | 2026-10-15 07:21:36 | 186 comprobaciones de sesión, 739 generales, 8588 de animación y 11 nativas |
| Cierre ampliado de validación y documentación | 2026-10-15 07:25:33 | 190 comprobaciones de sesión, incluido rechazo por semilla y rutas user:// |

Intervalo medido entre primer registro y cierre: **29 min 16 s**. La petición
llegó antes del primer registro; no se dispone de su segundo exacto. No hay
un desglose exclusivo por subsistema: guardado, interfaz, anatomía y pruebas
se hicieron intercalados. No sumar estos hitos como si fueran tareas separadas.

Validación adicional: escritura y lectura en dos procesos independientes de
Godot; 374 comprobaciones de codos/agarres, 24 de cuerpo/armadura, 65 de equipo,
6532 de criatura y prueba de streaming. Compatibilidad gráfica comprobada en
ventana nativa, sin cambiar resolución ni escala del viewport. El cambio de
ciclo de vida drena las peticiones de interiores al liberar una partida; las
pruebas de sesión no reprodujeron el aviso anterior de RefCounted al cerrar.

Al preparar la subida apareció en la rama remota
`entregables/herramientas/pico1_4vistas_3d.png`; se incorporó el commit del usuario
sin modificarlo y se ajustaron volumen y silueta de la cabeza del pico a esas
vistas. Revisión nativa adicional y pruebas de equipo/armadura pasadas.
Último hito antes de publicar: **2026-10-15 07:28:46 UTC**. Intervalo medido desde
el primer registro: **32 min 29 s**, incluida esta ampliación de referencia.


## 2026-10-15 — Zancada, cámara, referencias nuevas y HUD 3D

Alcance inicial: zancadas 30% más largas, misma velocidad, cadencia menor y
brazos con 10% menos de amplitud y ritmo más lento; cámara vertical sin parpadeo.
Durante la tanda se pidieron rehacer el superviviente desde dos imágenes nuevas,
rehacer el joven conforme a sus cuatro vistas y sustituir la escala del HUD
por cinco niveles, con el antiguo nivel 3 como nuevo nivel 1.
No se dio una estimación previa para este alcance ampliado.

| Hito | UTC | Estado |
| --- | --- | --- |
| Primer registro de la tanda de movimiento/cámara | 2026-10-15 07:42:04 | Inicio medido parcial; la petición exacta fue anterior |
| Primera validación ampliada | 2026-10-15 08:06:47 | Rig, ritmo, criatura, HUD, guardado y movimiento probados |
| Cierre de revisión nativa y documentación | 2026-10-15 08:18:21 | Modelos revisados de frente/lado/espalda y en movimiento; prueba nativa de sesión pasada |

Intervalo medido hasta este hito: **36 min 17 s**. Es un intervalo combinado;
no se dispone del inicio exclusivo de modelado del superviviente, enemigo o
cambio de HUD. No atribuir esta duración entera a ninguno de ellos.

Se reprodujo el parpadeo de cámara: alternaba una posición por encima del suelo
con otra por debajo al recuperar hacia la distancia completa mientras seguía
obstruida. La corrección converge a la distancia segura, admite ±90° y valida
ese ángulo tras guardar/leer JSON. La zancada conserva huesos y apoyos; los
brazos comparten el ciclo más largo, además de reducir su amplitud.

Los nuevos modelos conservan rigs continuos de 20 y 14 huesos; se reconstruyen
formas, manos/cara/pelo/ropa del humano y pelaje/cresta/hocico/ojos/piedra del
joven. Las vistas del usuario son referencias de reconstrucción, no archivos
con una malla extraíble. Se verificaron poses estáticas y fases de caminar,
correr, agacharse, hacha, pico, espada, arco, comida, parry, deslizamiento,
salto, muerte, stun, sentado y alimentación del joven. Dos revisiones gráficas
detectaron defectos de unión/relieve y contaminación de texturas que se
corrigieron antes de la publicación.

Validación: 8588 comprobaciones del catálogo, 6531 de criatura/HUD, 1116 de
zancada/cámara, 539 de referencias/piel/HUD, 374 de codos/agarres, 24 de
cuerpo/armadura, 739 generales, 69 de arco, 191 de guardado/sesión y prueba de
movimiento. En ventana nativa: 11 comprobaciones de menús, desplegables,
configuración, guardado/carga y clics. La importación del editor terminó sin
errores de scripts. El controlador llvmpipe avisa que no puede cambiar VSync;
ese aviso pertenece a la revisión gráfica del entorno, no al proyecto.


## 2026-10-15 — Objetos tirados con volumen 3D

Primera observación de esta continuación: **11:19:40 UTC** (13:19:40 Madrid).
El usuario pidió continuar la migración. Se abordó la representación física
pendiente de objetos con diseño existente, sin inventar los que no tienen
referencia. Durante la tanda añadió rehacer después el deslizamiento a partir
de referencias reales. Sin estimación previa para esta tanda.

Hito de cierre de implementación y pruebas: **11:35:06 UTC**, intervalo medido
**15 min 26 s**. Incluye modelos de 21 ids (agua antigua comparte la botella
actual), caché de geometría/materiales, apoyo, recogida y revisión gráfica de
14 objetos. No incluye la animación del deslizamiento, aún no realizada.

Validación: 162 comprobaciones de modelos físicos, estados, caché y recogida;
15 de botín; 17 de mesa; 191 de guardado y sesión. Importación del editor sin
errores. Revisión nativa: materiales, contornos, sombras, profundidad, botella,
armadura, herramientas y sal con etiqueta sobre superficie curva. Se ajustó el
apoyo mediante vértices reales y la boca/etiqueta de la bolsa al observarlos.

Para la tarea siguiente, el acceso web a referencias reales quedó bloqueado
por el proxy (403). El permiso general de red se concedió, pero no modifica
la lista del proxy; se guardó una ampliación de cuatro dominios en el borrador,
que requiere publicación del entorno. No se sustituyen referencias verificadas
por una afirmación de haber visto un movimiento real.

Medición adicional de construcción en Godot headless: primera creación de los
21 ids en **302,754 ms** (20 claves de malla por la botella heredada compartida);
1000 creaciones/liberaciones posteriores en **12,118 ms**, sin aumentar la
caché. Son costes de construcción de nodos/recursos en este entorno, no una
medición de FPS ni de coste de renderizado en el equipo del usuario.


## 2026-10-15 — Primera animación de deslizamiento sobre una cadera

La postura fue elegida por el usuario: una pierna adelantada y la otra
flexionada. Primer registro de esta tarea: **11:41:46 UTC** (13:41:46 Madrid).
Hito intermedio de pruebas y revisión: **11:52:47 UTC**, intervalo observado
**11 min 1 s**. Sin estimación previa. La petición exacta fue anterior al primer
registro; no incluir los objetos físicos en esta duración.

Se implementaron entrada desde carrera, cadera baja con inclinación y giro
leves, rodilla plegada lateral, talón adelantado, brazos de equilibrio y
recuperación. Los agarres permanecen unidos al objeto. El salto encadenado toma
la última postura real y la abre gradualmente, conservando su plano de herramienta.
La orientación del modelo acompaña el deslizamiento y el giro aéreo permitidos.
No se cambiaron duración, distancia, frenada ni reglas de `locomotion.gd`.

Validación: 2027 comprobaciones de deslizamiento/IK/agarres/continuidad, 8588 del
catálogo, prueba de movimiento en partida y 191 de guardado. Revisión nativa
frontal y lateral en cuatro fases, manos libres y cinco familias de objetos,
con armadura. Se elevó la postura de las manos libres tras observar la primera
pasada. Importación sin errores de scripts.

**Alcance pendiente:** consulta de una grabación real. El proxy mantiene los
dominios externos bloqueados; la ampliación de red aún requiere publicar el
borrador. La secuencia se basa en la postura elegida e IK anatómico, y no se
presenta como mocap ni como referencia externa ya contrastada. Esos minutos
miden la primera implementación y pruebas, no la investigación aún bloqueada.

Último registro antes de publicar la primera secuencia: **11:54:29 UTC**,
intervalo observado desde el inicio **12 min 43 s**.

## 2026-10-15 — Anatomía, malla y catálogo de animaciones del superviviente 3D

Primer registro **12:31:45 UTC** (14:31:45 Madrid). Hito de cierre de revisión
**13:06:02 UTC** (15:06:02 Madrid): **34 min 17 s observados**, sin estimación
previa. Incluye investigación accesible desde GitHub, lectura de las dos vistas
originales, implementación y comprobaciones; no incluye la tarea posterior de
árboles ni el tiempo final de publicación. No representa horas de trabajo manual
de modelado en una herramienta externa ni una animación de captura de movimiento.

Malla: nuevos perfiles de tórax/espalda/clavículas, 48 lados por sección del
torso y 24 por anillo de miembros; detalle de ojos, mandíbula, barba, mechones,
cierre de corona y entrepierna. Enlace entre malla y esqueleto corregido,
controles de volumen de codos/rodillas, orientación de palmas, codos ligados al
torso y separación continua respecto al tórax. Armadura adaptada y postura de
arco abierta. La proyección de pinturas deja de mezclar UV frontales y
posteriores dentro de un mismo triángulo: se corrigieron las bandas visibles
en los codos y la unión de cuello. Los contornos de raíces de brazos enterradas
no se proyectan como costuras falsas sobre el pecho. La tela central permanece
en la pelvis y los bajos acompañan los muslos.

Referencias realmente examinadas: OpenSim Arm26, Gait2392 Millard y
`subject01_walk1_ik.mot` (211 muestras). BVH consultado solo para jerarquía, sin
atribuirle una acción. Las webs de Little League/Wikipedia permanecieron
bloqueadas por el proxy. Ver `ANIMATION_REFERENCES.md` para enlaces y límites.

Validación: prueba nueva de piel deformada, enlace, UV y continuidad de 29
acciones × 8 familias; catálogo de agarres, carrera, deslizamiento/salto,
cámara/zancada, arco, armadura, referencia de malla, movimiento real y guardado.
Renderizado nativo de fases frontales/laterales, con y sin armadura, y vistas
de reposo frente/espalda/lados. Se usó también material neutro para distinguir
un fallo de UV de un fallo de geometría. La revisión visual sigue siendo
necesaria para valorar parecido y naturalidad; las pruebas no certifican un
modelo idéntico a una imagen ni animación perfecta.

## 2026-10-15 — Nueve modelos de árbol y superficies propias

Inicio observado **13:07:19 UTC** (15:07:19 Madrid). Hito de integración y
revisión **13:29:04 UTC**: **21 min 45 s observados**, todavía antes del cierre y
publicación. Estimación comunicada durante la tanda: 20–30 minutos adicionales
para su pulido y pruebas; se registra separadamente de la nueva cintura.

Se reconstruyeron nueve siluetas a partir de una única vista por diseño,
completando ramas y copas en profundidad, raíces, curvas y hojas cerradas con
pliegues. Hubo varias pasadas: se retiraron rellenos esféricos visibles, se
ensancharon hojas que parecían púas, se ajustó su orientación, irregularidad y
color, y se cerraron extremos de madera. Dos mapas propios de 512×512 sustituyen
los atlas de personaje/enemigo. Caché de 36 variantes, una superficie por árbol,
colisiones del tronco curvado y cámara independiente. Se conserva la población
y escala originales.

Pruebas: 383 comprobaciones específicas de formas/360°/recursos/interacciones,
739 de integración del prototipo, 27 de población y 191 de guardado. La prueba
de contacto se reposicionó para apuntar al nuevo tronco curvado a distancia
alcanzable, en lugar del vacío que ocupaba el cilindro antiguo. Renderizado de
los nueve diseños en ocho orientaciones y vistas por encima/debajo de la copa.
Población medida: 83 árboles y 5191 grupos de césped, carga observada 3222 ms en
esta máquina. Este dato no es una medición de FPS. F6 disponible en tree_review.

Cierre de la tanda de árboles registrado a **13:30:47 UTC**: **23 min 28 s**
observados desde el inicio, antes del último commit/push. Se añadieron pequeñas
ramillas visibles entre las hojas y se validó la escena de revisión independiente.
