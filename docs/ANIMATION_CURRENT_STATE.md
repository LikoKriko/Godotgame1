# Sistema de animaciones de Aren: estado actual

**Rama:** `test/animation-system-v1`. **Base anterior de autoría:** `1520151`.
Trabajar en esta rama; no integrar en `main` sin autorización. Rutas relativas
a la raíz del proyecto Godot 4; leer las instrucciones `AGENTS.md` aplicables.

## Arquitectura y archivos principales

Generación parametrizada, perfiles JSON y recursos versionados; muestreo de
ciclos, mezcla de poses y contactos, IK de longitudes fijas y correctivos de
rodilla. Rig nativo de 66 huesos; conservar modelos, binds, materiales y fuentes.

- Modelo: `assets/characters/prototype_3d/composite/model.scn`.
  Rig: `data/animation/characters/survivor_native.tres`.
  Enlace: `scripts/animation/characters/native_survivor.gd`;
  herramientas compartidas: `scripts/animation/shared/`.
- Variante actual: `assets/characters/prototype_3d/generated/aren_run_balanced_v1/aren.tscn`
  y `assets/characters/prototype_3d/generated/aren_run_balanced_v1/profile.json`.
- Evaluación: `scripts/animation/authoring/aren_run_balanced_actor.gd`,
  `scripts/animation/authoring/aren_run_balanced_sampler.gd`;
  tobillos: `scripts/animation/authoring/aren_run_foot.gd` y
  `scripts/animation/authoring/aren_run_left_foot.gd`.
- Transiciones: `scripts/animation/authoring/aren_transition_actor.gd`.
- Generador de la variante: `tools/animation/generate_aren_run_balanced.gd`.
  Generador base: `tools/animation/generate_aren.gd`; solicitudes de vocabulario
  acotado: `scripts/animation/authoring/aren_request.gd`.
- Revisión: `scenes/prototype_3d/aren_authoring_review.tscn`,
  `scripts/animation/authoring/aren_review.gd` y
  `scripts/animation/authoring/aren_review_pose.gd`: cuatro cámaras, una evaluación
  de pose compartida; `actors[0]` mantiene el estado de simulación.

## Disponible y uso

`idle`, `walk`, `run`; estados `normal`, `cautious`, `tired`. Transiciones:
`idle_to_walk`, `idle_to_run`, `walk_to_run`, `run_to_walk`, `walk_to_idle`,
`run_to_idle`, con anticipación, aceleración/frenada y contactos compartidos.
La variante actual aplica a ambos pies los mismos parámetros de recuperación,
con medio ciclo de desfase; hereda zancada, cadencia, velocidad, torso y brazos.
Las versiones anteriores siguen seleccionables sin sobrescribir sus recursos.

Abrir la escena de revisión con **F6**, elegir **Carrera: pies coordinados**,
estado y ciclo/transición. **Ver antes / Ver después** alterna con la variante
del pie derecho; **Encadenadas**, **Reiniciar**, pausa y velocidad permiten revisar
secuencias desde frente, lateral, espalda y tres cuartos.

API del actor: `set_style(estado)`, `reset_motion(gait, fase)`,
`request_transition(nombre)`, `advance_transition(delta)`, `seek_cycle(clip, segundos)`.
El anfitrión aplica `distance_m` como avance sobre +Z; subpasos internos ≤1/120 s.
Regenerar solo en un directorio nuevo, preservando las referencias `source_hashes`:

```sh
godot --headless --path . --script tools/animation/generate_aren_run_balanced.gd -- --output res://assets/characters/prototype_3d/generated/aren_run_balanced_custom
```

## Completado, pendiente y próximo objetivo

Implementados: generación por parámetros/solicitudes acotadas, tres ciclos y
estados, transiciones encadenables/interrumpibles, apoyos en plano y comparación.
La última corrección izquierda se publicó **sin pruebas, importación ni revisión
visual por petición del usuario**: validar ciclo y transiciones antes de aprobarla.
`tests/aren_run_refined.gd` cubre la variante previa; falta ampliar la cobertura
a `aren_run_balanced_v1`. No hay generación universal de movimientos desde texto.

## Prueba jugable de terreno (aislada)

Abrir `scenes/prototype_3d/aren_terrain_test.tscn` y pulsar **F6**. No cambia
la escena principal ni el visor `aren_authoring_review.tscn`.

