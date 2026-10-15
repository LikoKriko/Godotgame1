# Referencias de anatomía

Las referencias consultadas para los límites articulares fueron [Arm26 de OpenSim](https://github.com/opensim-org/opensim-models/blob/master/Models/Arm26/arm26.osim) y [Gait2392](https://github.com/opensim-org/opensim-models/blob/master/Models/Gait2392_Simbody/gait2392_thelen2003muscle.osim). Son modelos biomecánicos, no medidas exactas del personaje.

La versión actual usa un cuerpo de autoría continuo: huesos de longitud constante, codos limitados a 130°, hombros unidos al torso, piernas desfasadas medio ciclo, 60% de apoyo y 40% de avance. Los fotogramas se exportan con cuerpo, ropa y herramienta juntos; el juego no deforma extremidades. La preparación, aceleración, contacto y recuperación del hacha son diferentes de las del pico. El rebote es una curva estilizada por categoría, no una simulación de fuerzas ni una respuesta física medida del material. Los contactos y el consumo de usos siguen las reglas existentes del juego.

El arco conserva su dibujo, con cuerda móvil y flecha proyectada desde la misma pose de disparo. Las herramientas posteriores quedan ocultas por cuerpo y cabeza usando la profundidad al exportar. La sombra del jugador se obtiene de la misma imagen RGBA completa que se muestra en pantalla.

Para detalle de formatos, fotogramas y regeneración, véase [COMPLETE_SPRITE_PLAN.md](COMPLETE_SPRITE_PLAN.md). Las pruebas de los módulos antiguos de mallas validan esos cálculos, pero no acreditan la presentación visible actual.


## Primera revisión de deslizamiento 3D — 15 de octubre de 2026

El usuario eligió deslizamiento sobre una cadera, con una pierna extendida y la
otra flexionada. `scripts/prototype_3d/slide_pose.gd` implementa esa postura con
IK de longitudes constantes y transfiere la pose al salto. Esta implementación
es una primera aproximación anatómica; **no se ha contrastado todavía con un
vídeo, una secuencia fotográfica o mocap real de un deslizamiento**.

Se intentó consultar Little League y la página de Slide (baseball) de Wikipedia;
el proxy rechazó esos dominios con 403 antes de obtener su contenido. La búsqueda
en GitHub fue accesible, pero no proporcionó una referencia útil verificada. Se
ha guardado el borrador de red con los dominios de Little League y Wikimedia,
pendiente de publicación. No citar esas fuentes como consultadas ni dar por
terminada la parte de investigación visual hasta poder examinarlas.
