# Aren: estudio visual independiente

Abrir `authoring/aren_visual.blend` en Blender 4.3.2 o ejecutar con F6
`scenes/prototype_3d/aren_model_v2_review.tscn` en Godot 4.7.2.
El proyecto conserva su escena principal y el personaje jugable originales.

El archivo Blender conserva las mallas editables de anatomía, rostro, cabello,
ropa y detalles, materiales de autoría, siete cámaras e iluminación neutra.
La colección `REFERENCE` contiene una copia inactiva de los 66 huesos originales.
La colección `EXPORT` conserva la copia estática con UV y atlas de color de
2048 × 2048 px. Ambas colecciones están ocultas al abrir el archivo.
`aren_visual.glb` contiene exclusivamente la copia visual, sin esqueleto ni clips.
`source.json` identifica fuente, huella, base Git, dimensiones y fase de revisión.

La anatomía corporal procede de una copia evaluada del FBX original, con brazos
bajados para revisar la silueta; se han sustituido cabeza, cabello y vestimenta,
añadido tatuajes y reconstruido las zonas superiores de los muslos. La superficie
se ha consolidado y reducido para esta revisión visual; los bucles de deformación
y pesos definitivos todavía requieren revisión específica. Esta pose
estática **no es una nueva pose de reposo del rig**. No contiene skinning aprobado
ni certifica deformación, compatibilidad de clips, contactos o IK. Estos trabajos
requieren aprobación visual previa y deben reutilizar los nombres y binds nativos.

## Revisión

Las vistas se seleccionan con los botones o teclas 1–7: frontal, lateral izquierdo,
lateral derecho, trasera, tres cuartos, superior y rostro. Botón derecho y arrastre
giran la cámara; la rueda cambia el encuadre; R recupera tres cuartos.
En Blender, las cámaras `Review` permiten revisar los mismos ángulos.

## Reconstrucción

Desde la raíz del repositorio:

```sh
blender -b -t 6 --python tools/characters/build_aren_v2.py
```

El generador reconstruye y **sobrescribe únicamente esta entrega experimental**,
incluido el `.blend`; guardar las modificaciones manuales con otro nombre antes
de repetirlo. `-- --quick` reduce las muestras y renderiza frontal, rostro, tres
cuartos, lateral izquierdo y trasera. Las imágenes de revisión y diagnósticos se guardan en `work/aren-v2/`,
fuera de Git. `-- --no-render` reconstruye los recursos sin generar imágenes.
La fuente FBX, el modelo compuesto y los clips originales se leen
como referencias y no se escriben.