- WASD: movimiento relativo a cámara; Mayús: carrera; botón derecho y ratón:
  orientar cámara; 1/2/3: normal/cauteloso/cansado; R: volver al inicio.
  4/5: acceso al camino de tierra o al terreno forestal, mirando hacia su recorrido.
- Centro: plano, subida de 15°, plataforma y bajada de 15°. Izquierda: baches
  suaves. Derecha: pequeños desniveles de 5 a 25 cm. Geometría básica sin texturas.
- Camino de tierra: 6 × 28 m, centro `(-17, 0, -12)`, con ondulaciones continuas
  pequeñas. Terreno forestal: 12 × 28 m, centro `(19, 0, -12)`, con pendientes
  cruzadas, montículos, depresiones y variación lateral para apoyos asimétricos.
  `terrain_test_patch.gd` construye ambas superficies con triángulos de paso
  0,25 m; malla y colisión estática comparten vértices. Los bordes enlazan
  suavemente con el plano existente. Material gris uniforme, sin texturas ni
  decoración; las depresiones son relativas a la superficie elevada para que
  el plano original no las tape. Se conservan todas las zonas anteriores.
- `scenes/prototype_3d/aren_terrain_actor.tscn` hereda la variante coordinada;
  `scripts/animation/terrain/aren_terrain_actor.gd` añade contactos con colisiones,
  sondeos de talón/centro/punta y envolvente de suela nativa, normales, pelvis
  filtrada e IK nativa sin escalado
  de piernas. Anclajes de apoyo en mundo, también al girar; fase y mezcla usan
  el desplazamiento físico final, incluido el escalón, incluso al bloquearse.
- `aren_terrain_test.gd` reutiliza `movement_response.gd` para aceleración,
  frenada, dirección y reversión; conserva las seis recetas como preparación
  corporal. El colisionador cilíndrico conserva altura/radio y ofrece una base
  plana para no confundir bordes de escalones con paredes inclinadas.
  `terrain_step.gd` barre el cuerpo hacia arriba, avanza el desplazamiento real
  y baja hasta un aterrizaje transitable, con límite de 26 cm. Comprueba paredes
  y techo y confirma el recorrido completo sin duplicar el avance horizontal.
  El snap automático se limita al descenso posible por tick en una pendiente
  de 42° (mínimo 2,5 cm); salir de un borde usa gravedad, sin snap forzado de
  35 cm. Cambiar de estado conserva
  la fase y mezcla las poses locales, conservando longitudes, durante 0,3 s
  antes de resolver los apoyos; la velocidad de destino también se filtra.
  `terrain_foot_support.gd` cachea puntos de la malla skinned en espacio del
  tobillo para comprobar la suela completa, con margen inicial de 6 mm.
  Una rejilla dinámica de 3 mm de puntos skinned comprueba colisiones después
  de IK, una vez por fotograma físico, y permite
  corrección vertical del tobillo (margen de 3 mm) calculada desde cero por pose,
  sin acumularla en el anclaje persistente ni realimentar la pelvis.
  Antes de ese barrido, `terrain_foot_support.gd` transforma las envolventes por
  hueso de todos los vértices de piel y consulta un volumen conservador, con
  el mismo alcance superior de 65 cm y margen de suela. Si no hay superficie,
  evita construir la rejilla y lanzar sus rayos. Si solo hay una caja y todas
  las proyecciones caen dentro de su cara superior transitable, calcula la
  separación con ese plano. En caras horizontales proyecta el skinning a Y;
  su mínimo coincide con el mínimo de la rejilla. En caras inclinadas conserva
  los puntos de 3 mm. Bordes, mallas, varios contactos o formas desconocidas
  siguen usando el barrido detallado original. La consulta se renueva por pose;
  no reutiliza alturas de otro fotograma ni cambia el reloj de apoyos a 120 Hz.
  Los rayos y el atajo de plano comparten la selección de superficies del actor:
  una cara elevada debe estar dentro del escalón de 26 cm. Si no pertenece al
  plano de suelo del controlador (tolerancia 3,5 cm), requiere movimiento real
  hacia ella y un aterrizaje válido del barrido corporal de `terrain_step.gd`.
  Este barrido anticipado de 35 cm solo consulta colisiones; no mueve el cuerpo
  y se cachea por actualización física. No autoriza terrazas laterales o traseras.
  La IK limita la flexión añadida a 130°, conservando cualquier flexión mayor
  presente en la pose aprobada, también después de la compensación de pelvis
  y de suela. Un apoyo anclado válido puede completar su fase aunque el sondeo
  nominal cruce un borde; al liberarlo, el desfase parte del objetivo actual
  y se desvanece con `smooth5`, incluso si no hay superficie aceptable.
  En vuelo, un sondeo horizontal detecta caras de escalón antes de que las
  alcance la piel. El sondeo vertical y la política anterior deben aprobar
  su superficie superior. La envolvente exacta de la piel determina la
  distancia y velocidad de aproximación a esa cara, incluyendo la rotación
  de la pierna; se anticipa con `smooth5` en una ventana de 0,16 s, entre
  15 y 50 cm. Las observaciones conservan su tiempo físico y normal de cara
  para no interpretar giros o fotogramas sin detección como velocidad adicional.
  Los cambios grandes de corrección elevan el pie con límite de 2 m/s,
  conservando su última posición y orientación seguras junto al borde hasta
  tener altura suficiente; luego mezclan el avance y la orientación durante
  0,12 s. Al abandonar un nivel, solo la corrección añadida retiene altura y
  desciende con frecuencia 24 y límite de 1,5 m/s, por encima del objetivo de
  colisión. La historia guarda la corrección realmente aplicada
  tras los límites anatómicos, sin sumarla al siguiente objetivo. El pie sigue
  en vuelo hasta alcanzar el nuevo apoyo; los anclajes estables no se filtran.
  `terrain_cycle_sampler.gd` reutiliza las muestras idénticas entre el cálculo
  de pecho durante el arranque y la pose final de esa misma evaluación. La
  caché exige el mismo clip y tiempo exacto, restaura la pose nativa y los polos
  de rodilla del clip, y se vacía al terminar la evaluación. No cuantiza tiempos
  ni modifica la frecuencia de animación o IK; fuera del arranque delega en el
  muestreador aprobado sin almacenar muestras.
  Los tres estados se precargan con muestreadores independientes: antes de
  configurar el siguiente se instala un muestreador temporal, para que el
  `set_style` heredado no reconfigure la instancia ya cacheada. Así clips, fase,
  zancada y parámetros de postura corresponden al mismo estado. La orientación
  usa el límite de giro del controlador existente. Clips y perfiles aprobados son de solo lectura.
