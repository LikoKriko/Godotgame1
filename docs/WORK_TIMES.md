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

## 2026-10-15 — Cintura, pinturas envolventes y ropa ajustada

Inicio observado **13:36:56 UTC** (15:36:56 Madrid). Validación de integración
cerrada a **13:58:19 UTC**: **21 min 23 s transcurridos**, incluyendo consultas e
interrupciones de conversación; no se presentan como tiempo de ejecución
continua. Estimación previa: 40–60 minutos adicionales para el personaje.

El torso se reconstruyó con secciones medidas en ambas referencias, profundidad
propia, cintura más estrecha y transición de caja torácica/cuello. Se ajustaron
caderas, puente de tela, perneras y cuerda. Las pinturas frontal y posterior
ahora se muestrean por separado y se mezclan por color en los laterales. La
ropa usa límites propios por pierna para evitar pintar el fondo entre ellas.
La armadura comparte el perfil y se abrieron sus ataduras superiores para
eliminar un roce durante el golpe de hacha.

Pasaron las pruebas de deformación (145006), catálogo (8588), brazos (374),
cámara/zancada (1116), deslizamiento (2027), referencia (539), armadura/modelo
(24), arco (69), integración (739) y movimiento real. Una prueba nueva añade
10 comprobaciones de cobertura/proporciones/unión de tela, tomando muestras
interiores de triángulos de ambas imágenes. Revisión nativa de frente, espalda,
lados y diagonales, con/sin armadura, en reposo, movimiento y herramientas.
La revisión artística sigue siendo necesaria: no se afirma identidad exacta
con una imagen plana ni perfección de todas las animaciones.

El ajuste de cámara/mira solicitado durante esta tanda se realizará después de
publicarla, separado de los cambios del modelo.

## 2026-10-15 — Mira cercana y convergencia del cuerpo

Inicio observado **14:00:09 UTC** (16:00:09 Madrid), después de publicar el
modelo en `979623f`. Primer hito registrado **14:03:34 UTC** (3 min 25 s).
Reanudación observada **15:14:33 UTC**, validación nativa **15:16:49 UTC**
(2 min 16 s del segundo bloque). El intervalo intermedio no tiene registro
continuo de trabajo y **no se imputa como duración activa**. Estos son hitos
parciales, no una medición completa del tiempo de la tarea.

El usuario escogió reducir a la mitad el desplazamiento lateral: 0,60 → 0,30 m.
El cuerpo converge al contacto real en vez de seguir una línea paralela a la
cámara. Un golpe mantiene su contacto al moverse; el arco conserva seguimiento
hasta el disparo. El raycast de inicio entrega juntos objeto y punto. Se
sustituyó el glifo de la mira por un punto geométrico centrado: en el render de
1280×720 los cuatro píxeles blancos rodean exactamente (640,360).

Pruebas: 62 específicas de proyección, tamaños de viewport/HUD, 16 rumbos,
contacto bloqueado, punta visible e impacto real; 1116 de cámara/zancada, 69 de
arco, 65 de equipo, 739 de integración y movimiento real. Render nativo con
comparación del desplazamiento anterior/nuevo. Se registró la división de
trabajo por chats en `ANIMATION_AREA.md`.


## 2026-10-15 — Incorporación del chat de animaciones

Revisión de la copia local `prototype/third-person-3d`, commit `99a5a91`:
instrucciones, documentación, catálogo de poses, rig y pesos humanos,
cinemática/agarres, deslizamiento, integración del jugador, modelo/poses del
joven y escenas de revisión. Sin cambios en el código ni los recursos del juego.
Estimación previa no registrada. Inicio de la revisión no cronometrado; no se
atribuye una duración total exacta. Bloque final observado entre **17:55:12 y
17:55:21 Europe/Madrid**: **9 s parciales**, no duración completa de las pruebas.

Godot 4.6.3 headless: catálogo **8588 comprobaciones, 0 fallos**; criatura,
memoria, parry y HUD **6531 comprobaciones, salida correcta**. Se redirigieron
los directorios XDG al área de trabajo tras fallar la escritura del directorio
de usuario predeterminado. No hubo revisión visual renderizada en esta tarea.
La consulta de ramas remotas falló al conectar con el proxy; no se certifica
que la copia local coincida con el último estado de GitHub.


## 2026-10-15 — Naturalidad del superviviente y contactos cerca de la mira

Primer hito observado **15:59:43 UTC** (17:59:43 Madrid); cierre de validación
**16:21:17 UTC** (18:21:17 Madrid). Intervalo medido parcial:
**21 min 34 s**, incluyendo lectura, edición, pruebas y
renderizado. No se registró el comienzo exacto anterior a ese primer hito ni
una estimación previa; no se presenta este intervalo como duración total exacta.

Pelvis y pecho coordinados, transferencia de peso, entrada de movimiento,
preparación del puño, flexión para golpes bajos, equipamiento en arco, equilibrio
de salto, agachado y apoyos de la caída. Tensado continuo del arco sin alterar
sus 0,5 s ni munición. Recogida dirigida de 0,72 s, paso corto al caminar,
contacto de la mano a 0,36 s y transferencia diferida sin duplicación ni pérdida
por mochila llena/alejamiento. Selección de corto alcance en un radio del 1,8%
de altura del viewport; centro prioritario, superficies visibles y comprobación
de obstáculos/alcance al contacto. Escena F6 con pausa, fase y contacto ajustable.
Se conserva la versión 2D, anatomía, zancada/cadencia, referencias y reglas de
herramientas. Cambios locales sin commit/push; remoto comprobado en `99a5a91`.

Validación en Godot **4.6.3**: deformación humana **145006**, catálogo **8588**,
acciones naturales/tolerancia/contactos/recogida andando **4050**, cámara/zancada
**1116**, deslizamiento **2027**, brazos **374**, mira **62**, equipo/arco/armadura
**65**, integración general **739**, guardado **191**, interacciones **15** y
botín **16**: suites superadas. También pasó movimiento real con recogida y
recuperación, ajustando su espera a la nueva duración. `git diff --check` limpio.
Se renderizaron **288 fotogramas** de doce acciones y **64 vistas** de contacto
en ocho orientaciones con/sin armadura, además de agachado, caída y recogida
andando. La inspección detectó y corrigió rodillas bajo suelo y falta de alcance
en contactos bajos del pico. Las pruebas conservan longitudes y agarres; no
certifican naturalidad perfecta ni procedencia de mocap. La previsualización
MP4 y las capturas quedan como material intermedio en el área de trabajo.


## 2026-10-15 — Contexto del chat de modelado y texturas

Hito final observado: **2026-10-15 17:51:13 CEST**. Inicio sin registrar; duración total
no medida. Sin estimación previa: revisión exploratoria de alcance.

Revisión de AGENTS.md, documentación 3D/migración, árboles, referencias de
animación y documento de confianza/afinidad. Inspección visual de referencias
y atlas de personajes, enemigo, herramientas, armadura, edificio y terreno;
lectura de generadores de modelos, materiales y escenas de revisión.
Rama local observada: `prototype/third-person-3d`. No se consultó el remoto,
no se modificaron modelos/texturas y no se ejecutaron pruebas ni un render 3D.
Este chat se dedica a modelado y texturas; la zona de animaciones ya consta
en `ANIMATION_AREA.md`. La revisión no constituye aprobación artística final.


## 2026-10-15 — Primer pulido de hombros y pelo del superviviente

Inicio observado: **17:52:35 Europe/Madrid** (15:52:35 UTC).
Cierre observado: **18:02:32 Europe/Madrid**
(16:02:32 UTC). Duración medida: **9 min 57 s**, incluidas
lectura, ajustes, capturas, comprobaciones y documentación. Sin estimación previa.

Referencias frontal y trasera originales conservadas. Perfil proximal del brazo
y tórax superior ajustados, normales del hombro suavizadas y contorno de raíces
enterradas corregido. Cubierta de pelo separada del cráneo y mechones más amplios,
escalonados y barridos; nuca cubierta. Esqueleto y agarres conservados.

Godot 4.7.2: 145006 comprobaciones de deformación, 539 de referencias/poses,
24 de escultura/armadura, 10 de superficie/UV y 33 rayos de cobertura del pelo,
todas pasadas. Revisión nativa de 16 capturas: cuatro ángulos en reposo y dos
por carrera/golpe/arco con y sin armadura. Comparativa antes/después guardada en
`/workspace/work/modeling-review/comparison.png` y mostrada en el chat. Cambios locales en `prototype/third-person-3d`; sin push.


