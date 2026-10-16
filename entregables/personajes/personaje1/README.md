# Superviviente Meshy optimizado

Fuente vigente: `personaje1_3d.zip`, Release `modelo_personaje3d`. El FBX original
`source/Meshy_AI_Wild_Wanderer_1016142901_texture.fbx` tiene 10440 vértices y
20878 triángulos, sin rig ni animaciones. `source/survivor.fbx` se conserva
solo como histórico. Los PNG originales y los hashes están en
`assets/characters/prototype_3d/meshy/source.json`.

El juego carga `survivor_skin.res`, con la ligadura existente de 24 huesos
transferida y el pulido de sombreado de piel. Las posiciones, UV, triángulos
y PNG nuevos se conservan. La carpeta source está excluida de la importación
automática mediante `.gdignore`. Ver `docs/MESHY_ASSETS.md` para regenerar.
