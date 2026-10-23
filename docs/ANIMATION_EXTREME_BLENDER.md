# Aren: caída extrema Blender (revisión visual)

Rama exclusiva: `test/animation-system-v1`. Escena de revisión:
`scenes/prototype_3d/aren_authoring_review.tscn`. La incorporación nueva
requiere aprobación visual antes de entrar en `aren_terrain_test.tscn`.

## Clips y aislamiento

Las cuatro primeras fases y la variante de muerte conservan el clip y actor
`aren_extreme_blender_v1` / `aren_extreme_actor.gd`. Su fuente
`authoring/aren_extreme.blend`, curvas, poses y contactos permanecen intactos.
El visor ofrece una sola comparación **Anterior / Nueva** para la incorporación:

| Variante | Incorporación | Reloj completo del clip |
| --- | --- | --- |
| Anterior | 8,00 s | 0–10,40 s |
| Nueva | 6,25 s | 0–8,65 s; clip independiente 0–6,25 s desde 2,40 s |

`aren_getup_v2_actor.gd` extiende el actor existente y sustituye únicamente
la fase de incorporación al sobrevivir. Reutiliza muestreador, física,
contactos e IK nativos. Godot reproduce las poses horneadas; no genera una
incorporación corporal procedural. El resultado «muere» permanece tumbado
con el control bloqueado y nunca entra en el clip nuevo.

## Referencias y diseño de la incorporación nueva