### Publicación solicitada e integración con animaciones

Hito observado: 2026-10-15 18:30:07 CEST.
Duración de publicación sin medir; sin estimación previa. El usuario solicita
commit y push. El primer push se rechaza por avance concurrente de la rama.
Se integra `69a4d8f` mediante rebase, conservando ambos registros de tiempos;
los cambios de modelos y rig se combinan sin conflicto de código.

Tras integrar: pasan 145006 comprobaciones de deformación, 33 rayos de pelo y
4050 comprobaciones de las nuevas acciones. `prototype_3d_model_corrections.gd`
falla en tres comprobaciones (descenso en golpes y holgura de armadura en hacha
y espada). Se reproduce exactamente el mismo fallo en una copia aislada del
commit remoto `69a4d8f`, sin el pulido: son fallos previos a esta integración.
No se alteran los criterios ni las animaciones del otro departamento.

## 2026-10-15 — Revisión y corrección conjunta de departamentos

Primer hito cronometrado **16:30:56 UTC** (18:30:56 Madrid). Cierre de validación
**16:41:01 UTC** (18:41:01 Madrid): **10 min 5 s observados**, sin estimación
previa. Incluye obtención de entregas, reproducción de fallos, correcciones,
pruebas y revisión gráfica; no incluye el inicio anterior al primer hito ni
la documentación y publicación posteriores.

Base remota `c99e19b`, que incluye la entrega de animación `69a4d8f`. Revisión
en copia aislada para conservar la copia local anterior. Ajustadas las ataduras
superiores de hojas y la preferencia de agarre adelantado de la espada. No se
recorta la cobertura de hojas ni se cambian agarres de dos manos. El primer
ensayo de preferencia de agarre aplicado también a herramientas de dos manos
producía una discontinuidad; se descartó y la prueba de continuidad volvió a pasar.

Se reproducen los tres fallos comunicados por modelado. El límite global antiguo
de descenso no corresponde a los nuevos contactos bajos: se conserva en golpes
altos y se añaden comprobaciones de alcance, punta y apoyo para los bajos.
La holgura de 1,3 unidades se comprueba en 33 fases frente a las ocho anteriores;
ese muestreo detectó otros roces intermedios, corregidos antes de cerrar.

Godot 4.7.2: 23 suites superadas. Entre ellas, deformación **145006**, catálogo
**8588**, acciones naturales **4050**, integración **739**, modelos/contacto/
armadura **42**, pelo **33**, guardado **191**, criatura **6531**, árboles **383**.
Suites X11 con clics reales: inventario **17** y menú/configuración/guardar/
continuar **11**. Se renderizaron y examinaron **16 capturas finales** con y sin
armadura. Los logs y capturas son intermedios en `/workspace/work/integration-review`.
Linux usa llvmpipe y no hay dispositivo de audio físico; no se atribuye una
prueba de sonido, rendimiento de usuario ni Windows a esta revisión.



## 2026-10-15 — Eliminar líneas proyectadas en la piel de los brazos

Inicio observado: **18:51:32 Europe/Madrid** (16:51:32 UTC). Cierre de
implementación observado: **18:55:37 Europe/Madrid**
(16:55:37 UTC). Duración medida hasta este hito: **4 min 5 s**.
Sin estimación previa. Incluye diagnóstico, ajuste de UV, render y pruebas;
la publicación posterior no está incluida en este intervalo.

Diagnóstico renderizado: las líneas persistían al desactivar el contorno, y
desaparecían al desactivar la pintura de los brazos. La proyección directa
muestreaba el borde oscuro de las referencias. Se sustituye únicamente en los
brazos por un recorrido longitudinal propio con márgenes interiores medidos
en ambas imágenes. Se conservan la geometría, esqueleto, contorno y mapeados
del torso/piernas. No se modifican imágenes originales.

Pasan 10368 muestras interpoladas de textura de brazos (cero píxeles de borde),
10 comprobaciones de superficie/UV y 145006 de deformación. La nueva prueba
falla con el mapeado anterior en la copia aislada de `69a4d8f`: 2534 muestras
de borde/fondo sobre 8832, antes del pulido geométrico. Revisión renderizada
en reposo frontal/trasero/lateral y carrera/golpe/arco, con y sin armadura.

Integración previa a publicar: se incorpora el avance remoto `92d3189`, que
resuelve las comprobaciones de golpes y armadura pendientes. Los únicos
conflictos fueron notas añadidas al final de documentos; se conservan ambas
entradas. Tras el rebase pasan las 10368 muestras de brazos, las 10 pruebas
de superficie/UV y las 42 comprobaciones actualizadas de contacto y armadura.

## 2026-10-15 — Corrección de la marcha diagonal

Primer hito observado **18:51:53 Madrid**; cierre de comprobaciones
**18:56:35 Madrid**. Intervalo medido parcial **4 min 42 s**;
no se registró una estimación previa ni el inicio exacto anterior al primer hito.
Se giran conjuntamente carriles de apoyo, rodillas y pies hacia la diagonal,
con acompañamiento parcial de pelvis y mezcla de orientación. Se conserva la
cadencia, velocidad, anatomía y la recogida con su postura específica.

Se incorporaron primero `c99e19b` y `92d3189` de modelaje/integración, conservando
sus cambios y revalidando el ajuste sobre ellos. Godot 4.6.3: **32736**
comprobaciones de trayectoria, orientación, huesos y agarres en cuatro diagonales,
ocho familias y tres marchas; catálogo **8588**, deformación **145006**, acciones
naturales **4050**, cámara/zancada **1116** y correcciones de modelo/armadura **42**:
todas superadas. Revisión nativa de dieciséis poses de marcha diagonal con/sin
hacha sobre el modelo actualizado; `git diff --check` limpio. El commit conserva
los commits publicados por los otros departamentos.

Integración final: se incorpora también `984c370` (piel de brazos),
conservando ambas entradas del registro de tiempos. El rig se integró sin
conflictos de código; se revalidan marcha diagonal, piel y contactos.

## 2026-10-15 — Revisión conjunta de piel de brazos y marcha diagonal

Inicio observado **16:59:00 UTC** (18:59:00 Madrid); cierre de validación
**17:01:03 UTC** (19:01:03 Madrid): **2 min 3 s observados**, sin estimación
previa. Incluye lectura de entregas, pruebas y revisión gráfica; documentación
y publicación posteriores fuera de ese intervalo.

Revisados `984c370` (UV de brazos) y `309132e` (carriles, rodillas y pies en
diagonal), sobre la integración anterior `92d3189`. Se conservan ambos commits.
No se detectan fallos nuevos en las comprobaciones realizadas ni se requieren
correcciones adicionales de código o recursos.

Godot **4.7.2**, Linux: **16 suites superadas**. Marcha diagonal **32736**;
piel de brazos **10368 muestras**, cero píxeles de borde; deformación **145006**;
catálogo **8588**; superficie/UV **10**; referencias **539**; acciones naturales
**4050**; modelo/contacto/armadura **42**; cámara/zancada **1116**; deslizamiento
**2027**; brazos en carrera **374**; mira **62**; equipo **65**; integración
general **739**; guardado **191**; y movimiento con física real.

Revisión renderizada en X11/Compatibility de **24 capturas**, con/sin armadura:
reposo frontal/trasero/lateral, hacha, espada, arco, recogida, contacto bajo y
las cuatro diagonales, con y sin herramienta. Se mantienen los agarres y la
corrección anterior de armadura. Intermedios en
`/workspace/work/integration-review/round2`. No se repiten las suites de menús,
árboles o criaturas: estas entregas no modifican esos sistemas. No incluye
prueba en Windows, audio físico ni medición de rendimiento del usuario.


## 2026-10-15 — Brazo libre como contrapeso en el ataque de espada

Primer hito observado **19:11:16 Europe/Madrid**, cierre de validación
**19:13:49 Europe/Madrid**. Intervalo parcial medido **2 min 33 s**;
no se registró el comienzo exacto anterior al hito ni una estimación previa.
El brazo vacío se extiende hacia fuera y ligeramente atrás durante preparación
e impacto, conserva una flexión suave de codo y vuelve gradualmente al reposo.
La palma utiliza la orientación de mano libre. Se conservan la trayectoria,
agarre, punto de mira y duración del golpe de espada y las demás familias.

