# Perfiles de criaturas, sombras y pulido visual

`resources/creatures/young_mole.tres` configura al joven sin mezclar decisiones
con dibujo o daño. `creature_profile.gd` define especie, curiosidad, agresividad,
hábitat, velocidades y duraciones; `creature_behavior.gd` decide las actividades.
`enemy.gd` aplica desplazamiento, combate y sprites completos. Otras especies
pueden reutilizar este mecanismo con un perfil propio y sus atlas.

El joven persigue dentro de 250 unidades al 85% de la caminata inicial del jugador
(59,5 unidades/s), y explora al 42,5% (29,75 unidades/s). Prefiere árboles
agrupados, come durante 2–10 s, y se sienta durante 4–8 s. Las transiciones de
sentarse/levantarse duran 0,3 s. La pose sentada tiene cuatro fotogramas con un
ciclo lento de cabeza de 4 s. La detección del jugador interrumpe la actividad;
la recuperación de la pose puede acompañar el desplazamiento inmediatamente.
Actividades y secuencia aleatoria se incluyen en el guardado.

## Contactos de sombra

`ground_contact_shadow.gd` conserva el raster y una malla reutilizable por
textura/contactos. Los contactos se expresan en coordenadas normalizadas del
sprite (0–1), independientes de su colisión. El contorno alfa inferior sirve
como valor por defecto para raíces y rocas. Objetos con patas deben declarar
cada pie explícitamente, como `workbench_art.gd.SHADOW_CONTACTS`. La choza
también declara los apoyos de su fachada mediante `hut.gd.SHADOW_CONTACTS`.

`ground_contact_shadow.gdshader` proyecta la silueta desde esos apoyos. La zona
superior usa un plano compartido, mientras los contactos inferiores permanecen
anclados a sus píxeles visibles. Se actualizan uniformes del sol; las mallas no
se reconstruyen por fotograma. El personaje conserva su proyección anterior.
Un `CanvasGroup` une las siluetas antes de aplicar opacidad, evitando marcas
oscuras cuando se solapan triángulos de la proyección. Su margen contempla el
desplazamiento producido por el shader. Al añadir un edificio o mueble, revisar sus apoyos con varias direcciones de luz;
no usar el final de una hitbox ni una única fila global para objetos con patas.

## Configuración y recursos

- Gráficos → **Cámara nítida**: ajuste opcional de la cámara a píxeles físicos.
  No redondea posiciones ni modifica la física. Desactivada por defecto.
- La espada mantiene 16 fotogramas y pasa de 0,62 a 0,837 s. Las vistas
  problemáticas abren el agarre delante del torso; izquierda y abajo-izquierda
  conservan su recorrido. El codo tiene un límite de flexión de 115°.
- Armadura de hojas: paleta restringida, separaciones finas, mismo tratamiento
  para icono y superficie continua del torso. Exportar todos sus perfiles al
  cambiar esa superficie, incluido el arco sin flecha.
- Plataformas: doble densidad de raster, tamaño y altura física sin cambios,
  conservando el grosor del contorno en unidades del mundo.
- Césped: doce originales y cinco composiciones nuevas. Regeneración con
  `tools/bake_grass_variants.gd`; no sustituye los originales de entregables.
- Marcos: contorno reforzado en tramos intermedios (mínimo cuatro píxeles
  lógicos; doce en el marco grande de inventario),
  conservando esquinas, adornos, medidas y márgenes de texto del 15%.

La pantalla de carga se muestra antes de generar. `world_build_job.gd` realiza
la generación de datos en un hilo; texturas y nodos se preparan en el hilo
principal. La barra refleja etapas reales y el mundo preparado se reutiliza
al crear/restaurar la escena, evitando generaciones duplicadas. En ejecución sin
pantalla no se espera una señal de dibujo que el renderizador vacío no emite.