Se estudian dos **capturas de movimiento de personas reales**, CMU subject 140,
«Getting Up From Ground»: [140_01](https://github.com/una-dinosauria/cmu-mocap/blob/master/data/140/140_01.bvh)
y [140_02](https://github.com/una-dinosauria/cmu-mocap/blob/master/data/140/140_02.bvh),
ambas «Get Up Face Down». El [índice y README del espejo público](https://github.com/una-dinosauria/cmu-mocap)
identifican las tomas y la conversión BVH de Bruce Hahne/cgspeed.
Se analizan secuencia de apoyos, desplazamiento de pelvis, avance de piernas
y duración. Las tomas sirven como referencia biomecánica: **no se retargetean
ni se copian sus poses o curvas al rig de Aren**.

Atribución de la base CMU: “The data used in this project was obtained from
mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.”
Los BVH de referencia no se incorporan al juego.

La nueva acción parte del rig original de 66 huesos del piloto Blender.
Solo conserva los dos estados autorizados: boca abajo y el Idle aprobado,
exportados en `authoring/endpoints.json`. No carga curvas, poses o trayectorias
de la incorporación anterior. La duración se diseña para mostrar el esfuerzo
tras la caída, sin imponer los ocho segundos anteriores.

Se utiliza un apoyo intermedio de rodillas para elevar el tronco antes de
adelantar el pie derecho. Esto adapta el principio observado en las capturas
a los brazos y piernas nativos de Aren y evita exigir una flexión de cadera
extrema bajo un abdomen todavía horizontal. La base de rodillas y empeines
sostiene el cuerpo mientras se descargan las manos; después el pie derecho
y la rodilla izquierda sostienen la elevación y el avance del pie izquierdo.
El pequeño paso derecho final ocurre con el peso sobre el pie izquierdo.

| Tiempo local | Pose completa / apoyo |
| --- | --- |
| 0,00 | Boca abajo aprobado |
| 0,70 | Palmas cerca del pecho; piernas extendidas y relajadas |
| 1,30 | Empuje inicial con hombro izquierdo adelantado |
| 1,90 | Pelvis elevada antes de recoger las piernas |
| 2,40 | Rodillas apoyadas; manos preparadas para descargar |
| 3,20 | Tronco elevado sobre rodillas; manos libres |
| 3,85 | Planta derecha apoyada; rodilla izquierda estabiliza |
| 4,40 | Elevación sobre la derecha; izquierda avanza |
| 4,95 | Ambas plantas sostienen el cuerpo |
| 5,40 | Peso sobre la izquierda; derecha recoge la postura |
| 5,80 | Base equilibrada para el cierre |
| 6,25 | Idle aprobado exacto |

La palma izquierda se coloca a los 0,34 s y estabiliza mientras se coloca
la derecha (0,70 s), por arcos descargados. La descarga entre 2,40 y 2,85 s
precede a la relajación gradual de muñecas al elevar el tronco. El contacto
IK se descarga en el primer fotograma de salida: el clip ya contiene el
arco de retirada, y no debe mezclarse de nuevo hacia la palma bloqueada.
`palm_release` describe esa salida del IK y `palm_exit` el arco Blender. El pie derecho
avanza con un arco de despeje y llega a planta completa; no se fuerza el antepié.
Los tiempos de apoyo y salida se almacenan en `timing.json`. El IK de autoría
resuelve contactos y longitudes originales antes de hornear poses completas.
La interpolación corporal cúbica conserva continuidad sin sobrepasar las claves;
el horneado nativo utiliza 60 Hz. No se alteran rig, pesos, proporciones ni carrera.

## Fuente editable, horneado e importación

`assets/characters/prototype_3d/generated/aren_getup_blender_v2/` contiene:

- `authoring/aren_getup_v2.blend`: malla y rig originales, acción de **12 poses
  completas** `ArenGetupV2_TwelveWholeBodyPoses`, acción de contactos horneada
  `ArenGetupV2_ContactBaked` y copia separada de exportación.
- `authoring/poses.json`: decisiones nuevas de cuerpo completo.
- `authoring/endpoints.json`: únicamente boca abajo e Idle autorizados.
- `getup_v2.glb` / `getup_v2.res`: clip independiente, 376 muestras / 6,25 s.
- `timing.json`: claves, duración, apoyos y referencias.

Para editar manualmente, trabajar sobre la acción de contactos o seleccionar
la acción de poses como bloqueo de referencia. **Hornear con `--bake-only`
para conservar las ediciones manuales**; las otras opciones reconstruyen la
nueva autoría a partir de sus decisiones declaradas.

```sh
# Generación del bloqueo: revisar las 12 poses antes de interpolar.
blender -b -t 4 --python tools/animation/author_aren_getup_v2.py -- --keys-only
# Comprobar la piel real del bloqueo.
blender -b assets/characters/prototype_3d/generated/aren_getup_blender_v2/authoring/aren_getup_v2.blend -t 4 --python-exit-code 1 --python tools/animation/validate_aren_getup_v2.py -- --keys-only
# Tras validar el bloqueo: resolver intermedios y exportar la acción nueva.
blender -b -t 4 --python tools/animation/author_aren_getup_v2.py -- --animate
# Comprobar todos los fotogramas de la piel horneada antes de importar.
blender -b assets/characters/prototype_3d/generated/aren_getup_blender_v2/authoring/aren_getup_v2.blend -t 4 --python-exit-code 1 --python tools/animation/validate_aren_getup_v2.py
# Alternativa: exportar la acción editada sin reconstruirla.
blender -b assets/characters/prototype_3d/generated/aren_getup_blender_v2/authoring/aren_getup_v2.blend -t 4 --python tools/animation/author_aren_getup_v2.py -- --bake-only
# Importación del mismo rig, sin retargeting.
godot --headless --path . --script tools/animation/import_aren_blender_landing.gd -- --getup-v2
```

El importador compartido conserva sus opciones anteriores de piloto y caída
extrema. Comprueba los 66 huesos y la coincidencia de reposo/unidades antes
de guardar los 198 canales nativos. Los archivos anteriores no se regeneran.

## Revisión y futura integración

Abrir `aren_authoring_review.tscn` y ejecutar **F6**. Seleccionar
**Blender · caída extrema ≥8 m → Previsualizar: sobrevive → Comparar: Nueva**.
**Secuencia completa** reproduce la caída y la incorporación; **Incorporación**
permite inspeccionar directamente esa fase. Comparar con **Anterior**, usar
**1× / 0,25×**, Pausa y la barra temporal. Se mantienen vistas frontal, lateral,
trasera y diagonal, alturas 8/10/12/16 m y previsualización de muerte.

Comprobar la malla visible, no solo huesos: abdomen/muslos, espacio para la
pierna, estabilidad de contactos, pies y tobillos, transferencia de peso,
continuidad articular y enlace al Idle. Pruebas de soporte y regresión:

```sh
godot --headless --path . --script tests/aren_getup_v2_review.gd
godot --headless --path . --script tests/aren_getup_v2_review.gd -- --quarter
godot --headless --path . --script tests/aren_extreme_catalog.gd
```

La futura integración jugable deberá consultar `game.player_health` después
del daño mediante el sistema vigente. El selector del visor solo presenta
resultados de revisión; no crea vida ni daño paralelos. La predicción física
de caídas sobre geometría desconocida sigue fuera de esta entrega.