Godot 4.6.3: **1440** comprobaciones específicas de extensión, separación del
torso, continuidad, huesos, agarre y contactos bajos/medios/altos con/sin armadura;
catálogo **8588**, deformación **145006** y modelo/contactos/armadura **42**:
todas superadas. Revisión nativa de **40 poses** en cuatro ángulos y cinco fases,
con/sin armadura; `git diff --check` limpio. Cambios locales sobre `309132e`,
**sin commit ni push por instrucción expresa del usuario**.


## 2026-10-15 — Golpear manteniendo Ctrl/agachado

Primer hito observado **19:15:43 Europe/Madrid**; cierre de validación
**19:18:15 Europe/Madrid**. Intervalo medido parcial **2 min 32 s**;
no se registró el inicio exacto anterior al hito ni una estimación previa.
La postura agachada se aplica al golpe/tensado antes de calcular IK/contacto;
el jugador transmite el nivel suave de agachado de locomoción al modelo y la
comprobación de alcance usa la misma anatomía. Así no se incorpora al atacar
con Ctrl, puede encadenar golpes y caminar agachado mientras ataca. Soltar Ctrl
permite recuperar la postura de pie sin bloquear el gesto. La revisión F6
incluye «Atacar agachado». Se conserva el contrapeso de espada pendiente.

Godot 4.6.3: **836** comprobaciones específicas, incluidas teclas físicas Ctrl,
ataques repetidos de hacha/pico/espada, marcha agachada, soltar Ctrl, poses de
manos libres/arco, longitud de piernas, agarres y contacto de mira; catálogo
**8588**, deformación **145006**, contrapeso de espada **1440**: todo superado.
Revisión nativa de **40 poses** del golpe de espada agachado con/sin armadura.
`git diff --check` limpio. Cambios **sin commit ni push**, manteniendo la
instrucción expresa del usuario de esperar antes de publicar.



## 2026-10-15 — Reconstrucción del joven desde cuatro vistas

Primer hito observado: **19:05:54 Europe/Madrid** (17:05:54 UTC).
Cierre de implementación observado: **19:39:42 Europe/Madrid**
(17:39:42 UTC). Intervalo registrado: **33 min 48 s**.
La lectura anterior al primer hito y la publicación posterior no se imputan
a este intervalo. Sin estimación previa. Incluye estudio de la lámina,
reconstrucción, revisiones renderizadas, ajustes de densidad y pruebas.

Se sustituyen cabeza, torso, brazos, patas, cara, orejas, puños y pelaje.
1836 mechones marrones y 128 dorados cerrados, con relieve y puntas propias;
84 placas de piedra. La malla final tiene 759012 vértices de triángulos y
253004 triángulos; se comparte ligada entre instancias, con esqueletos
independientes. Se elimina la copia temporal de geometría. Altura 0,875 m,
catorce huesos, anatomía adaptada y las mismas categorías de acciones y reglas
de combate. Las imágenes originales se conservan. Se añade la comparación
`docs/previews/young_reference_comparison.png` y el documento `YOUNG_3D.md`.

Revisiones de cuatro vistas y seis acciones con ambas manos. Pasan 2560
comprobaciones específicas de malla/piel/materiales/caché, 6531 de criatura,
539 de referencias y ligaduras, 16 de botín y 191 de guardado. Las tres
primeras suites se repiten tras densificar el pelaje; la de malla se repite
tras retirar la superficie sobrante de la mandíbula. La revisión del joven
ya no deja el marcador de contacto humano sin liberar.

La fidelidad se contrasta con capturas reales; no se certifica una copia
artística idéntica mediante pruebas numéricas ni se inventan vistas ortogonales.
Los laterales de revisión aproximan los de la lámina mediante ±68°. No se ha
medido rendimiento gráfico en el equipo del usuario.

Integración para publicar: se incorporan `309132e`, `c6fa837` y `81d6d1f`
del departamento de animaciones. El único conflicto está en el registro de
tiempos añadido al final; se conservan las entradas de ambos departamentos.
La escena de revisión conserva el control nuevo de ataque agachado del humano.
Tras el rebase vuelven a pasar 2560 pruebas de malla detallada, 6531 de criatura
y 539 de referencias/ligaduras.

## 2026-10-15 — Revisión conjunta de ataques agachado y nuevo enemigo1

Inicio observado **17:42:54 UTC** (19:42:54 Madrid); cierre de validación
**17:45:56 UTC** (19:45:56 Madrid): **3 min 2 s observados**, sin estimación
previa. Incluye lectura de entregas, pruebas, capturas y registro del alcance
provisional de las animaciones; la publicación posterior queda fuera.

Revisados juntos `81d6d1f` (ataques agachado y contrapeso de espada) y `684f9a1`
(reconstrucción del joven), conservando la integración previa `c6fa837`.
El usuario aclara durante la revisión que rehacerá todas las animaciones del
enemigo1 después de esta subida. Se documentan como provisionales en
`YOUNG_3D.md`; no se exige conservar su acabado anterior ni se certifica el
actual como definitivo. No se requieren correcciones adicionales de código.

Godot **4.7.2**, Linux: **19 suites superadas**. Ataques agachado/teclas Ctrl
**836**; contrapeso de espada **1440**; malla/pesos/materiales del joven **2560**;
criatura/combate/parry **6531**; referencias **539**; botín **16**; guardado **191**;
deformación humana **145006**; catálogo **8588**; contacto/armadura **42**;
acciones naturales **4050**; marcha diagonal **32736**; piel de brazos **10368
muestras** sin bordes; cámara/zancada **1116**; deslizamiento **2027**; equipo
**65**; mira **62**; movimiento con física real e integración general **739**.

Se renderizan y examinan **22 capturas** en X11/Compatibility: diez de hacha y
espada agachado con/sin armadura, y doce del nuevo joven (cuatro vistas y ocho
estados/variantes). El shader y la geometría se renderizan sin errores. Logs y
capturas intermedios en `/workspace/work/integration-review/round3`.
No incluye Windows, medición de FPS del usuario, prueba de audio físico ni
aprobación artística final de las animaciones del enemigo1.

## 2026-10-15 — Corrección del torso del joven en cuadrupedia

Primer hito observado: **20:05:13 Europe/Madrid** (18:05:13 UTC).
Cierre de revisión observado: **20:12:46 Europe/Madrid** (18:12:46 UTC).
Intervalo registrado: **7 min 33 s**. La lectura anterior al primer hito y la
publicación posterior quedan fuera; sin estimación previa. Incluye comparación
con las cuatro referencias y la captura del usuario, renders antes/después,
cuatro vistas de enlace y de reposo, seis acciones con ambas manos y capturas
con terreno, jugador e iluminación del mundo de prueba.

Se reduce el núcleo del torso: profundidad máxima 22,2 → 13,4 unidades,
anchura 18 → 14,4; se baja su coronación de 27,3 a 24,8. La inclinación
cuadrúpeda pasa de 0,96 a 0,55 radianes para que la espalda no eleve una gran
joroba y oculte la cabeza. Cola y cresta del lomo siguen el nuevo volumen.
Se conserva la altura normalizada, el detalle de pelaje y el esqueleto.

Pasan **2641** comprobaciones de malla y deformación, **6531** de criatura y
**539** de referencias/ligaduras. Se añaden 81 comprobaciones de las envolventes
reales deformadas de torso y cabeza durante reposo, marcha y carrera: anchura,
profundidad y altura relativa. La proporción de la malla en reposo por sí sola
no detectaba el problema de la postura anterior. Se actualiza la comparación
de referencia y se añaden las de cuadrupedia, antes/después y mundo jugable.
La mejora de silueta está revisada visualmente; siguen existiendo diferencias
artísticas en cara, mechones y acabado respecto a la ilustración original.

Integración de publicación: se conserva `70bacfe`, revisión del departamento
de animaciones. Solo añade documentación; se resuelve el registro de tiempos
conservando ambas entradas. No modifica el código validado.

## 2026-10-15 — Comparación e integración del torso reducido del joven

