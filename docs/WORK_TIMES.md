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
