# Superviviente Meshy optimizado

Fuente vigente: `personaje1.zip`, Release `modelo_personaje3d`. El FBX original
`source/Meshy_AI_Rugged_Castaway_1017215425_texture.fbx` tiene 15598 vértices y
31182 triángulos, sin rig ni animaciones. Los PNG originales y los hashes están en
`assets/characters/prototype_3d/meshy/source.json`.

`survivor_skin.res` conserva la ligadura existente de 24 huesos transferida,
el pulido de sombreado de piel y el material facial
`face_materials_v1` con correcciones de pelo/barba y relieve adicional sutil.
La fuente conserva posiciones, UV, triángulos y PNG.
El juego muestra `survivor_axilla.res`, una superficie derivada con subdivisión
local del sobaco y pesos graduales entre tórax y brazo. La fuente no se modifica.
Las curvas y la regeneración se describen en `docs/ANIMATION_SYSTEMS.md`. La carpeta source está excluida de la
importación
automática mediante `.gdignore`. Ver `docs/MESHY_ASSETS.md` para regenerar.