Inicio observado **18:16:12 UTC** (20:16:12 Madrid); cierre de validación
**18:18:27 UTC** (20:18:27 Madrid): **2 min 15 s observados**, sin estimación
previa. Incluye comparación de código y capturas, pruebas y recuperación de
la pantalla virtual local. Documentación y publicación posteriores fuera
del intervalo.

Comparado `e5c301e` con la integración anterior `70bacfe`: núcleo del torso
más estrecho y menos profundo, menor inclinación cuadrúpeda, y cola/franja
dorsal ajustadas al nuevo volumen. Cabeza, puños, rig y reglas de combate se
conservan. No se requieren correcciones adicionales de código.

Godot **4.7.2**, Linux: **6 suites superadas**. Malla y deformación del joven
**2641**, criatura/combate/parry **6531**, referencias/ligaduras **539**, botín
**16**, guardado **191** e integración general **739**. Se revisan **12 capturas
nuevas** de cuatro vistas y ocho estados/variantes, y una comparación con seis
capturas de la versión anterior usando la misma cámara e iluminación. La
espalda queda más baja y el torso deja de dominar el perfil cuadrúpedo.

Intermedios en `/workspace/work/integration-review/round4`. La pantalla virtual
anterior ya no estaba disponible; se inicia una nueva y el render final termina
sin errores de scripts o shaders. Las animaciones del enemigo1 siguen siendo
provisionales conforme a la instrucción del usuario. No se mide rendimiento
del usuario ni se valida Windows o audio físico en esta tarea.

## 2026-10-15 — Revisión de fidelidad de formas del enemigo1 y comparativa

Primer hito observado: **20:24:19 Europe/Madrid** (18:24:19 UTC).
Cierre de revisión visual observado: **20:49:02 Europe/Madrid**
(18:49:02 UTC). Intervalo registrado: **24 min 43 s**, sin estimación previa.
La lectura anterior al primer hito y documentación/publicación posteriores
quedan fuera. Incluye lectura de la referencia, varias iteraciones renderizadas,
pruebas de perfil y encuadre, poses y comparativa final solicitada por el usuario.

Se rehacen frente/coronilla, puente y disco nasal, apertura de ojos, pupilas,
cejas, mejillas, inserción de orejas, clumps de pelaje, cresta, manchas doradas,
puños, talones y uñas. La coronilla se adelanta; las patas quedan bajo la grupa
y los puños se sitúan según los laterales. Los brazos conservan sus longitudes
durante cada animación con segmentos de 7,1 y 7,5 unidades. Se actualizan el
anclaje de cabeza y la zona de impacto del hocico. El torso conserva la anchura
reducida y una menor profundidad que la cabeza. Se mantienen 0,875 m y 14 huesos.

La malla final comparte **1277 mechones marrones, 130 dorados y 84 placas**;
**965124 vértices / 321708 triángulos**, sin indexar. Las nuevas secciones curvas
aumentan los vértices pese a reducir el número de mechones respecto al primer
modelo; no se afirma una mejora de rendimiento ni se ha medido en el PC del
usuario. Se atenúa la proyección de color y se afinan los contornos y normales.

Pasan **2642** comprobaciones de malla/piel/materiales/poses, **6537** de
criatura/combate y **539** de referencias/ligaduras. Las nuevas verificaciones
comprueban que la geometría ligada no salga bajo el suelo y que la zona de
impacto de la nariz siga un vértice real del hocico en cinco estados. La suite
de malla se repite tras los últimos ajustes de pelaje y cresta.

Se revisan cuatro vistas de enlace, cuatro cuadrúpedas, seis acciones con ambas
manos y cuatro cámaras con terreno, jugador e iluminación del mundo de prueba.
La comparativa `young_reference_comparison.png` conserva arriba la referencia
y debajo renders reales; ambas figuras tienen la misma altura visible, sin
estirar sus proporciones. Se actualizan la comparativa cuadrúpeda y la captura
del juego; se añade `young_fidelity_before_after.png`. No se retoca la referencia.
Los laterales usan ±68° aproximados; no se certifica una copia exacta ni se
convierte la coincidencia de silueta en un porcentaje global de parecido.

Publicación: se integra `976c011` del departamento de animaciones, que solo
añade documentación. El conflicto del registro se resuelve conservando ambas
entradas; no se modifica el código sometido a las pruebas anteriores.


## 2026-10-15 — Carpeta de entregables del enemigo1

Hito observado: **19:04:17 UTC** (21:04:17 Madrid). Sin estimación previa ni
duración total medida. Creada `entregables/enemigos/enemigo1/` con `.gitkeep`
para conservarla en GitHub. Comprobación de ruta y cambios; no requiere pruebas
del juego. Los entregables existentes permanecen en su ubicación.


## 2026-10-15 — Sustitución del enemigo1 por el FBX Meshy del usuario

Primer hito observado: **21:15:44 Europe/Madrid** (19:15:44 UTC).
Cierre de implementación y revisión observado: **21:38:12 Europe/Madrid**
(19:38:12 UTC): **22 min 28 s registrados**, sin estimación previa.
La descarga anterior al primer hito y la documentación/publicación posterior
no se imputan al intervalo. Las gestiones previas para obtener un enlace
accesible tampoco forman parte de esta duración.

Se descarga el ZIP de la Release `modelo-enemigo1`; su SHA-256 coincide
exactamente con `f0af7cc7091dfa1c6219a23b6c609e695a1a7dae90206889fab21802ed4c3655`.
El FBX original se conserva sin modificar en `entregables/enemigos/enemigo1/source`
y los cuatro PNG, byte por byte, en `assets/enemies/first/meshy`. Se elimina la
geometría procedural y sus dos shaders, junto con capturas antiguas de
antes/después. Se actualizan documentación, referencia vigente y comparativas.

El archivo no contiene rig ni animaciones. Se prepara una ligadura de catorce
huesos mediante difusión de calor de Blender 4.3.2 y se exportan cuatro pesos
normalizados por vértice. La primera asignación analítica se descarta al revisar
estiramientos de mejillas en el golpe; la entrega utiliza difusión de calor,
sin vértices sin ligar. Se conservan los **977782 triángulos** originales;
**488891 vértices de autoría / 518861 de ejecución** por separaciones de UV y
normales. Solo se normalizan escala y posición, manteniendo las proporciones
y las imágenes. Recurso nativo preparado una vez, compartido entre instancias;
no se generan mechones ni pesos al iniciar la partida. Se adaptan anclajes,
longitudes y zona de impacto del hocico a la malla nueva. Altura 0,875 m.

Godot 4.7.2, Linux: pasan **2573** comprobaciones de importación/identidad de
FBX y PNG/UV/triángulos/pesos/poses/caché, **6537** de criatura/combate/contacto,
**539** de referencias y ligaduras, **16** de botín, **191** de guardado y **739**
de integración general. La suite de importación se repite tras incluir el FBX
original en el repositorio y exigir su SHA-256. `git diff --check` limpio.

Se revisan cuatro vistas originales, cuatro cuadrúpedas, seis acciones con
ambas manos y cuatro cámaras con jugador, terreno y luz del mundo de prueba.
Comparativa actualizada con renders reales del Meshy; se conserva la referencia
artística arriba y el archivo importado debajo. No se afirma que Meshy traiga
animaciones ni que las adaptaciones provisionales sean la animación final.
No se valida rendimiento del PC del usuario, Windows ni audio físico.

Se incluyen herramientas reproducibles para exportar anclajes, convertir el
FBX con ligadura y preparar el recurso Godot. Se incorpora `b247ca5` del otro
departamento antes de trabajar; añade la carpeta de entregables del enemigo1.


## 2026-10-15 — Rehacer las animaciones del enemigo1 reconstruido

Primer hito observado **19:47:31 Europe/Madrid**; cierre de validación
**20:08:53 Europe/Madrid**. Intervalo medido parcial **21 min 22 s**;
no se registró el inicio anterior al primer hito ni una estimación previa.
Se actualizó la rama de `81d6d1f` a `70bacfe` antes de editar, incorporando la
reconstrucción de modelaje/texturas y su revisión de integración.

