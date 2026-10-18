# Materiales y modelo compartidos del personaje 3D

El personaje visible carga `composite/model.scn`: cuerpo y 66 huesos originales
en T, cabeza aprobada y transición cerrada de cuello. El cuerpo usa el albedo
incluido en su FBX; la cabeza conserva los mapas de `meshy/`, el perfil
`face_materials_v1` y su relieve sutil. El modelo y el retrato usan la misma
malla y binds inmutables, con poses independientes.

`meshy/survivor_skin.res` y `survivor_axilla.res` se conservan como donantes
para autoría de contactos y verificaciones del sistema compartido. No dibujan
el cuerpo actual. `pixel_materials.png` sigue sirviendo a objetos procedurales.

El acabado vigente es fantasía 3D estilizada con texturas pintadas, colores
armonizados, detalle limpio y relieve moderado, con enemigo3 como referencia.
Consultar `docs/ANIMATION_SYSTEMS.md` para regenerar la composición, sus curvas
y los apoyos nativos; las reglas visuales están en AGENTS.md.
