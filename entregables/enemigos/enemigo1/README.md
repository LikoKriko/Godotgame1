# Enemigo1 — Meshy Mossclaw Boar

Modelo vigente aportado por el usuario en la Release `modelo-enemigo1`:
`enemigo1_3d.zip`, SHA-256
`64e21cf1b8822e63a0913015a4b2ef29a6c6ca62831bf83eef4e5eadc938e5bc`.

- FBX reducido original: `source/Meshy_AI_Mossclaw_Boar_1016001519_texture.fbx`.
- 3672 vértices de autoría, 7340 triángulos; sin esqueleto ni clips.
- PNG originales, hashes y recurso de ejecución: `assets/enemies/first/meshy/`.
- El FBX `1015190139` anterior se conserva solo como fuente histórica.

La versión reducida hereda la ligadura animada de quince huesos mediante
transferencia de pesos, conservando geometría, UV y PNG nuevos. `source/` lleva
`.gdignore` para evitar importar/exportar los FBX por duplicado. El juego carga
únicamente `mossclaw_skin.res`. Ver `docs/YOUNG_3D.md` para reproducir la conversión.
