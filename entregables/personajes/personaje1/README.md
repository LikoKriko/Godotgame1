# Superviviente Meshy optimizado

Fuente vigente: `personaje1.zip`, Release `modelo_personaje3d`. El FBX original
`source/Meshy_AI_Rugged_Castaway_1017215425_texture.fbx` tiene 15598 vértices y
31182 triángulos, sin rig ni animaciones. Los PNG originales y los hashes están en
`assets/characters/prototype_3d/meshy/source.json`.

El juego carga `survivor_skin.res`, con la ligadura existente de 24 huesos
transferida, el pulido de sombreado de piel y el material facial
`face_materials_v1` con correcciones de pelo/barba y relieve adicional sutil. Las posiciones, UV, triángulos
y PNG nuevos se conservan. La carpeta source está excluida de la importación
automática mediante `.gdignore`. Ver `docs/MESHY_ASSETS.md` para regenerar.
