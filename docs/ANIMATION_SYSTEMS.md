# Animación de Personajes y Enemigos

## Personajes

`scripts/animation/characters/humanoid_profile.gd` define la anatomía humanoide
compartida. `data/animation/characters/survivor.tres` describe los 24 controles
históricos de contactos y ropa, sin una malla visible. El cuerpo del jugador
usa `survivor_native.tres`: los **66 huesos originales** de
`psnj1_3d_rigged.fbx`, con referencia en T y pesos propios. Su escena está en
`assets/characters/prototype_3d/composite/model.scn`.

`native_survivor.gd` enlaza ese rig mediante `RigBinding` y aplica las poses
mediante `SkeletonPose`. Conserva los ejes nativos y las longitudes de brazos,
piernas y columna; ambas manos usan una proporción uniforme de 0,90 desde la
muñeca (`NativeHandGrip.HAND_SCALE`), heredada una sola vez por palma y dedos.
Los pesos originales mantienen la unión de la muñeca con el antebrazo. Usa los planos
articulares compartidos para orientar brazos y piernas. Las curvas existentes
siguen proporcionando ritmo, cuerpo y contactos. Las extremidades libres
adaptan su alcance a las proporciones nuevas; las manos ocupadas resuelven IK
hacia los contactos, incluyendo proyección de clavículas y el centro real de
la palma. El lado 0 de los controles corresponde a Right del rig suministrado;
el lado 1 a Left. Los dedos originales acompañan los agarres. El modelo y el retrato
comparten la malla y los binds inmutables, con esqueletos independientes.

La cabeza aprobada conserva sus UV, normales, tangentes, máscaras y materiales.
Se liga a Neck/Head del rig nuevo. Dos contornos del cuello se unen con
triángulos conformes y los mismos pesos en sus bordes; el color de transición
procede de ambas fuentes. No superponer dos cuellos ni dejar una cabeza rígida
separada del cuerpo. La referencia completa mide 64 unidades de autoría y se
convierte a 1,75 m; consultar `author_bounds()` para encuadrar o escalar instancias.

La parte posterior de cada rodilla conserva volumen mediante los correctivos
`KneeFoldRight` y `KneeFoldLeft`, evaluados en GPU antes de la ligadura.
Se limitan a la piel posterior en un radio longitudinal de 0,13 m, con
un desplazamiento máximo de autoría de 0,08 m y caída cosenoidal suave.
El peso por pierna es `sin(flexión/2)^2`, atenuado de forma continua entre
115° y 145° para respetar el contacto muslo/pantorrilla al arrodillarse.
Se calcula desde la flexión real en todas las acciones, sin cambiar la pose
de reposo, huesos, pesos originales, UV ni geometría de cabeza y cuello.
Las instancias comparten la malla; sus dos pesos correctivos son independientes.

Las fuentes originales y `approved_head_source.glb` están en
`entregables/personajes/personaje1/source/`, excluidas de importación automática.
La instantánea de cabeza conserva la aprobación anterior y permite regenerar
sin depender de cambios posteriores del donante de sobacos. Para preparar la
composición desde la raíz, con Blender 4.3+ y Godot 4.7:

```sh
blender -b -t 6 --python tools/meshy/build_composite.py -- \
  entregables/personajes/personaje1/source/psnj1_3d_rigged.fbx \
  entregables/personajes/personaje1/source/approved_head_source.glb \
  /tmp/survivor-composite/composite.glb
cp /tmp/survivor-composite/body_albedo.png assets/characters/prototype_3d/composite/body_albedo.png
godot --headless --editor --path . --import
godot --headless --path . --script tools/meshy/bake_composite.gd -- /tmp/survivor-composite/composite.glb
godot --headless --path . --script tools/animation/characters/bake_native_ground.gd
```

La preparación compara jerarquía, ejes de reposo y binds con una exportación
independiente del FBX nuevo. `rig.json` y `source.json` contienen los parámetros
vigentes. El apoyo durante la caída reutiliza `SkinGround` con un conjunto
horneado de puntos reales de las tres superficies; no recorre la malla completa
durante el juego. Si cambian las curvas de control, regenerar también estos
apoyos nativos. No transferir los pesos antiguos del cuerpo al rig en T.

## Enemigos