Se rehacen quince estados: reposo, caminar, correr, incorporarse, puñetazos
alternos, bajar, sentarse, sentado, levantarse, alimentación, caer/estar/salir
del aturdimiento, muerte y cadáver. Se separa la postura de enlace de cualquier
fotograma animado. Los hashes de todos los arrays de la malla (759012 vértices,
normales, colores, pesos, UV y proyecciones) y de la imagen de referencia siguen
idénticos a la base publicada. No se cambian proporciones, pelaje, piedra, cara,
materiales ni catorce huesos. El giro de los segmentos usa marcos de flexión
completos; las transiciones se resuelven de nuevo con longitudes constantes.
La marcha usa apoyos de puños y uñas/talones, las recolocaciones alternan patas
y las interrupciones parten de la pose mostrada. El catálogo y la escena F6
comparten duraciones y admiten pausa/fase manual para el joven. No se alteran
velocidad, daño, personalidad, memoria, vida, recompensas ni ventanas de combate.

Godot **4.6.3**: nueva suite de movimientos **21924**, malla de referencia
**2560**, criatura/memoria/parry/HUD **6531**, modelos/referencias **539**, botín
**16**, guardado **191**, integración general **739** y equipo **65**: superadas.
Se comprueba piel real con pesos, apoyos, continuidad entre estados/ciclos,
interrupciones, independencia de instancias y cadáver inmóvil. Se renderizaron
**256 fotogramas** del catálogo, **64 vistas** desde cuatro ángulos y **64 poses**
finales de incorporarse/sentarse por apoyos alternos. La revisión corrigió
penetración de pelaje de patas en suelo, giro de extremidades y copia del
plegado del modelo antiguo. Son animaciones de autor, no mocap ni simulación
física del pelaje. `git diff --check` limpio. Cambios locales **sin commit/push**.

Nota histórica: la tarea anterior quedó local sobre `70bacfe`; el usuario
solicitó después trasladar las animaciones al Meshy de `d551f4c`. La malla
procedural y sus hashes de aquella comprobación no son el modelo vigente.

## 2026-10-15 — Trasladar las animaciones al enemigo1 Meshy vigente

Primer hito observado **21:46:32 Europe/Madrid**; cierre de comprobaciones
**21:56:39 Europe/Madrid**. Intervalo medido parcial **10 min 7 s**; no se
registró el inicio anterior al primer hito ni una estimación previa. El commit
se realiza después de este hito, por petición expresa del usuario durante
la tarea; no se solicitó push para esta entrega.

Se actualizó de `70bacfe` a `d551f4c`, conservando una copia de los cambios
pendientes antes de integrar. Se trasladan las quince animaciones a los
anclajes del Meshy Mossclaw Boar. Se preservan el FBX, `.res`, PNG, geometría,
UV, pesos y topología publicados; no se recuperan los modelos procedurales.
La postura fija de enlace reproduce exactamente los puntos originales de
`rig_seeds.json`, comprobados también con el exportador. Se adaptan apoyos,
puños, transición a guardia, alimentación, descanso, aturdimiento y muerte.
Se corrigen penetraciones detectadas de suelas, piedra de los puños y hocico,
y los saltos al interrumpir acciones. No cambia el balance del combate.

Godot **4.6.3**, pruebas superadas: movimiento **21935**, identidad de Meshy
**2573**, criatura/parry/HUD **6537**, referencias **539**, botín **16**,
guardado **191**, integración **739** y equipo **65**. Revisión visual nativa
Compatibility de **128 fotogramas** (16 poses/estados incluida referencia,
cuatro fases y dos cámaras), con montajes frontal y lateral de marcha,
golpe, sentarse, alimentación, muerte y cadáver. `git diff --check` limpio.
No incluye prueba manual en Windows ni rendimiento del ordenador del usuario.

## 2026-10-15 — Importar la botella y el superviviente Meshy del usuario

Primer hito observado **22:32:24 Europe/Madrid**; cierre de comprobaciones
**23:16:04 Europe/Madrid**. Intervalo medido parcial **43 min 40 s**.
La descarga comenzó antes del primer hito y no se reconstruye su inicio exacto.
Estimación comunicada durante la revisión: **45–75 minutos restantes** para
ambos modelos, incluyendo integración y comprobaciones. Commit y push se
realizan después de este cierre, por autorización expresa reiterada del usuario.

Se actualizó primero a `de2923d`, conservando las animaciones del enemigo del
otro departamento. Se descargaron las Releases `modelo_botella_3d` y
`modelo_personaje3d`; los SHA-256 de archivos y PNG originales están en sus
`source.json`. Los FBX se conservan sin editar en entregables. Se sustituyeron
la botella y el cuerpo procedural del personaje por recursos nativos con la
geometría y los cuatro mapas del usuario, sin remallar ni diezmar las mallas
visibles. Primer hito de botella e inventario: **22:40:26**, con 155 pruebas de
objetos superadas; después se ajustaron el cuello, contacto de boca y escala
física compartida entre mano y suelo.

El personaje recibe pesos por transferencia desde un proxy auxiliar de cálculo
y mantiene la malla original. Se adaptan articulaciones, tela, recogida,
deslizamiento, recuperación de hacha/pico y armadura horneada sobre el torso
real. Se corrige la orientación de la flecha desde la mano efectiva hasta el
objetivo. Se retiraron proyección fotográfica y shaders procedurales del
personaje; sus tres pruebas específicas se sustituyen por procedencia,
identidad de geometría/materiales, independencia de actores y contactos sobre
los nuevos recursos, conservando las pruebas de deformación y continuidad.

Godot **4.7.2**, importación final sin errores. Pruebas superadas: assets **32**,
brazos **374**, catálogo **8588**, piel/articulaciones/continuidad **145005**,
ritmo/cámara **1116**, ataque agachado **836**, marcha diagonal **32736**,
deslizamiento **2027**, acciones naturales/recogida **4050**, contactos y
separación con armadura **41**, equipo **65**, objetos físicos **155**,
integración **739**, interacción/botella **15**, arco **69**, movimiento en vivo,
referencias **537**, guardado **191** y movimiento del enemigo vigente **21935**.
Interfaz real X11: **17** comprobaciones. Total numérico **218528**, además de
las pruebas de movimiento en vivo y dos comparaciones independientes contra
los FBX sin rig. Todos los índices de triángulos coinciden; posiciones, UV y
normales conservan la precisión del empaquetado de Godot, documentada en
`docs/MESHY_ASSETS.md`.

Revisión visual nativa Compatibility: cuatro vistas iguales de FBX original y
actor en juego, ocho poses con herramientas/botella/armadura, iconos transparentes
y captura del personaje con botella equipada y caída en la escena real.
Láminas en `docs/previews/`. `git diff --check` limpio. No incluye sesión manual
en Windows ni rendimiento medido en el ordenador del usuario.

## 2026-10-15 — Animaciones del superviviente Meshy, espalda y deslizamiento

Primer hito observado **23:24:06 Europe/Madrid**; cierre de validación
**23:39:58 Europe/Madrid**. Intervalo medido parcial **15 min 52 s**. No se
registró el inicio anterior al primer hito ni una estimación previa. En el hito
**23:30:09** ya estaban incorporados los dos fallos señalados durante la tarea:
escápulas exageradas al moverse y pierna deformada al deslizarse.

Se actualizó de `de2923d` a `c0bcd4b` para trabajar sobre el Meshy Wild Wanderer
vigente. Se conserva la primera adaptación de modelado y se corrige la ligadura
que asignaba zonas centrales de la espalda casi al 100% a un brazo. En las
muestras diagnósticas, el máximo desplazamiento respecto al tórax pasó de
8,48 unidades en una acción a 0,015; carrera de 1,99 a 0,111. Se transfieren
influencias a pecho con transición hacia el deltoides; no se cambia la forma.
El FBX y PNG siguen intactos. La comparación contra el recurso publicado
confirma igualdad exacta de todos los arrays ajenos a huesos/pesos, incluidos
posiciones, normales, tangentes, UV y triángulos. Se conservan sus buffers
empaquetados para evitar una segunda cuantización de normales. La corrección
es reproducible y estable al reaplicarla; el rig fija su reposo con las semillas
publicadas, independiente de las animaciones.