- La pelvis calcula alcance para apoyos y anticipa el siguiente aterrizaje
  con poses frontales cacheadas y el vector de velocidad física, no el rumbo
  visual retrasado durante el giro. Omite anticipaciones a otro nivel fuera del
  alcance del escalón (26 cm). Solo el suelo de apoyos anclados determina la
  referencia corporal; un sondeo nominal en vuelo no cambia esa referencia.
  El alcance del pie en vuelo se acota con la IK existente. Altura de apoyo y alcance de ambas piernas se resuelven en un
  único objetivo firmado de pelvis (`pelvis_offset`, −28 a +22 cm), con resorte
  de frecuencia 18 y un único límite de 0,75 m/s en subpasos físicos.
  `reach_velocity` se expresa en m/s; `pelvis_lowering` heredado permanece a
  cero. Se filtra únicamente la corrección añadida, sin filtrar las curvas
  de oscilación corporal.
  La mezcla de marchas filtra los impulsos de velocidad de colisión (frecuencia
  24). La fase usa distancia física y zancada efectiva de esa misma mezcla,
  con límite de 3 ciclos/s para arranques de amplitud casi nula. La distancia
  acumulada sigue siendo la recorrida realmente.
  Los apoyos fuera de alcance o con más de 60° de giro corporal desde su
  adquisición se liberan hasta el siguiente ciclo; el vuelo
  conserva el desfase de apoyo y lo desvanece con `smooth5`, como en el visor.
- La altura visual sigue la altura real del controlador con un resorte de frecuencia
  25; modelo y cámara comparten esa referencia. El ajuste usa la altura real
  tras colisiones y escalones, sin restar subidas solicitadas o anticipadas.
  Las mezclas conservan las poses y pies anteriores a IK de terreno, y mantienen
  la compresión y su velocidad entre estados para evitar sumas o reinicios.
- El HUD muestra velocidad medida, error de apoyo, FPS y coste CPU de evaluación.
  Los sondeos usan la capa física 1, excluyen el controlador y aceptan normales
  hasta 42°. Alcance de sondeo: 0,65 m arriba y 0,85 m abajo del tobillo.

Alcance provisional: locomoción terrestre sobre colisiones estáticas. No incorpora
saltos, combate ni seguimiento de plataformas móviles. Revisar también la
naturalidad visual en Godot con F6 antes de integrar en el juego principal.