Cada criatura nueva debe tener un perfil propio y separar decisiones, física y
representación. Reutilizar articulaciones continuas e IK, manteniendo anatomía,
proporciones, número de patas y postura propios. Las instrucciones de sprites
completos y dieciséis direcciones que sobreviven como referencia se delimitan en
[SHARED_RESOURCES.md](SHARED_RESOURCES.md#referencias-de-exportación-2d-verificar-vigencia);
no imponen un pipeline de atlas a los nuevos rigs 3D.

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

## Curvas del superviviente

### Autoría automatizada de Aren

`tools/animation/generate_aren.gd` crea bibliotecas independientes de reposo,
caminata y carrera para los 66 huesos nativos. No sobrescribe clips ni fuentes.
Reutiliza las curvas propias autorizadas del catálogo local
`data/animation/authoring/aren_clips.json`, adapta el cuerpo mediante el rig
nativo y hornea una trayectoria original de apoyos con IK de longitudes fijas.
No contiene mocap externo ni concede una licencia de redistribución separada.
Los clips de huesos suministrados posteriormente pueden prepararse con
`retarget_clip.gd`; no se aceptan recursos externos automáticamente en el catálogo.

Desde la raíz, con Godot 4.6.3 o compatible:

```sh
godot --headless --path . --script tools/animation/generate_aren.gd -- \
  --request "Genera una caminata de Aren cautelosa natural zancada media brazos moderados sin deslizamiento de pies" \
  --output res://assets/characters/prototype_3d/generated/aren_custom_v1 \
  --evidence /tmp/aren-custom-validation
```

La salida debe ser un directorio **nuevo**. Por defecto cada petición entrega ambos ciclos
walk/run y reposo, para poder probar sus transiciones; el movimiento mencionado
en la petición expresa la intención, no excluye su compañero de locomoción.
El vocabulario está delimitado: caminar/caminata, correr/carrera, natural,
cautelosa/cauteloso, cansada/cansado, zancada corta/media/larga y brazos moderados.
Las palabras desconocidas fallan con un mensaje; no se inventa una animación.
Las instrucciones abiertas pueden traducirse a parámetros por el agente sin
especificar huesos. `--preset natural|cautious|tired` es la alternativa explícita.

Personalización adicional, por ejemplo:

```sh
godot --headless --path . --script tools/animation/generate_aren.gd -- \
  --preset tired --parameters '{"stride":0.8,"cadence":0.75,"arms":0.5}' \
  --output res://assets/characters/prototype_3d/generated/aren_tired_v2
```

| Parámetro | Rango | Efecto coordinado |
| --- | --- | --- |
| stride | 0,6–1,2 | Zancada, recorrido y velocidad de desplazamiento |
| cadence | 0,65–1,3 | Duración del ciclo y velocidad de desplazamiento |
| arms | 0,3–1,3 | Factor real de amplitud angular de los brazos respecto al torso |
| lean | −0,03–0,10 rad | Inclinación corporal; piernas resueltas desde las caderas finales |
| fatigue | 0–1 | Descenso, flexión articulada de espalda/cuello y menor elevación del pie |
| caution | 0–1 | Apoyo más largo, cuerpo más bajo y transferencia lateral contenida |
| tension | 0–1 | Postura de protección de ambos brazos |
| anticipation | 0–0,08 ciclos | Anticipación de los brazos respecto al paso |
| torso_flow | 0–1 | Reparte flexión, inclinación lateral y contrarrotación en toda la columna al caminar |
| pelvis_sway | 0,2–1 | Fracción de oscilación de pelvis conservada con `torso_flow` activo |

No se simulan lesiones clínicas, anatomías distintas, pendientes ni contactos de
armas en estos clips de manos libres. Los presets son variantes técnicas
provisionales, no sustituyen una aprobación artística del movimiento.
`ArenGenerator.set_animation_style` valida parámetros antes de hornear.
Los perfiles persistentes incluyen jerarquía, ejes, longitudes, roles, cadenas,
commit de partida y hashes de fuentes, curvas, rig y scripts del pipeline.
`data/animation/characters/aren_rig_cache.json` evita reconstruir el índice
cuando coinciden los hashes; se sigue instanciando el rig para reproducirlo.
Si cambian las fuentes, regenerar el perfil y las entregas que se quieran
actualizar; no reutilizar un caché de otro modelo/importador. Las bibliotecas
ya horneadas conservan sus hashes históricos y no se sobrescriben cuando cambia
la herramienta. `rig_profile.json` acompaña cada entrega.

La validación reproduce 241 instantes por clip con AnimationPlayer, comprueba
longitudes locales, transformaciones finitas, cierre de bucle y velocidad de
los tobillos apoyados en espacio de mundo. Muestrea toda la piel y los morfos
de rodilla en nueve instantes. Tolera hasta 6 cm/s de deslizamiento de tobillo
y 4 mm de penetración; no certifica cada vértice en cada instante ni el contacto
de cada punto de la suela. Una corrección vertical constante se hornea cuando
el error de suelo es menor de 8 cm. Los fallos restantes impiden exportar.
Los informes opcionales permanecen fuera de Git; no equivalen a revisión visual.

Cada entrega contiene `clips.res`, `rig_profile.json` y `aren.tscn`. La escena
crea un AnimationTree de reposo/caminar/correr con ciclos de fase normalizada,
reloj común y transición de 5 unidades de mezcla/s. `set_locomotion(metros_s)`
elige la mezcla; `current_speed` expone la velocidad compatible con zancada y
cadencia. El consumidor mueve el actor; la escena no añade física ni colisiones.
La variante natural reproduce aproximadamente 2/4,48 m/s; las variantes
personalizadas tienen velocidades propias. No forzar una variante a una
velocidad distinta sin adaptar parámetros y volver a validar contactos.
La prueba de transiciones
comprueba finitud, inversiones, continuidad angular y llegada a reposo;
no certifica ausencia de deslizamiento durante todas las mezclas dinámicas.
El gameplay conserva su controlador y clips anteriores. El rollback consiste
en retirar la escena generada o usar `use_procedural_rollback()` y devolver su
actor al controlador existente.

Abrir `scenes/prototype_3d/aren_authoring_review.tscn` con F6 para cuatro vistas,
pausa, cámara lenta y transiciones. El primer selector distingue:

- **Original del juego**: ejecuta el actor procedural aprobado, sin AnimationPlayer
  ni biblioteca nueva. Sirve para comparar caminar/correr/reposo; las transiciones
  de este actor se prueban en gameplay, no se simulan en este visor.
- **Generada natural v1**: reproduce `aren_natural_v1/clips.res`. La primera
  versión ya horneaba pistas nativas y nuevos contactos, pero heredaba gran parte
  del torso y brazos del movimiento original. La escena inicial elegía solamente
  esta variante, sin selector entre bibliotecas, por lo que el parecido era grande.
- **Prueba: paso +20 %, brazos +30 %**: reproduce exclusivamente la nueva biblioteca
  `aren_walk_proof_20_30_v1/clips.res`, seleccionada al abrir F6.
- **Generada cautelosa/cansada v1**: conservan los clips anteriores intactos.

Elegir `walk` en el segundo selector. La pausa permite alternar las fuentes en
la misma fase normalizada; la etiqueta muestra los parámetros de la biblioteca
que se está reproduciendo. La prueba usa `stride=1.2`, `arms=1.3`, `lean=4°`
adicionales y la misma cadencia. Aumenta el recorrido por ciclo de 1,925 a
2,31 m y la velocidad de revisión de 2 a 2,4 m/s para conservar el apoyo.
No altera las velocidades del controlador del juego.

#### Caminata con torso coordinado

El visor conserva **Caminata: torso coordinado**, una entrega independiente
en `aren_walk_torso_v2/`. Se compara con **Prueba: paso +20 %, brazos +30 %** en
la misma fase y con los mismos parámetros de zancada, brazos, inclinación media
y cadencia. Las bibliotecas anteriores y los recursos del modelo se conservan.

La capa `aren_torso_flow.gd` mide el ciclo base y conserva su postura media.
Con `torso_flow=1` y `pelvis_sway=0.4`, mantiene el 40 % de la oscilación de pelvis.
La contrarrotación original se reparte progresivamente entre Spine, Spine1 y
Spine2 con participaciones acumuladas 30/65/100 %. Añade flexión sagital contenida
de ±0,25° a dos pulsos por ciclo e inclinación lateral de ±0,45° ligada a los
apoyos, con compensación parcial de cuello/cabeza. Las transformaciones de cada
tramo arrastran sus descendientes; después se resuelven los pies con las
longitudes nativas y los objetivos previos. No modifica la trayectoria ni el
reloj del paso. Esta capa se aplica únicamente a `walk`; reposo y carrera
conservan sus poses anteriores.

La deformación exagerada de cintura no procedía solo del hueso de cadera:
las escenas horneadas anteriores reproducían la piel fuente y omitían la
estabilización de cintura/glúteos ya usada por `NativeSurvivor`. Las entregas
con `torso_flow` activado exportan `use_approved_skin=true`. Su reproducción y
su validación reutilizan `hip_skin.gd` con sus valores aprobados, sin añadir una
corrección de pesos nueva. La copia GPU se comparte y se prepara una vez; las
fuentes, posiciones de reposo, UV, morfos, materiales y binds permanecen intactos.
La escena guarda la referencia al modelo original y prepara esta copia al
cargar. La política de piel pertenece al actor completo; las poses de carrera
y reposo no se vuelven a diseñar. Las escenas antiguas mantienen el flag desactivado.

Repetir con otro nombre:

```sh
godot --headless --path . --script tools/animation/generate_aren.gd -- \
  --preset natural \
  --parameters '{"stride":1.2,"arms":1.3,"lean":0.06981317008,"torso_flow":1,"pelvis_sway":0.4}' \
  --output res://assets/characters/prototype_3d/generated/aren_walk_torso_v3
godot --headless --path . --script tests/aren_torso_coordination.gd
```

La prueba reproduce ambas bibliotecas, mide la piel real de la cintura respecto
a la cadera, la distribución angular de los tres tramos, la contrarrotación y
la conservación de pies/brazos/cadencia. Comprueba además que los clips de
reposo/carrera mantienen sus claves y poses, y que la corrección coincide con sus
fuentes. `tests/aren_authoring.gd` incluye las transiciones de la nueva entrega.

#### Carrera y reposo parametrizados

La opción **Carrera y reposo corregidos** (`aren_run_idle_v3/`) conserva esa entrega. Seleccionar
`run` o `idle`; **Caminata: torso coordinado** permite comparar la entrega anterior.
La biblioteca copia `walk` con todas sus claves, duración y metadatos intactos.
Las bibliotecas originales permanecen disponibles. El controlador jugable no cambia:
esta entrega continúa siendo una prueba independiente.

`aren_run_idle.gd` aplica capas de cuerpo completo sobre las curvas autorizadas.
`run_flow=1` activa el ajuste de carrera; `run_cadence=0.9` reduce su frecuencia
un 10 %. El generador conserva automáticamente la velocidad del clip base
(5,376 m/s en esta biblioteca de prueba), ajusta la distancia del ciclo y mantiene
el tiempo de apoyo original. No cambia la velocidad de juego (4,48 m/s).
`run_arms=0.8` escala la oscilación de brazos respecto a sus parámetros heredados;
`run_body_motion=0.7` modera torso y cabeza, con contrarrotación progresiva de
columna, y `run_posture=0.8` suaviza su inclinación media. `lean=0` elimina la
inclinación adicional de la antigua variante demostrativa. `run_lift=0.8` reduce
la elevación nominal del pie; la recuperación temprana del talón flexiona la
rodilla antes de avanzar y enlaza suavemente con los contactos. La pelvis acompaña el vuelo con una elevación suave,
sin cambiar los objetivos plantados; la recuperación del pie corrige suavemente
su altura cuando el alcance nativo lo requiere, sin estirar las piernas.

`idle_flow=1` sustituye la oscilación antigua por una pose relajada con respiración
de `idle_period=4.5` segundos. `idle_breath=1` reparte flexión acumulada de
±0,05°/±0,16°/±0,38° entre abdomen inferior, superior y pecho, con compensación del
cuello y hombros mínimos. `idle_balance=1` añade equilibrio milimétrico horizontal,
sin oscilación vertical de pelvis ni desplazamiento de los pies. El AnimationTree
conserva la duración real de reposo; solo normaliza las fases de caminar/correr.
Los parámetros `*_flow` por defecto valen cero: no cambian generaciones antiguas.

Regenerar exclusivamente esos dos clips en un directorio nuevo:

```sh
godot --headless --path . --script tools/animation/generate_aren.gd -- \
  --base-scene res://assets/characters/prototype_3d/generated/aren_walk_torso_v2/aren.tscn \
  --replace run,idle \
  --clip-parameters '{"run":{"run_flow":1,"run_cadence":0.9,"run_arms":0.8,"run_body_motion":0.7,"run_posture":0.8,"run_lift":0.8,"lean":0},"idle":{"idle_flow":1,"idle_period":4.5,"idle_breath":1,"idle_balance":1}}' \
  --output res://assets/characters/prototype_3d/generated/aren_run_idle_custom

godot --headless --path . --script tests/aren_run_idle.gd
```

`--base-scene` hereda los parámetros de cada clip y la política de piel. Usar
`--clip-parameters` para sus cambios; no combinarlo con parámetros globales o
peticiones de texto. `--replace` preserva los clips excluidos sin corregir sus
claves; el perfil registra también los hashes de escena y biblioteca de origen.
La cadencia de carrera admite 0,85–1,1, la velocidad explícita 0–8 m/s (cero conserva
la calculada), brazos 0,5–1,1, movimiento corporal 0,4–1, postura/elevación 0,6–1.
El reposo admite periodos de 3,5–6 s, respiración 0,3–1,5 y equilibrio 0–1.
Los límites de alcance y contactos siguen sujetos a validación antes de exportar.

#### Transiciones compartidas de movimiento

La opción **Transiciones con apoyos** (`aren_transitions_v1/aren.tscn`) conserva la entrega anterior.
Elegir **Normal**, **Cauteloso** o **Cansado**, y una de las seis transiciones del
segundo selector. **Encadenadas** recorre reposo→caminar→correr→caminar→reposo,
seguido de reposo→correr→reposo, sin reiniciar la fase ni los contactos entre
tramos. **Reiniciar** repite la prueba seleccionada; Pausa y el deslizador regulan
la reproducción. Las cuatro cámaras muestran frente, lateral, espalda y tres
cuartos. Los ciclos aprobados siguen disponibles en las opciones walk/run/idle
y en sus entregas anteriores.

En la escena de revisión, las fuentes con `advance_transition` se evalúan una
sola vez, en `actors[0]`. `aren_review_pose.gd` copia su pose local de esqueleto
y sus pesos de blend shapes a las otras tres vistas, que conservan esqueletos
e instancias independientes. Los enlaces y buffers se reutilizan hasta cambiar
de fuente. Las cuatro cámaras siguen mostrando la misma pose y desplazamiento;
solo el primer actor mantiene el reloj y el estado de la simulación. Se conservan
los subpasos de hasta 1/120 s, la IK, los apoyos, los clips y los ajustes gráficos.
Esta optimización también se aplica a los ciclos de esas fuentes; las fuentes
anteriores mantienen su reproducción original. Verificación de equivalencia:
`godot --headless --path . --script tests/aren_review_playback.gd`.

`generate_aren_transitions.gd` genera seis pequeños clips de control normalizados
(`controls.res`) y un perfil con referencias y hashes de las bibliotecas
existentes. No duplica claves de huesos ni modifica ciclos, rig o piel fuente.
Normal referencia `aren_run_idle_v3`; cauteloso y cansado reutilizan
`aren_cautious_v1` y `aren_tired_v1`. Sus parámetros de postura, brazos y velocidad
se conservan. Los seis controles comparten interpolación quintica y separan
anticipación del cambio de velocidad. Duraciones normales:

| Transición | Duración | Anticipación, fracción del tramo |
| --- | --- | --- |
| idle_to_walk | 1,15 s | 0,17 |
| idle_to_run | 1,85 s | 0,12 |
| walk_to_run | 1,10 s | 0,08 |
| run_to_walk | 1,15 s | 0,05 |
| walk_to_idle | 1,10 s | 0,06 |
| run_to_idle | 1,75 s | 0,05 |

Cauteloso multiplica tiempos por 1,25 y cansado por 1,4. La transferencia lateral
anticipatoria es de 12/9/10 mm. Una carga compartida de hasta 28 mm prepara la
flexión de piernas durante el cambio, conserva un margen de 0,8 s al completarse
y se libera suavemente. La aceleración inclina progresivamente pelvis y los tres
tramos de columna, con compensación parcial del cuello; la frenada invierte esa
inclinación. Resortes críticamente amortiguados conservan la continuidad corporal
al interrumpir un tramo. El siguiente tramo parte de la velocidad y aceleración
actuales; no reinicia la fase del paso.

`aren_cycle_sampler.gd` lee los clips aprobados. `aren_transition_actor.gd` mezcla
sus poses locales y conserva un reloj común para caminar/correr, calculado a
partir de velocidad y distancia del ciclo; reposo conserva su reloj respiratorio.
Los objetivos de los pies se mezclan en espacio global para conservar las
trayectorias y la orientación de suelas de los clips fuente. La traslación se
integra con ese mismo reloj. Los apoyos se bloquean en espacio
de desplazamiento y las piernas usan la IK nativa de longitudes fijas. Al soltar
el pie, el error anterior de apoyo se desvanece durante la recuperación; la
compresión de pelvis se anticipa al alcance y se libera gradualmente. No se
retoca cada hueso a mano ni se guarda un clip nuevo por cada combinación de estado.

API de la escena generada: `set_style("normal"|"cautious"|"tired")`,
`reset_motion("idle"|"walk"|"run", fase)` para iniciar una prueba y
`request_transition(nombre)` para solicitar o encadenar cualquiera de los seis
tramos. `advance_transition(delta)` evalúa con pasos internos de hasta 1/120 s;
`distance_m` es la traslación frontal acumulada que debe aplicar el anfitrión.
`set_locomotion(velocidad)` selecciona uno de los tres estados nominales. Esta
entrega es una prueba de avance recto sobre plano; no integra todavía el
controlador jugable, giros ni terreno irregular. Los apoyos durante mezclas se
validan para estas seis transiciones y estos tres estados.

Regenerar sin sobrescribir recursos:

```sh
godot --headless --path . --script tools/animation/generate_aren_transitions.gd -- \
  --output res://assets/characters/prototype_3d/generated/aren_transitions_custom
godot --headless --path . --script tests/aren_transitions.gd
```

#### Carrera habitual e impulso inicial coordinados

La entrega **Carrera e impulso: postura ajustada** (`aren_run_launch_v1/`)
conserva el ajuste anterior de carrera e impulso. El visor abre ahora la entrega
de coordinación descrita a continuación y permite compararla con esta versión
mediante **Ver antes / Ver después**. Para comparar el impulso, seleccionar
**Reposo → correr** y usar el mismo botón. Puede pausarse
la comparación; al alternar, el arranque se reproduce hasta el mismo instante,
sin cambiar la trayectoria de velocidad. **Reiniciar** repite el arranque.
El selector de estado conserva Normal/Cauteloso/Cansado en ambas versiones.

Los ángulos siguientes son incrementos sobre los ciclos aprobados de cada estado,
no inclinaciones absolutas medidas desde la vertical:

| Estado | Carrera habitual, pecho | Impulso, extra máximo sobre la nueva postura | Ventana de recuperación |
| --- | --- | --- | --- |
| Normal | +3° | +7° | 2,5 pasos |
| Cauteloso | +2° | +4° | 3 pasos |
| Cansado | +1,5° | +3° | 3 pasos |

`aren_run_posture.gd` aplica una capa constante durante todo el ciclo. La pelvis
recibe el 35 % del giro y la inclinación acumulada alcanza 50/75/100 % en abdomen
inferior/superior/pecho. Hombros y brazos acompañan al pecho, conservando exactamente
su gesto relativo; el cuello compensa la mitad del giro añadido para estabilizar
la mirada. Las cadenas completas de piernas se expresan en el nuevo marco de
pelvis conservando sus transformaciones globales, apoyos y morfos originales.
No cambia la cadencia, amplitud ni trayectoria de las extremidades, ni el rig,
los binds, longitudes o escalas nativas. La capa solo afecta al muestreo de `run`:
walk/idle y los recursos originales permanecen intactos.

`aren_run_launch_actor.gd` reutiliza el evaluador de transiciones y sus controles.
Solo al arrancar a correr desde reposo sustituye la inclinación de aceleración
anterior por el impulso parametrizado. La anticipación carga la postura antes de
avanzar. Su objetivo absoluto parte de la inclinación media de la nueva carrera
del estado más el extra de impulso; se filtra ese objetivo absoluto para que la
mezcla inicial con reposo no diluya el impulso ni produzca sobrepasos.
El primer aterrizaje real tras ese impulso fija el origen de la
recuperación. Desde ahí se combina el avance de fase (dos apoyos por ciclo) con
la fracción de velocidad realmente ganada hacia la velocidad de carrera del
estado. La recuperación quintica progresa con el mayor de esos avances y nunca
retrocede. El reloj de transición por sí solo no reduce la inclinación.

La inclinación adicional se reparte con la capa corporal del evaluador existente:
45 % pelvis y 55 % distribuido en columna, con compensación parcial del cuello.
La respuesta del resorte aumenta suavemente de 12 a 24 con el avance de la
recuperación para evitar un retraso de postura al tercer apoyo.
El resorte corporal mantiene la continuidad al pasar a carrera estable o
interrumpir el arranque. La velocidad, aceleración, distancia y reloj de pasos
siguen el plan aprobado; los contactos e IK existentes coordinan el impulso con
piernas y transferencia de peso. La nueva postura habitual ya forma parte de la
pose destino, sin un segundo cambio de postura al terminar el arranque.

Criterios de comparación en frente, lateral, espalda y tres cuartos:

- Igual fase, estado y velocidad, tanto en `run` como en el instante del arranque.
- Incrementos efectivos de pecho y pelvis acordes a la tabla, no flexión aislada
  de cintura; cabeza y hombros acompañan sin oscilaciones nuevas.
- Trayectorias de piernas/pies y gesto relativo de brazos conservados en carrera
  habitual (tolerancia de 1 mm en pies); reloj, velocidad y ciclos sin alteración.
- Impulso visible, recuperación entre los siguientes 2–3 pasos y residual inferior
  a 0,25° al tercer paso; avance de fase y velocidad controlan la recuperación.
- Continuidad de pelvis/columna, apoyos bloqueados durante las transiciones,
  bucles continuos y piel dentro de la tolerancia de suelo de 4 mm.

La entrega solo guarda escena y perfil; referencia las bibliotecas aprobadas y los
seis controles existentes sin copiarlos. Regenerar con un nombre nuevo:

```sh
godot --headless --path . --script tools/animation/generate_aren_run_posture.gd -- \
  --output res://assets/characters/prototype_3d/generated/aren_run_launch_custom
godot --headless --path . --script tests/aren_run_posture.gd
```

El actor añade `seek_cycle(clip, segundos)` para comparar los ciclos muestreados.
La API de solicitud y encadenado de transiciones sigue siendo la anterior. Las
entregas previas y el controlador jugable mantienen su comportamiento.

#### Coordinación contralateral, incremento del impulso y plano de rodillas

La entrega **Coordinación: brazos y rodillas** (`aren_coordination_v1/`) conserva
las correcciones de brazos, impulso y rodillas. Sigue seleccionable como fuente
y como referencia de comparación para el ajuste de torso siguiente. Los tres estados y las seis transiciones,
incluido **Encadenadas**, están disponibles. **Pausa** permite comparar una pose;
**Reiniciar** repite una transición. Las fuentes anteriores siguen seleccionables.

`aren_coordination_sampler.gd` desplaza las cadenas completas de ambos brazos,
desde hombro hasta dedos, medio ciclo de caminata (`walk_arm_phase=0.5`). Conserva
sus gestos y amplitudes aprobados: el brazo derecho avanza con la pierna izquierda
y viceversa en Normal/Cauteloso/Cansado. No modifica el torso, piernas, apoyos ni
morfos de los ciclos; reposo y carrera se muestrean igual que antes. Las transiciones
mezclan estos mismos ciclos, sin bibliotecas duplicadas.

`aren_coordination_actor.gd` añade `launch_increment_deg=1.5` a la pose efectiva del
impulso anterior en los tres estados. La carga quintica alcanza exactamente +1,5°
en el pecho antes de la recuperación; no se aumenta únicamente un objetivo que un
filtro pudiera atenuar. La misma recuperación por apoyos y velocidad real reduce
el incremento durante los siguientes 2,5/3/3 pasos. Al interrumpirlo, un resorte
críticamente amortiguado libera el incremento. La carrera estable conserva los
incrementos +3°/+2°/+1,5° de la tabla anterior. La capa corporal existente reparte
el nuevo giro entre pelvis (35 %) y columna (50/75/100 % acumulado hasta pecho),
con hombros solidarios y compensación de cuello del 50 %. Las cadenas de piernas
conservan sus transformaciones globales.

El rig usa +Z como avance en el marco de autoría. La flexión correcta aproxima
el talón a los glúteos; elevar el muslo es un movimiento distinto. Los ciclos
fuente mantienen su flexión y sus límites originales. Bajo carga, el antiguo polo
IK tomado del vector de muslo podía invertir el plano de la rodilla.
`aren_knee_plane.gd` conserva el componente radial obtenido por FK de los ciclos
mezclados como referencia anatómica. Solo corrige la desviación del plano fuera
de un cono suave: empieza a 15° y alcanza la referencia a 45°, reduciendo esos
umbrales cuando la referencia está próxima al límite de inversión. La corrección
y su liberación limitan el giro relativo del plano a 180°/s, evitando saltos al
cruzar la singularidad del polo antiguo; los movimientos válidos se siguen
directamente. Conserva el ángulo de flexión, las longitudes, el pie y su orientación; no introduce una
flexión manual ni cambia los ejes de reposo, binds o recursos originales.

Criterios de comparación: coordinación opuesta de brazo/pierna en cada estado;
+1,5° efectivo durante el impulso y ningún incremento en carrera estable; recuperación
al tercer apoyo; rodillas en el plano anatómico sin alterar una flexión válida;
continuidad de pelvis, columna y articulaciones al acelerar, frenar e interrumpir;
contactos y velocidad de desplazamiento conservados. Revisar frente, lateral,
espalda y tres cuartos con el selector de estado y las transiciones encadenadas.

La entrega guarda únicamente escena y perfil, referenciando las bibliotecas y los
seis controles existentes. Generar siempre en un directorio nuevo:

```sh
godot --headless --path . --script tools/animation/generate_aren_coordination.gd -- \
  --output res://assets/characters/prototype_3d/generated/aren_coordination_custom
godot --headless --path . --script tests/aren_coordination.gd
```

#### Caminata con movimiento del torso superior

La entrega **Caminata: torso superior coordinado** (`aren_walk_upper_v1/`)
conserva el ajuste de caminata y sigue seleccionable en el visor. La entrega
posterior de carrera hereda estos mismos ciclos y parámetros de torso. Se mantienen disponibles los seis
cambios de velocidad y **Encadenadas**, además de **Pausa** y **Reiniciar**.

`aren_walk_upper_sampler.gd` reutiliza el muestreo contralateral y añade una capa
parametrizada solo a `walk`. `aren_walk_upper_body.gd` utiliza las herramientas
existentes de transformación de ramas y referencia media del torso. Conserva la
postura media de cada estado, incluida la flexión propia de Cansado, y reparte
el movimiento acumulado entre lumbar, abdomen superior y tórax con participaciones
28/63/100 %. La pelvis conserva el 90 % de su oscilación angular previa y su
traslación completa. No añade un nuevo balanceo de cadera.

Amplitudes de pecho respecto a su postura media, por lado (±):

| Estado | Flexión sagital | Contrarrotación | Inclinación lateral |
| --- | --- | --- | --- |
| Normal | 0,85° | 4,20° | 1,50° |
| Cauteloso | 0,60° | 3,20° | 1,00° |
| Cansado | 0,75° | 3,60° | 1,30° |

La contrarrotación y el balanceo lateral usan la fase existente de los pasos;
la flexión sagital tiene dos pulsos por ciclo. El giro del tórax se opone al de
la pelvis, acompañando al brazo contralateral. Los hombros siguen al tórax con
sus gestos locales originales, sin duplicar ni incrementar el balanceo de brazos.
Cuello y cabeza conservan el 45 % y el 20 % del movimiento angular del pecho,
respectivamente, estabilizando la mirada sin desconectar la cabeza del cuerpo.

La capa conserva las transformaciones globales de las cadenas completas de
piernas y las curvas de morfos/contactos del ciclo. El evaluador existente mezcla
los ciclos ajustados antes de resolver los apoyos y el IK anatómico. La velocidad,
cadencia, zancada, planes de aceleración/frenada e impulso de carrera siguen los
parámetros previos. Los muestreos de carrera y reposo permanecen iguales. No se
modifican mallas, pesos, rigs, binds, materiales ni bibliotecas aprobadas.

El perfil guarda `walk_torso` por estado: `pitch_deg`, `yaw_deg`, `roll_deg`,
`spine_shares`, `pelvis_retention`, `neck_follow` y `head_follow`. La escena y el
perfil referencian la entrega anterior y sus recursos compartidos. Regenerar con
un nombre nuevo:

```sh
godot --headless --path . --script tools/animation/generate_aren_walk_upper.gd -- \
  --output res://assets/characters/prototype_3d/generated/aren_walk_upper_custom
godot --headless --path . --script tests/aren_walk_upper_body.gd
```

Comparar en frente, lateral, espalda y tres cuartos: movimiento progresivo en los
tres tramos de columna, contrarrotación sin giro aislado de cintura, hombros
conectados, cabeza más estable que el pecho y apoyos conservados al encadenar o
interrumpir transiciones. La comprobación automatizada evalúa también la piel
deformada del torso superior para detectar ajustes sin efecto visible.

#### Carrera con apertura contenida y recuperación temprana

La entrega **Carrera: zancada contenida** (`aren_short_run_v1/`) conserva el ajuste
de apertura y recuperación de piernas. Sigue seleccionable y sirve como referencia
para la entrega posterior de caminata y preparación de brazos. En transiciones
conserva el tiempo real, la velocidad y la distancia recorrida; las fases pueden
diferir porque la cadencia cambia. Los tres estados, las seis transiciones y
**Encadenadas** siguen disponibles.

`generate_aren_short_run.gd` mide la separación longitudinal máxima de los pies
de cada ciclo fuente y calibra los objetivos de vuelo hasta obtener el 80 % de
esa apertura. Es una reducción de la separación observable en vista lateral,
distinta de la distancia recorrida por ciclo. `duration_scale=0.9` acorta el ciclo
un 10 % y aumenta la cadencia un 11,11 %. La distancia de desplazamiento por ciclo
se reduce también un 10 % para conservar exactamente la velocidad del estado.
La fracción de apoyo aumenta inversamente a la duración: el tiempo físico de
contacto y su recorrido longitudinal permanecen iguales.

`aren_short_run.gd` reutiliza el planteamiento de objetivos de pie del generador,
el límite de alcance y el solver IK nativo. Durante el vuelo, calibra los tramos
de liberación y preparación del aterrizaje (proporción 1:1,4). Las curvas quinticas
conservan velocidad y aceleración en sus uniones con el apoyo; invierten antes
la trayectoria de la pierna trasera y reducen la extensión de la delantera.
La recuperación adicional del talón se concentra en el primer tercio del vuelo
mediante una envolvente suave, nula en los contactos:

| Estado | Recuperación del talón, parámetro |
| --- | --- |
| Normal | 0,18 m |
| Cauteloso | 0,14 m |
| Cansado | 0,13 m |

El IK articula muslo y rodilla para alcanzar esos objetivos, conservando longitudes,
orientación de pie y morfos correctivos. La elevación de vuelo de pelvis se ajusta
a la nueva fracción de apoyo; pelvis, torso, cabeza y brazos comparten el nuevo
reloj sin cambiar sus gestos angulares ni la inclinación de carrera estable.
Se conserva el evaluador de aceleración/frenada, bloqueo de contactos, corrección
del plano de rodilla y recuperación del impulso por apoyos y velocidad real.

La entrega guarda tres recursos `run_*.res` con las claves fuente temporizadas y
metadatos de ciclo coherentes. `aren_short_run_actor.gd` los combina con referencias
a los mismos recursos de caminar/reposo; `aren_short_run_sampler.gd` aplica los
objetivos parametrizados al evaluar la pose. Para evaluar la entrega completa,
usar el actor (`seek_cycle`) o la escena de revisión. El perfil registra los
parámetros y hashes de fuentes; no se duplican las bibliotecas de caminar/reposo
ni se modifican los modelos, binds, materiales o recursos previos.

Regenerar con un directorio nuevo:

```sh
godot --headless --path . --script tools/animation/generate_aren_short_run.gd -- \
  --output res://assets/characters/prototype_3d/generated/aren_short_run_custom
godot --headless --path . --script tests/aren_short_run.gd
```

Comparar el ciclo lateral completo: apertura máxima, flexión anatómica, recuperación
del talón y preparación del apoyo; después probar **Reposo → correr**, carrera
estable y **Correr → reposo**, además de cambios hacia/desde caminar e interrupciones.
La velocidad y los contactos deben conservarse, sin saltos de pelvis/columna ni
alteraciones de las caminatas y el reposo aprobados.

#### Flexión lumbar moderada y preparación asimétrica de brazos

El visor abre **Caminata y arranque ajustados** (`aren_walk_launch_v1/`) con `walk`
seleccionado. **Ver antes / Ver después** alterna con `aren_short_run_v1` en la
misma fase o, al revisar transiciones, en el mismo instante, estado y velocidad.
Usar **Reposo → correr** para observar la preparación antes del primer paso y
**Caminar → correr** para comprobar el enlace desde el balanceo existente.

La entrega reutiliza el evaluador de torso y reduce `walk_torso.pitch_deg` al
35 % del valor anterior en los tres estados: ±0,2975° Normal, ±0,21° Cauteloso y
±0,2625° Cansado en el pecho. Conserva las posturas medias, la contrarrotación,
las inclinaciones laterales y las participaciones acumuladas 28/63/100 % de la
columna. Reduce la flexión/extensión lumbar y abdominal sin añadir escalados ni
traslaciones a la columna. Cada muestra se reconstruye desde la pose fuente;
las participaciones son orientaciones acumuladas objetivo y no giros que deban
sumarse de nuevo a la muestra anterior. Se conservan los pies y los ciclos de
carrera y reposo.

`aren_walk_launch_actor.gd` añade una preparación de brazos sobre la pose fresca
del evaluador existente. La carga anticipatoria del torso activa primero el
brazo que acompaña a la siguiente pierna contralateral; el segundo empieza más
tarde y con menor amplitud. Los umbrales de carga son 0,02 y 0,65, respectivamente.
El brazo que inicia la preparación adelanta el húmero hasta 8° y añade hasta 32°
de flexión de codo; el otro usa 3° y 18°. Las ganancias son 1/0,85/0,70 para
Normal/Cauteloso/Cansado. La flexión total queda limitada a 115° y sigue el plano
anatómico del codo muestreado. `aren_arm_preparation.gd` utiliza las herramientas
compartidas de transformación de ramas; no cambia longitudes, escalas o rig.

La preparación empieza durante la inclinación, antes de avanzar la fase del
primer paso. Se retira con interpolación quintica según dos pasos de fase y la
velocidad realmente ganada, enlazando con el balanceo contralateral de los ciclos.
En **Caminar → correr** usa una intensidad del 35 %, manteniendo el gesto que ya
está en marcha. Los ángulos efectivos de cada brazo se filtran con resortes
críticamente amortiguados de respuesta 20; conservan continuidad al interrumpir,
retomar o cambiar el brazo que inicia el movimiento. La pose se reconstruye antes
de aplicar la preparación, evitando acumulación entre fotogramas. La preparación
no permanece en la carrera estable ni modifica los contactos o planes de velocidad.

El perfil referencia todos los ciclos anteriores; solo se guardan escena y
parámetros nuevos. Generar en un directorio independiente:

```sh
godot --headless --path . --script tools/animation/generate_aren_walk_launch.gd -- \
  --output res://assets/characters/prototype_3d/generated/aren_walk_launch_custom
godot --headless --path . --script tests/aren_walk_launch.gd
```

Comparar el bucle de caminata desde lateral, frente, espalda y tres cuartos:
flexión contenida sin efecto de compresión/estiramiento, torso conectado y pies
conservados. En el arranque, comprobar inicio escalonado de los brazos antes del
primer paso, amplitudes distintas, recuperación hacia la carrera y continuidad
en aceleraciones interrumpidas y retomadas.

El factor de brazos actual mide primero el ángulo de cada hombro respecto al
torso durante el ciclo base. Escala su oscilación respecto al centro del rango
y transforma la cadena completa. Corrige la fórmula inicial, que añadía un giro
cosenoidal aproximado y no garantizaba el porcentaje pedido. Las bibliotecas v1
anteriores mantienen la interpretación con la que fueron horneadas.

Para repetir la variante con otro nombre, sin editar huesos:

```sh
godot --headless --path . --script tools/animation/generate_aren.gd -- \
  --preset natural --parameters '{"stride":1.2,"arms":1.3,"lean":0.06981317008}' \
  --output res://assets/characters/prototype_3d/generated/aren_walk_proof_v2
godot --headless --path . --script tests/aren_authoring_comparison.gd
```

La comparación mide posiciones y ángulos del Skeleton3D que usa el visor,
no solo valores del perfil; verifica los porcentajes, la inclinación, la ruta de
la biblioteca y el cambio efectivo de pose al alternar en pausa.

Implementado: selección de curvas propias autorizadas, adaptación al rig nativo,
horneado de poses y correctivos, parámetros corporales, IK de piernas sobre plano,
compensación de pelvis, validación de contactos/bucle, perfiles con hashes,
reproducción independiente, AnimationTree de prueba, transiciones con contactos y render desde cuatro ángulos.
El texto de alto nivel usa un vocabulario acotado; los porcentajes se pasan por
JSON. No hay un generador general de movimientos a partir de lenguaje libre.
El retargeting de clips de huesos es una herramienta separada: esta prueba usa
las curvas del proyecto, no un clip externo retargeteado automáticamente.
Pendientes: selección automática de otros clips/rigs, fallback cuando faltan las
curvas del proyecto, lesiones y anatomías distintas, IK de terreno, validación de
contactos durante mezclas dinámicas fuera de las transiciones documentadas e integración de estas bibliotecas en el
controlador jugable. La revisión artística de naturalidad sigue siendo humana.

Para otro recurso, ejecutar:

```sh
godot --path . scenes/prototype_3d/aren_authoring_review.tscn -- \
  res://assets/characters/prototype_3d/generated/aren_tired_v1/aren.tscn
godot --path . --script tools/animation/render_aren.gd -- \
  res://assets/characters/prototype_3d/generated/aren_tired_v1/aren.tscn \
  /tmp/aren-tired-render walk
godot --headless --path . --script tests/aren_authoring.gd
```

El render necesita un servidor gráfico OpenGL; headless basta para hornear y
validar pero no para las imágenes. La exportación produce 48 fotogramas con
cuatro ángulos y cuadrícula fija mientras el actor recorre su distancia real.
La revisión visual sigue siendo necesaria para silueta, naturalidad y oclusión.
Los recursos originales del modelo, binds, rest pose y escala permanecen intactos.

`assets/characters/prototype_3d/motion/controls.res` contiene curvas nativas
compartidas para marcha, carrera, salto, ocho deslizamientos, caída frontal y
los golpes de hacha, pico y espada. Se interpolan controles de cuerpo, manos,
apoyos y esfuerzo; las extremidades se resuelven después con las longitudes
del rig. La mira sigue resolviendo el contacto real y los agarres del objeto.
No se interpolan escalas de brazos, piernas, cabeza ni cuello.

La reducción de claves usa límites de error de 0,018 unidades para posiciones
y 0,0004 para ángulos y pesos de mezcla. Conserva las fases de contacto, impacto,
entrada y salida, además de los extremos del ciclo. Las pistas constantes
usan una sola clave. Los datos de autoría no se evalúan durante el juego.
El reloj base usa el desplazamiento horizontal real en coordenadas del modelo.
Los cambios ordinarios de dirección se suavizan en el desplazamiento físico:
respuesta angular de 15/s y velocidad máxima de 540°/s. Los pies del jugador
usan la dirección real recorrida, sin añadir otro filtro visual después.
La frenada normal dura 0,12 s; el arranque de marcha conserva 0,24 s.
Una inversión de 180° mientras hay movimiento activa una frenada de 0,4 s en
la dirección de salida, seguida de 0,1 s con velocidad horizontal exactamente
cero. La detección admite una tolerancia angular de 0,1°. En carrera, los dos
tiempos se multiplican por 2,24: 0,896 s de frenada y 0,224 s detenido; durante
la aceleración se interpola este factor con el peso actual de sprint.
El reinicio conserva el arranque físico de marcha de 0,24 s y el de carrera
de 0,16 s más 1 s de aceleración. La dirección solicitada se actualiza durante
frenada y pausa; soltar las teclas evita el reinicio. La inversión especial
solo se aplica en el suelo. Los cambios de 90°, con la misma tolerancia de
0,1°, frenan en la dirección de salida durante 0,2 s andando o 0,448 s en
carrera máxima y arrancan en la dirección solicitada sin pausa adicional.
La duración interpola el factor de sprint vigente y la dirección pendiente
puede actualizarse o soltarse durante la frenada. Los demás ángulos conservan
el giro suavizado ordinario. Saltos y deslizamientos conservan su control propio.
El guardado conserva fase, tiempo restante, velocidad y dirección pendiente;
las partidas anteriores siguen siendo válidas.

La marcha erguida usa semizancada de apoyo de 8,8 unidades, contacto frontal
del 25 % y elevación máxima de 2,8 unidades, definidos en `gait_parameters.gd`.
La distancia efectiva por ciclo es `2 * 8.8 * (1.75 / 64) / 0.25`, 1,925 m:
a 2 m/s dura 0,9625 segundos, unos 2,08 pasos por segundo. El retorno de la
pierna ocupa el 75 % del ciclo frontal, con aceleración continua y aterrizaje
suave. El reloj conserva esta duración en diagonales delanteras y laterales;
la amplitud y el tiempo de contacto se ajustan juntos a cada dirección para
mantener la velocidad del pie apoyado respecto al terreno. La altura de apoyo
ronda 29,8 unidades y el objetivo nativo se centra bajo su propia cadera,
con entrada y salida suavizadas. La marcha hacia delante y de lado es de
2 m/s. Hacia atrás y en ambas
diagonales traseras es el 30 %, 0,6 m/s, con frenada progresiva; la marcha
agachada conserva el mismo factor direccional respecto a su avance frontal.
La carrera hacia delante y de lado alcanza 4,48 m/s; hacia atrás y en ambas
diagonales traseras alcanza 1,344 m/s. Los límites de marcha y carrera cambian
con una transición de velocidad desde el valor actual.
La cadencia trasera es el 80 % de su equivalente frontal, tanto andando como
corriendo. La zancada trasera se multiplica por `0.30 / 0.80 = 0.375`, junto
con su elevación y giro de tobillo; la duración relativa del apoyo se mantiene.
El ciclo completo de marcha trasera recorre 0,721875 m y dura 1,203125 s a
0,6 m/s. La carrera trasera recorre aproximadamente 1,1497 m por ciclo. El reloj
sigue la distancia real con esta zancada reducida, sin aplicar otra reducción
a la amplitud por la menor velocidad. El factor entra suavemente al pasar del
desplazamiento lateral al trasero.
Las cuatro diagonales de marcha y carrera usan 35° respecto al eje frontal o
trasero: la entrada horizontal combina `sin(35°)` lateral y `cos(35°)` longitudinal,
con módulo normalizado. Los carriles de pies y los planos de rodillas comparten
ese ángulo; la pelvis gira 33° y la espalda conserva su articulación relativa. Los
controles de deslizamiento conservan sus trayectorias propias de 45°.
La marcha agachada conserva su curva propia `crouch_walk`, su distancia base
`1.56 * 0.68 * lerp(1, 0.44, abs(direccion.x))` y sus apoyos del 60–45 %.
El reloj mezcla ambas distancias durante la transición de postura y conserva
`GAIT_PLAYBACK_RATE = 0.90`. La escala de autoría es
`GAIT_STRIDE_LENGTH = 1.10`. La carrera usa los parámetros compartidos de
`gait_parameters.gd`: semizancada de apoyo de 12,33375 unidades, contacto frontal
del 22 % del ciclo y elevación máxima de 5,6 unidades. El ciclo recorre
`2 * 12.33375 * (1.75 / 64) / 0.22`, aproximadamente 3,066 m. Su reloj sigue la
distancia real con `RUN_PLAYBACK_RATE = 1.0`; la transición mezcla el reloj
de marcha y el de carrera. A 4,48 m/s dura aproximadamente 0,6844 s, unos
2,92 pasos por segundo. El recorrido y la duración del ciclo se calculan
desde la misma semizancada: la frecuencia de las piernas es proporcional
al inverso de la distancia por ciclo y la velocidad física se mantiene.
Torso, brazos, hombros, cabeza y cadera comparten esa fase de recorrido,
incluidos arranque, desaceleración y mezcla entre marcha y carrera. El ritmo
más lento conserva los giros y la oscilación contenida de pelvis existentes;
no añade rebote ni amplía la cadera para compensar el recorrido de los pies.
Los brazos conservan el último peso explícito de sprint al entrar en una pose
de marcha o reposo que no lo incluya; la mezcla de salida se desvanece desde
ese valor, sin recuperar de golpe una postura de carrera al terminar de frenar.
La carrera adapta la duración del contacto al recorrido lateral, conservando
la velocidad relativa del apoyo. La recuperación horizontal usa aceleración
continua, con liberación del pie, avance y entrada al siguiente apoyo. El
retorno vertical es C2 y las claves cercanas al contacto se conservan al reducir
las curvas. La altura de apoyo de carrera se calcula con ambos extremos
del contacto y un margen de 0,25 unidades, con límite superior de 29,8.
En la carrera frontal ronda 28 unidades para admitir la zancada completa;
el ajuste depende de la dirección y permanece constante a lo largo del ciclo,
sin añadir rebote a la pelvis. El rig nativo centra el apoyo bajo sus propias caderas y
mantiene un margen de suela de 0,30 unidades. El apoyo se ajusta a la velocidad
física definida para cada dirección.
`RUN_SWING_KEYS` conserva dos claves intermedias por pierna tras reducir
las curvas: entre despegue y máxima elevación de rodilla, y entre esa elevación
y el siguiente apoyo. Sus fases frontales nominales son 0,4533 y 0,845 para
`foot_l`, desplazadas medio ciclo para `foot_r`; la altura máxima de rodilla
ronda la fase 0,688. El remapeo del apoyo adapta estos puntos a cada dirección.
Las calles de apoyo dejan espacio para la trayectoria completa antes de
resolver IK, sin recortar su
mitad interior. El pie levantado regresa en el sentido real de desplazamiento.
El paso lateral usa `LATERAL_STEP_SCALE = 0.45` y
`LATERAL_LIFT_SCALE = 0.40`: reduce apertura y elevación de la pierna para
recoger el paso bajo la cadera y evitar tirones del pantalón. Entra suavemente
al pasar de diagonales de 35° al desplazamiento lateral puro, sin cambiar
la cadencia global ni la velocidad física.
La altura de apoyo calcula el alcance de ambos extremos del paso completo.
En marcha y carrera erguidas, `GAIT_LOWERING = 0.15` conserva solo el 15 % del
descenso total anterior, incluido el rebote y la compensación de alcance.
Las rodillas se resuelven con longitudes constantes y los objetivos de pie
limitan suavemente el alcance horizontal a la altura de la suela, evitando
alargar huesos o levantar los apoyos para alcanzar una zancada imposible.
La marcha agachada mantiene su altura propia. Los golpes erguidos comparten
esta corrección de altura y el límite horizontal de alcance de los pies antes
de resolver el contacto del arma. Los golpes agachados conservan su postura;
los objetivos bajos pueden necesitar una bajada adicional para alcanzarlos.
Durante los golpes cuerpo a cuerpo la velocidad se multiplica por 0,50, además
de desactivar el sprint. La entrada tarda 0,08 s y la recuperación ocupa los
últimos 0,12 s del gesto, con interpolación suave; no cambia el tiempo del golpe
ni la velocidad normal de marcha/carrera. El arco conserva su comportamiento.
El balanceo y giro base usan `GAIT_HIP_MOTION = 0.45`; después de resolver
la postura completa, `GAIT_HIP_REDUCTION = 0.30` conserva el 30 % del
desplazamiento final de pelvis alrededor de su altura de apoyo habitual
y de sus giros respecto a la inclinación
media del torso. Se aplica también a la oscilación vertical y de inclinación
de carrera, sin alterar el reloj de las piernas.
Al caminar, la pelvis mantiene un giro leve opuesto al de la espalda visible;
el giro de cadera se resuelve respecto al personaje para conservar el
contragiro de 0,025 rad de autoría, amortiguado al 13,5 % (0,45 × 0,30).
La carrera usa el doble de este giro y los balanceos laterales compartidos.
El brazo libre opuesto a la pierna que recupera inicia un pequeño gesto del codo hacia atrás, con
0,10 rad de amplitud; antebrazo y muñeca lo siguen 0,025 s después al ritmo
nominal de cada dirección. La muñeca añade solo 0,025 rad de giro. Las manos
ocupadas mantienen sus agarres y la carrera mantiene su gesto propio.
La piel visible de la pelvis conserva el 40 % de su deformación anterior
respecto al hueso de cadera. `hip_skin.gd` mezcla el 60 % restante hacia ese
hueso en la cintura (34,5–36) y la zona posterior de glúteos (31,5–36).
La cintura entra suavemente entre 32,7–34,5; el apoyo posterior entre
27,5–31,5 y se desvanece hacia el frente entre z=1,2–3,4. Ambos terminan
suavemente entre alturas 36–40. Usa transiciones C2. El cuádriceps frontal
por debajo de la articulación de cadera conserva sus pesos originales de muslo;
no se fija a la pelvis ni recibe una segunda flexión en mitad del músculo.
La malla GPU se prepara una sola vez y se comparte: no se recalculan vértices
durante el juego. Conserva los vértices de reposo, UV, materiales, morfos de
rodilla y ligaduras originales de las fuentes; solo la copia de pesos de la
piel visible recibe esta corrección. Cabeza, cuello y zonas exteriores no cambian.
La ligadura nativa conserva ejes y longitudes: las piernas usan giro desde el
reposo sin copiar la torsión axial del rig de contactos al pantalón.
El brazo libre de espada usa `SWORD_BALANCE_MOTION = 0.80`, proporciones nativas
y dedos relajados; su objetivo es de equilibrio, sin fijarlo a un contacto
de herramienta ni forzar la clavícula para alcanzarlo.
La caminata separa las rodillas un 10 % mediante el plano de flexión de cada
pierna, con `WALK_KNEE_SPREAD = 1.10`. Conserva pies, cadera y longitudes de
muslo/pantorrilla; limita el ajuste al círculo alcanzable de la articulación.
Añade `WALK_LEAN = 4°` hacia delante: `Spine` aporta 1,6° (40 %),
`Spine1`, `Spine2` y `Neck` aportan 0,8° cada uno. La cabeza sigue los 4°
acumulados del cuello. La entrada/salida se suaviza y se reduce con la velocidad
visual y la transición a carrera. La marcha agachada mantiene su postura propia.
La carrera usa `RUN_KNEE_SPREAD = 1.32`: aumenta un 20 % la separación lateral
que produce el factor de caminata 1,10, respetando el círculo alcanzable de
cada rodilla. La entrada y salida del sprint mezclan ambos factores sin
desplazar los pies ni cambiar las longitudes de muslo y pantorrilla.
En las diagonales delanteras, la rodilla del lado de avance usa el plano
frontal de la postura nativa como guía de flexión. Su corrección lateral se
limita a 25° en el círculo de rodilla, conservando flexión hacia delante
cuando la pierna está casi extendida. La corrección entra suavemente con
la dirección y el peso de marcha/carrera; mantiene pie, cadera y longitudes.
Usa `RUN_LEAN = 7,2°` con su distribución proporcional propia:
`Spine` aporta aproximadamente 2,323° y `Spine1`, `Spine2` y `Neck`
aportan aproximadamente 1,626° cada uno. La cabeza acompaña al cuello; la mezcla
marcha/carrera interpola los aportes por hueso junto con el peso de sprint.
La carrera añade `RUN_BACK_CURVE = 2°` de curvatura hacia delante, repartidos
por igual entre `Spine`, `Spine1` y `Spine2` (aproximadamente 0,667° locales
en cada uno; acumulados 0,667°/1,333°/2°). Cuello y cabeza acompañan los 2°
acumulados sin añadir flexión propia; su inclinación total de carrera es 9,2°.
La curva sigue el peso suavizado de carrera durante el arranque, la frenada
y la transición con caminata. No añade curvatura a la caminata ni a la pelvis.
Al agacharse, `CROUCH_BACK_CURVE = 5°` añade flexión hacia delante en la
espalda: 1,5° en `Spine`, 1,5° en `Spine1` y 2° en `Spine2`, situado en la
zona de omóplatos y receptor del 40 % de la curva. Cuello y cabeza acompañan
los 5° acumulados sin añadir flexión propia ni cambiar escala o longitudes.
La curva sigue la entrada de agacharse y se suaviza al cambiar de postura;
la marcha y los gestos realizados agachado la conservan según su peso de postura.
La pelvis acompaña las diagonales con `DIAGONAL_PELVIS_TURN = 33°` totales.
La espalda contragira suavemente respecto a la pelvis: `Spine` resta 1,5°,
`Spine1` resta 1° y `Spine2` resta 0,5°. Sus acumulados respecto al personaje
son 31,5°/30,5°/30°, frente a los 33° de pelvis.
El giro adicional de pelvis se hereda como una transformación común del
tren superior alrededor de la articulación de cadera; la compensación local
de columna conserva la misma dirección de avance sin sobrepasar el giro de
pelvis. Hombros y brazos acompañan los 30° de la espalda alta.
Los anclajes nativos de muslo acompañan el giro de pelvis conservando los
objetivos de apoyo y las longitudes de pierna. El giro cíclico de la zancada
se suma a esta orientación direccional y conserva su reparto propio.
Las diagonales de retirada invierten el giro respecto a las de avance del
mismo lado, manteniendo la orientación frontal. El giro desaparece suavemente
al acercarse a una dirección cardinal o al detenerse, con respuesta exponencial
14/s, velocidad de giro máxima de 120°/s y el filtrado direccional de los pasos.
Cuello y cabeza compensan progresivamente el giro heredado de pelvis:
en una diagonal completa, sin oscilación cíclica, sus giros acumulados
son 29° y 28° respectivamente. La cabeza conserva
su pequeño giro cíclico y no adopta toda la torsión de la espalda.
La columna visible distribuye la rotación total entre `Spine`, `Spine1` y
`Spine2` con pesos acumulados de 25 %, 60 % y 100 %. El giro cíclico del pecho
ronda ±3° al caminar y ±7° al correr, siguiendo la pierna que recupera.
`gait_parameters.gd` define `TORSO_YAW = 3°` y `RUN_TORSO_YAW = 7°`.
El reparto acumulado 25/60/100 % conserva los aportes locales de 25/35/40 %.
`RUN_TWIST_SCALE = 2.0` regula cadera y hombros.
La pista de columna compensa el contragiro amortiguado de la cadera, para
conservar esas amplitudes visibles. La clavícula del mismo lado desciende
hasta 2° en marcha y 4° en carrera; el brazo entero acompaña desde el hombro.
Cuello y cabeza siguen suavemente: la cabeza añade un 25 % del giro cíclico
del pecho a su orientación compartida, más una amplitud de 1° al caminar y
2° al correr (`WALK_HEAD_EXTRA` / `RUN_HEAD_EXTRA`). Reutiliza la misma curva
reducida del pecho para conservar fase y sentido. El giro visible de cabeza
ronda ±2,35° en marcha y ±5,15° en carrera, inferior al del pecho (±3°/±7°).
El peso de sprint interpola el aporte adicional y la velocidad visual atenúa
el gesto al detenerse. El cuello interpola entre la rotación del pecho y
la cabeza, manteniendo la unión y las longitudes del rig.
Los brazos libres y los objetivos de agarre acompañan al pecho, manteniendo
las longitudes y los contactos reales de las manos. El peso de sprint mezcla
las curvas de pecho, columna, cabeza y hombros durante arranque y frenada;
la intensidad sigue la velocidad visual. El resto de gestos distribuye sus
rotaciones entre pelvis y pecho con su postura propia.
Las pistas `spine` y `shoulders` comparten el reloj y la reducción de claves
con marcha/carrera, con error angular/peso máximo de 0,0004.
Las manos libres mantienen dedos recogidos en reposo, marcha, carrera y
postura/marcha agachada en todas las direcciones, incluidos los arranques,
frenadas y las manos libres durante equipamiento agachado. La curvatura nativa
se precalcula en `native_hand_grip.gd`: nudillo/articulación media/punta de
16°/26°/7° en índice, 20°/30°/9° en corazón, 24°/34°/11° en anular y
28°/38°/13° en meñique; pulgar 8°/14°/7°, orientado suavemente hacia la palma.
Las falanges conservan sus longitudes y espacio respecto a la palma. Esta
pose no sustituye ataques, recogida, salto, deslizamiento ni manos ocupadas.
Referencias de postura: [Hand Posing Basics](https://blog.animschool.edu/2025/05/09/hand-posing-basics/)
y [Posing Hands for Animation](https://blog.animschool.edu/2025/06/13/posing-hands-for-animation-2/), de AnimSchool.
Los dedos nativos de pico, hacha y espada envuelven el mango con pulgar opuesto,
conservando la longitud reducida de cada falange. El centro de palma se adapta
al tamaño 0,90 en todos los contactos, incluido el arco y su cuerda. El cierre
de los dedos usa sus longitudes efectivas y su grosor reducido alrededor de
los mangos a tamaño real, sin escalar las armas ni sus anclajes.
El cierre usa el peso de equipamiento
y el de la mano de apoyo. `data/animation/characters/hand_grips.tres` contiene
las secciones medidas y las orientaciones de palma relativas a cada mango;
se regenera con `bake_grips.gd`. Esa orientación estable evita inversiones del
agarre al cambiar el plano del golpe. Al equipar o guardar se resuelve el cierre
en el contacto final y se mezcla en las articulaciones locales nativas: los
dedos no persiguen el eje del mango mientras la muñeca todavía se aproxima.
La geometría
de herramientas se consulta únicamente en esa herramienta de autoría.
El apoyo de marcha/carrera rueda suavemente de talón a planta y despega por
los dedos: −0,05/+0,085 rad caminando y −0,035/+0,085 rad corriendo. La bajada
del pie usa un arco vertical C2 con velocidad y aceleración nulas al contactar;
conserva el recorrido horizontal, la altura máxima y la cadencia. La rodilla
acompaña la descarga progresiva del tobillo, con longitudes óseas constantes.
Los pies suavizan la entrada durante 0,15 s; el ciclo posterior sigue las claves
sin un filtro acumulativo que retrase el contacto. Los giros de marcha y carrera
comparten el suavizado de dirección de 0,12 s.

La caída de 3 s apoya primero las rodillas y termina boca abajo, con brazos y
piernas abiertos. Un conjunto reducido de apoyos de la piel real mantiene el
contacto con el suelo, incluyendo interrupciones desde posturas bajas.

La superficie `meshy/survivor_axilla.res` se conserva como donante del
sistema de autoría de contactos y para sus verificaciones históricas. No es la
malla visible del jugador. Sus bucles del sobaco y 24 controles pertenecen a
ese sistema. `build_axilla.gd`, `bake_controls.gd` y `bake_ground.gd` regeneran
esos recursos cuando cambia la autoría compartida; después de cambiar curvas,
regenerar también `bake_native_ground.gd`. No reemplazar la composición visible
por ese donante ni reconstruir su cabeza aprobada desde él.

Referencias de autoría: [marcha](https://www.animationmentor.com/blog/tutorial-animating-human-walk-cycle/),
[carrera](https://www.animationmentor.com/blog/animating-dynamic-run-cycles/),
[salto y aterrizaje](https://www.animationmentor.com/blog/tutorial-animate-a-jump-and-land/),
[deslizamiento sobre cadera](https://www.littleleague.org/university/articles/backyard-tips-sliding-tip/),
[mecánica de hacha](https://www.fs.usda.gov/t-d/pubs/pdfpubs/pdf18232812P/Part11a_UsingAnAx.pdf),
[golpes de herramientas](https://mocaponline.com/blogs/mocap-news/survival-game-animation-guide)
y [espada](https://www.animationmentor.com/blog/tutorial-animate-sword-fights-battle-sequences/).
Los movimientos se adaptan al rig y los tiempos de juego; no se incluyen clips
comerciales de terceros.

## Contratos de anatomía y contacto

El superviviente 3D representa un hombre estilizado de 1,75 m y 60 kg, delgado,
con articulaciones identificables y definición anatómica discreta. Compartir
anatomía y pesos de piel en todas las animaciones. La tela holgada acompaña las
piernas con inercia pequeña. Cada golpe tiene preparación, acción, retroceso y
recuperación. El golpe apunta al punto de mira fijado al iniciarlo, con alcance
limitado por brazos y herramienta. Las nuevas herramientas usan los anclajes
del catálogo de poses, sin duplicar o separar brazos del cuerpo.

Usar los modelos y rigs de `scripts/prototype_3d/` y la cinemática de
`scripts/continuous_body_pose.gd` como base reutilizable para personajes y
enemigos. El runtime y los exportadores de sprites 2D se han retirado. Los huesos
mantienen su longitud; hombros y caderas permanecen dentro
del torso, y piel, manos, pies y ropa acompañan sus articulaciones. Las fases de
apoyo y transferencia se comparten mediante `stance_swing`; el número de patas y
la postura deben corresponder a la criatura.

Las reglas de oclusión y orientación de herramientas están en
[WEAPON_ANIMATIONS_3D.md](WEAPON_ANIMATIONS_3D.md#orientación-y-oclusión).
Validar pelvis, columna, transferencia de peso, apoyos y continuidad en las
poses y transiciones afectadas, sin alargar huesos para alcanzar un contacto.
La base nativa y su regeneración se describen en el apartado [Personajes](#personajes);
las fuentes y perfiles exactos están en [MESHY_ASSETS.md](MESHY_ASSETS.md#contratos-de-fuentes-y-modelos).