Se rehace el deslizamiento completo: cadera de apoyo, rodilla recogida con
espacio para la pantorrilla, pierna adelantada con flexión suave, pecho curvado
respecto a la pelvis y brazos libres adelantados con codos flexionados. Los
agarres se conservan y el salto parte de la pose mostrada, incluyendo ambas
transformaciones de torso/pelvis. Referencias consultadas: Baseball Canada,
Sliding Fundamentals, y Ficklin et al., J Sport Health Sci, figura 1B
(enlaces en `docs/PROTOTYPE_3D.md`). No es captura de movimiento. No cambian
velocidad, duración 0,46 s, frenada ni dirección de la mecánica.

Se corrigen además penetraciones de suelas al rodar el pie, dedos al recoger
objetos bajos y rodillas/manos al morir. El agarre de objetos ocultos deja de
arrastrar la mano durante muerte; la precisión de los impactos y de E permanece.

Godot **4.6.3**: **17 suites superadas**. Piel/volumen/continuidad **145005**,
catálogo **8588**, diagonales **32736**, acciones/mira/E **4050**, combate
agachado **836**, contrapeso espada **1440**, deslizamiento/salto **2028**,
brazos de carrera **374**, procedencia Meshy **32**, nueva regresión de piel,
espaldas, apoyo y enlace **4376**, cámara/marcha **1116**, integración **739**,
equipo **65**, guardado **191**, objetos **155**, contactos/armadura **41** y
animaciones enemigo1 **21935**. Se actualizó la antigua aserción de altura
exacta del hueso del tobillo: ahora permite elevarlo para que la suela real
rote sin enterrarse; la nueva suite comprueba los vértices deformados.

Revisión nativa Compatibility: **144 fotogramas finales** del deslizamiento,
16 fases, tres cámaras y tres familias (vacío, espada y hacha), además de
comparación frontal/trasera de espalda y muestras del catálogo sobre el nuevo
modelo. Importación de editor y `git diff --check` sin errores. No incluye
Windows ni mediciones de FPS en el ordenador del usuario. Cambios locales,
sin commit ni push para esta tarea.

## 2026-10-15/16 — Rehacer hacha, pico, espada y arco con referencias

Primer hito observado **15/10 23:42:47 Europe/Madrid**; cierre de revisión
**16/10 00:08:37 Europe/Madrid**. Intervalo medido parcial
**25 min 50 s**; no se registró un inicio anterior al primer hito ni
una estimación previa. Se conservan los cambios locales de espalda y deslizamiento
de la tarea anterior, trabajando sobre el Meshy de `c0bcd4b`.

Se consultan referencias de herramientas forestales, trabajo con pico, espada
sola y tiro con arco: enlaces y limitaciones de acceso en
`docs/WEAPON_ANIMATIONS_3D.md`. Se rehacen porte/guardia, carga, golpe,
continuación y recuperación del hacha, pico y espada con esfuerzos diferenciados
de torso y pelvis. Se conserva el contrapeso del brazo vacío. El arco eleva,
une la mano de cuerda, ancla la muñeca junto a la mandíbula, suelta y baja.
El codo de tracción se orienta respecto a la cabeza para despejar tórax y armadura.
La cuerda se une a la mano durante el tensado y vibra después de soltar.

El contacto de herramientas se resuelve para la pose de impacto; las demás fases
usan esa solución estable para evitar saltos al cambiar la orientación del torso.
El solver comprueba el mango/hoja frente a la envolvente del cuerpo y descarta
candidatos por su puntuación mínima antes de hacer las comprobaciones costosas.
Una prueba local de 300 muestras del golpe apuntado de hacha midió aproximadamente
0,25 ms por muestra de pose en CPU; no es una medición de FPS del juego ni del
ordenador del usuario. No se cambian geometría, texturas ni pesos de la piel en
esta tarea, ni daño, consumo de flechas, desgaste, tiempos de impacto o tolerancia
de la mira. El seguimiento `bow_release` dura 0,24 s y es solo visual: permite
otro disparo inmediatamente; se limpia al cargar/reaparecer y puede sustituirse
por correr, saltar, deslizarse o comenzar otra acción.

Godot **4.6.3**, **15 suites superadas**: nuevas armas **27806**, piel/volumen y
continuidad **150005**, catálogo **8844**, mira/acciones/E **4050**, combate
agachado **836**, contrapeso **1440**, armadura/contactos **41**, precisión del
arco y seguimiento en jugador real **73**, piel/apoyos/Meshy **4520**, equipo
**65**, guardado **191**, integración **739**, deslizamiento **2028**, diagonales
**32736**, cámara/cadencia **1116**. Se adapta la comprobación de arco en fase 0:
la cuerda permanece en reposo y la flecha aparece al unirse la mano, en lugar
de estirar la cuerda hacia la mano todavía baja. Durante tensión, culatín y
cuerda coinciden con la mano real. Se comprueban cráneo y tórax, impactos a tres
alturas de pie/agachado, recuperación, codo suave, anclaje, una flecha por disparo
y ausencia de espera adicional antes de volver a tensar.

Revisión nativa Compatibility de **208 fotogramas finales**: 144 de carga,
golpe, recuperación, tensado, suelta y variantes agachadas; 64 adicionales con
armadura desde delante y atrás. Importación de editor y `git diff --check` sin
errores. No incluye Windows ni una sesión manual de juego en el equipo del
usuario. Cambios locales **sin commit ni push** para esta tarea.


## 2026-10-16 — Enemigo1: torso y estado de boxeo con crochet

Primer hito observado **16/10 00:15:35 Europe/Madrid**; cierre de comprobaciones
**16/10 00:23:17 Europe/Madrid**. Intervalo medido parcial **7 min 42 s**.
Sin estimación previa ni inicio anterior registrado. Base local `99dbd72`;
no se modifica el FBX, la malla Meshy, la ligadura, los pesos ni las texturas.

Se acentúa ligeramente el acompañamiento del torso/cabeza del puñetazo normal.
Se añade guardia erguida con ángulo interior del codo de 110°, antebrazos hacia
arriba y puños de piedra separados de la cara. El crochet alterna los brazos,
abre en círculo, acompaña con torso/cabeza y recupera la guardia. Las raíces de
cadera, rodillas y pies permanecen fijas durante el golpe; se resuelve la parte
inferior con una transformación de pelvis independiente del movimiento del torso.
Hay incorporación, bajada y avance en guardia, seleccionables desde F6.

El primer daño no letal habilita una tirada inmediata del 50 % y un reloj de
10 s; recibir daño adicional no concede más tiradas. Un éxito activa 20 s,
sin prolongación durante el estado. Ataques de 1,2 s frente a 1 s normal,
contacto a 0,6 s y 4 de daño base frente a 2. Se mantienen alcance, percepción,
obstáculos y parry. La expiración cancela golpes pendientes. Pausa congela los
relojes; el aturdimiento cancela el ataque, pero consume tiempo del estado.
Persisten activación, variante y temporizadores; los guardados anteriores siguen
siendo válidos. Las reglas exactas constan en `docs/YOUNG_3D.md`.

Godot **4.6.3**, cuatro suites superadas: nueva regresión de boxeo **16675**,
movimiento y apoyos Meshy **29257**, criatura/memoria/parry **8697**, guardado
**194**; total **54823 comprobaciones**. La regresión recorre ambos brazos,
comprueba la distribución de 1000 semillas, daño único, alternancia, expiración,
pausa, muerte, codos y apoyos. Incluye **15180 muestras** de vértices de piedra
ligados frente a la envolvente convexa de la cabeza, también en las transiciones:
ninguna muestra dentro. Se corrige un hundimiento leve de las suelas detectado
al aumentar el giro del torso, sin cambiar la malla ni alargar las patas.

Revisión nativa Compatibility: **112 fotogramas** de siete casos y **28 poses**
adicionales en cuatro vistas; guardia, ambos crochets, entrada/salida, golpe
normal y avance. Se inspeccionan secuencias y vistas de cuerpo completo.
Importación del editor con acceso al socket local y `git diff --check` sin errores.
No incluye una sesión manual en el ordenador del usuario. Cambios locales,
**sin commit ni push** para esta tarea.


## 2026-10-16 — Reparar expansión del torso y los brazos del superviviente

Primer hito observado **16/10 00:27:48 Europe/Madrid**; cierre **16/10 00:38:50
Europe/Madrid**. Intervalo medido parcial **11 min 2 s**.
No hubo estimación previa ni inicio anterior registrado. Base local `e2bdeb4`.

