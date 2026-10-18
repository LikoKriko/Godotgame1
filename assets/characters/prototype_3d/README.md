# Materiales compartidos del personaje 3D

`pixel_materials.png` contiene cuatro regiones: piel, tela, pelo y cuerda.
Se utiliza como material compartido para objetos y superficies procedurales.
El superviviente conserva sus PNG Meshy originales y `survivor_skin.res` como
fuente; muestra `meshy/survivor_axilla.res`, con soporte local del sobaco. El
perfil de material se describe en `docs/MESHY_ASSETS.md`; la regeneración de
superficie, curvas y apoyos está en `docs/ANIMATION_SYSTEMS.md`.

El acabado de los recursos nuevos sigue la fantasía 3D estilizada de enemigo3:
texturas pintadas, colores armonizados y detalle limpio con relieve moderado.
El superviviente usa filtrado lineal anisotrópico con mipmaps y un normal facial
adicional sutil; conserva los mapas de color y rasgos de la entrega.
Las reglas visuales se encuentran en AGENTS.md.