La captura del usuario identifica un defecto real que las comprobaciones
anteriores no detectaban. La máscara v1 fijaba al pecho parte de la superficie
interna del brazo, incluida dentro de la anchura total de la caja del torso.
Al levantar el brazo, la superficie exterior acompañaba al húmero y la interior
quedaba retenida: se ensanchaba la piel. El recorte superior también dejaba
vértices del trapecio ligados al brazo. Se verifica que las transformaciones
reales del esqueleto coinciden con las sondas de CPU: no es un error de cámara.

Se sustituye por `meshy_shoulders_v2`: separación por secciones anatómicas,
transición del deltoides al trapecio, conservación de las influencias relativas
del brazo y de los collares de codo, y distinción de las cuerdas de la cintura.
Se parte de los pesos originales de `c0bcd4b`, para recuperar las influencias
que había eliminado v1. La herramienta acepta esa fuente y exige identidad
geométrica; el importador aplica la misma corrección. Repetirla sobre v2 no
cambia pesos. No se alteran los movimientos, agarres, tiempos ni mecánicas.

En los casos de diagnóstico de arco, puñetazo, espada y hacha, el exceso radial
del brazo superior respecto al eje óseo pasa de aproximadamente **4,92–5,69**
unidades a **0,033–0,045**. Es una medida geométrica de esas poses, no de FPS.
Se mantienen byte por byte posiciones, normales, tangentes, UV y topología
(**491218 triángulos**), además del FBX y los PNG. Solo se actualizan los pesos,
los límites óseos y el metadato de ligadura del recurso.

Godot **4.6.3**, seis suites superadas: regresión Meshy ampliada **12656**,
piel/volumen/continuidad **150005**, procedencia Meshy **32**, contactos/armadura
**41**, trayectorias de armas **27806** y deslizamiento/salto **2028**;
total **192568 comprobaciones**. Las sondas cubren ambos húmeros, antebrazos y
codos en todas las familias y estados, además de tórax, trapecio alto, suelo
y contacto de recogida. Se corrige la selección anterior que confundía la cara
interior del brazo con la espalda, y se añade la zona superior que omitía.
Las sondas usan las transformaciones comprobadas contra `Skeleton3D`.

Revisión nativa Compatibility: **330 fotogramas finales exportados**, con
22 casos, cinco fases y tres cámaras. Se inspeccionan mosaicos frontales,
laterales y traseros de las fases centrales y comparaciones ampliadas antes /
después: portar arco, tensar, equipar, puñetazo y herramientas, además de marcha,
carrera, agachado, deslizamiento y recogida. Importación del editor y
`git diff --check` sin errores. No incluye validación en el equipo del usuario.
Cambios locales **sin commit ni push** para esta tarea.


## 2026-10-16 — Equipar continuo, agarres, rodillas y escápulas

Primer hito observado **16/10 00:56:11 Europe/Madrid**; cierre **16/10 01:14:21
Europe/Madrid**. Intervalo medido parcial **18 min 10 s**.
Sin estimación previa ni inicio anterior registrado. Base local `2302da6`.

Se sustituye el equipamiento heredado: obligaba a ambas manos a ocupar el mango
inmediatamente y partía de claves genéricas distintas de los brazos relajados
que realmente se dibujan. Ahora el brazo principal acerca el equipo por una
curva suavizada y la mano de apoyo se une entre el 25 % y el 85 %. Se captura
la pose visible al cambiar de equipo y se conservan palmas, giro de antebrazos,
codos y torso. La interpolación de polos se sustituye por transporte del plano
de flexión: la prueba arco→hacha detectó un giro brusco de codo que quedó resuelto.
Hay enlaces a reposo, marcha, carrera y agachado, incluido equipar parado con Ctrl.
Los límites de alcance de la mano de apoyo entran gradualmente.

El porte de hacha, pico y espada se inclina 10° más respecto a la vertical;
el arco añade 10° alrededor de su línea de tiro. El apoyo izquierdo del hacha /
pico sube de 7,25 a 8,25 unidades a lo largo del mango, compartidas por perfil
y solver. El codo ocupado baja ligeramente y palma/antebrazo pronan de forma
continua hasta 12°, guiados por el eje del mango. Se preservan el brazo libre
de contrapeso de espada y el codo de tracción del arco.

Se reduce al 40 % la flexión adicional de rodillas del ataque respecto a la
postura base; el agachado de Ctrl sigue siendo una postura independiente.
La nueva altura de cadera se calcula con longitudes óseas constantes. El torso
se inclina más desde la cadera en golpes bajos: evita recuperar el alcance con
otra sentadilla. Se mantienen los impactos en la mira y los tiempos de acción.
El perfil `meshy_shoulders_v3` contiene la superficie escapular, conservando
la movilidad y el grosor del brazo; se hornea desde los pesos de calor de origen.
No cambian geometría, posiciones, normales, tangentes, UV, topología ni PNG.

Godot **4.6.3**, **12 suites superadas**: nueva continuidad de equipamiento
**17892**, piel Meshy y panel escapular **14690**, catálogo **8844**,
deslizamiento/salto **2028**, contactos/armadura **41**, piel/volumen/continuidad
**150005**, armas **28219**, contrapeso espada **1440**, acciones/mira/E **4050**,
combate agachado **836**, equipo **65** y precisión del arco **73**;
total **228183 comprobaciones**. La nueva suite verifica 65 fases de cada
arma y locomoción, posiciones y giros, entrada desde la pose dibujada,
cambios directos entre familias, salida a reposo, apoyo izquierdo, ángulo de
porte, descenso del codo y reducción del 60 % del esfuerzo de rodillas.

Revisión nativa Compatibility: **324 fotogramas finales**, 12 casos, nueve
fases y tres cámaras (frente, lateral y espalda), con mosaicos de secuencias
e inspección ampliada de golpe bajo y arco. Incluye equipar las cuatro armas,
golpear, tensar, puñetazo y variantes agachadas. Importación del editor y
`git diff --check` sin errores. No incluye una sesión en el equipo del usuario.
Cambios locales **sin commit ni push** para esta tarea.

## 2026-10-16 — Departamento de hitboxes: tolerancia y alcance

Primer hito medido: **01:17:10 Europe/Madrid** (23:17:10 UTC del día 15),
tras inspeccionar alcance, selección y colisiones. Hito de validación:
**01:18:19 Europe/Madrid**; intervalo medido de **1 min 9 s**, parcial:
no incluye la inspección anterior ni las comprobaciones finales posteriores.
No se dio estimación previa.

Ampliación de radio de impacto en 0,15 m para árboles, piedras, arbolitos y
joven; separación de áreas de impacto respecto a colisiones sólidas. Alcance
horizontal de golpes de 1 m independiente del solver anatómico; límite vertical
acotado al cuerpo más 0,35 m. Arco conserva alcance de proyectil.

Verificación headless con Godot 4.6.3: 73 comprobaciones nuevas de hitboxes,
12 de recursos, 62 de retícula, 383 de árboles, 6531 de criatura, 69 de arco y 65 de equipo.
Se usaron directorios XDG temporales tras detectar que Godot no podía escribir
su directorio de usuario predeterminado. Pendiente la valoración al jugar del
usuario; las pruebas automáticas no sustituyen esa valoración.

## 2026-10-16 — Enemigo1: colisión y separación entre criaturas

Intervalo medido parcial: **01:21:01–01:22:52 Europe/Madrid**, **1 min 51 s**.
La inspección inicial precede al primer hito y no se incluye; sin estimación
previa. Incluye implementación y pruebas, no una revisión visual del jugador.

La máscara del joven omitía la capa de otras criaturas. Se añade esa capa al
movimiento y al sondeo de obstáculos; el cuerpo pasa a un cilindro de 0,875 m
con radio derivado de la envolvente horizontal del modelo y margen de 2%.
Se ajusta el inicio del ataque a la distancia física de parada, conservando
impacto, daño, hurtboxes y retirada de colisión al morir.

Godot 4.6.3 headless: 1000 comprobaciones de separación (tres perseguidores,
convergencia, criatura inmóvil y arranque del ataque), 6531 de criatura/parry,
30 de edificios/interiores y 73 de hitboxes anteriores. La tolerancia numérica
de contacto del motor es milimétrica; el 2% es nominal sobre la envolvente,
no una distancia fija en pantalla ni una garantía para cada extremidad animada.

### Integración previa a publicación

Se integró el commit de hitboxes sobre `8b341ec`, conservando el modelo Meshy,
las animaciones nuevas, la postura de boxeo y las transiciones de equipamiento
de los otros departamentos. El radio se recalcula con el modelo vigente;
los umbrales de inicio/contacto del ataque también respetan su nueva distancia
física. La prueba de persecución coloca los enemigos inicialmente según sus
radios reales, para no partir de cuerpos ya superpuestos. Duración de esta
integración no medida de forma completa.
Validación tras integrar: 1000 comprobaciones de separación, 16675 de boxeo,
73 de hitboxes, 65 de equipo y 62 de retícula; todas pasadas en Godot 4.6.3.

## 2026-10-16 — Cinco modelos Meshy de equipo y roca

Alcance: sustituir hacha, pico, roca, armadura de hojas y arco por los FBX y
PNG originales publicados por el usuario; conservar fuentes y hashes,
anclar filos y agarres, ligar armadura y cuerda, sustituir modelos físicos
e iconos y retirar la armadura procedural anterior. Incluye documentación,
pruebas y capturas reales en Godot Compatibility. Estimación previa: no
registrada para esta tanda.

| Hito | UTC | Europe/Madrid |
| --- | --- | --- |
| Primera observación registrada del trabajo | 2026-10-15 22:58:40 | 2026-10-16 00:58:40 |
| Inspección del hacha corregida, tras detectar el ZIP duplicado | 2026-10-15 23:13:46 | 2026-10-16 01:13:46 |
| Cierre de implementación y validación | 2026-10-15 23:28:20 | 2026-10-16 01:28:20 |

Duración observada hasta el cierre: **29 min 40 s**. Incluye el tiempo
transcurrido mientras se esperaba el hacha correcta; no se atribuye ese
intervalo exclusivamente a modelado. Commit/push posteriores no están
incluidos en esta medición.

Se integró primero `2302da6` y después el trabajo de animación `8b341ec`,
conservando pesos escapulares v3, transiciones de equipo, manos separadas
8,25 unidades y rodillas menos flexionadas. Los anclajes medidos de las
nuevas herramientas requieren traslación mínima de apoyo para el contacto
bajo, descarte de candidatos que cruzan la cabeza y retirada del hacha
con más separación del pecho. No se cambian las longitudes de huesos.

Validación final: **50.995 comprobaciones en once suites**: armas 27.739;
transiciones de equipo 17.892; contactos/ligadura de armadura 42; combate
agachado 836; acciones naturales/recogida 4.050; arco 73; procedencia y
materiales 100; geometría real de equipo/cuerda/armadura/roca 38; equipo 65;
objetos físicos 147; recursos y elevación 13. La prueba de recursos se
actualizó para esperar el contacto de la recogida animada en vez de asumir
transferencia instantánea.

Comparación independiente contra los cinco FBX: todos los índices de
triángulos, posiciones y UV coinciden; error máximo de normales inferior
a 0,00013 por empaquetado nativo. PNG/FBX se verifican mediante SHA-256.
Importación del editor y `git diff --check` sin errores. Capturas de los
cinco objetos, tres poses equipadas y escena real. No incluye medición de
rendimiento ni sesión manual en el ordenador del usuario.


Integración adicional antes de publicar: el push detectó `301080b`, recién
subido por el departamento de hitboxes. Se conserva su área de impacto de
15 cm en torno a la caja física de la roca importada, sin engordar la
colisión de paso. Su prueba toma ahora el borde del volumen nuevo en lugar
de la coordenada fija de la esfera antigua. Validación adicional pasada:
hitboxes 73, separación de criaturas 1.000, recursos 13, equipo 65, retícula
62, mallas completas 38 y recogida/acciones 4.050.

Cierre tras integrar colisiones: **2026-10-15 23:30:11 UTC**
(**2026-10-16 01:30:11 Europe/Madrid**),
**31 min 31 s observados** desde el primer hito. La publicación en GitHub
se realiza después de este registro.

## 16 de octubre de 2026 — Persecución y caídas de enemigo1 y superviviente

Inicio observado: **16/10/2026 01:18:53 Europe/Madrid**. Cierre de
implementación y comprobaciones: **16/10/2026 01:46:29 Europe/Madrid**.
Duración medida: **27 min 36 s**.
Sin estimación previa registrada. Intervalo de esta tarea, sin commit ni push.

Persecución cuadrúpeda con ciclo de 0,36 s frente a 0,26 s y mayor zancada;
en guardia, 0,65 s frente a 0,52 s. Misma velocidad física. Caídas compartidas
con apoyo de rodillas, reclinado progresivo sobre la espalda y extremidades
abiertas. Captura de postura al interrumpir carrera, ataques, arco, agachado
y deslizamiento. Cadáver estable, ropa asentada e interacción de botín ajustada.
Bisagra necesaria de cola del enemigo; se preservan geometría, proporciones,
UV, materiales, FBX y PNG originales. Corrección local de pesos reproducible.

Godot 4.6.3: **10 suites superadas, 260391 comprobaciones**: caídas **18221**,
movimiento del enemigo **30578**, fidelidad Meshy **3423**, criatura **8697**,
piel Meshy humana **14690**, deformación humana **150005**, equipamiento
**17892**, boxeo **16675**, botín **16** y guardado **194**. Las tres suites
de caídas, movimiento del enemigo y piel Meshy se repitieron tras los ajustes
finales de contacto. Importación del editor y `git diff --check` sin errores.

Inspección adicional de superficie completa en 65 fases: **17.143.620** muestras
de vértices humanos y **33.725.965** del enemigo durante muerte, más
**33.725.965** de persecución; sin penetraciones superiores al margen de
0,12 unidades de autoría. Revisión nativa Compatibility: **102 fotogramas de
muerte** (tres vistas) y **32 de persecución** (dos vistas), con inspección de
secuencias y poses finales completas. No incluye prueba en el equipo del usuario.


Publicación autorizada después de la implementación. Hito de integración:
**16/10/2026 01:49:19 Europe/Madrid**. Se incorporan los commits remotos
`301080b` (contactos y separación) y `b078b2c` (nuevos modelos Meshy) antes de
publicar las animaciones. Único conflicto: entradas anexadas al registro de
tiempos; se conservan ambas. Importación completa del editor sin errores.
Comprobaciones posteriores a la integración: caídas **18221**, modelos y equipo
**38**, hitboxes **73** y separación **1000**, todas superadas sin errores de
script. No se registró un inicio exacto del intervalo de publicación.

## 2026-10-16 — Revisión rápida de entregas combinadas

Inicio observado **2026-10-15 23:50:02 UTC** (16/10, 01:50:02 Madrid);
cierre de validación **23:53:35 UTC** (16/10, 01:53:35 Madrid): **3 min 33 s**.
Alcance solicitado: comprobación rápida. Estimación comunicada durante la
tarea: 3–5 minutos adicionales, pendiente la importación de los nuevos assets.
Documentación y publicación posteriores fuera del intervalo medido.

Comparados los diez commits desde `b247ca5` hasta `4c29883`: modelos Meshy,
rigs, equipo, hitboxes, separación, boxeo, persecución y caídas. No aparecen
marcadores de conflicto. Se corrige una comprobación obsoleta en
`tests/prototype_3d.gd`: contaba piezas del hacha procedural retirada; ahora
verifica la malla Meshy real que debe mostrarse. No cambia el juego.

Godot **4.7.2**, Linux: importación del editor completada y **10 suites
superadas** tras la corrección. Hitboxes **73**; separación **1000**; equipo
Meshy **38**; assets/materiales/procedencia **100**; caídas **18221**;
transiciones de equipamiento **17892**; boxeo **16675**; botín **16**;
guardado **194**; integración general **739**. Revisión adicional de una
captura real del mundo con superviviente, armadura, hacha, pico, arco y roca.
Intermedios en `/workspace/work/integration-review/quick-review`.

La primera importación encontró el bloqueo de sockets del entorno aislado;
la verificación posterior sin ese bloqueo terminó sin errores. El render
final en X11/Compatibility también terminó sin errores de scripts o recursos.
Esta revisión rápida no repite todas las suites ni certifica animaciones
artísticamente, rendimiento del usuario, audio físico o funcionamiento en Windows.
