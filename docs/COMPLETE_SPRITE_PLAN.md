# Fotogramas completos

Decisiones confirmadas: cuerpo continuo con piel y ropa unidas, exportado como imágenes completas; 12 fotogramas de caminata en ocho direcciones; 16 de acción en 16 direcciones; seis para equipar y detenerse. Cada herramienta conserva su dibujo y comparte el movimiento de su categoría. La caminata base baja de 220 a 70 unidades por segundo. Sacar una herramienta dura 0,42 s (0,50 s para pico) y permite seguir caminando, corriendo o caminando agachado con fotogramas completos combinados.

`tools/continuous_actor.gd` construye el cuerpo de autoría con superficies continuas en brazos y piernas, ropa ligada a muslos/cadera y longitudes de huesos constantes. Hacha y pico tienen ambos agarres fijados al mismo mango. La flexión máxima del codo es de 130°. La preparación, aceleración, contacto y recuperación son distintos por categoría. El arco usa una cuerda deformable y una flecha que se libera en el contacto.

`tools/bake_complete_sprites.gd` renderiza el cuerpo con la herramienta y oculta las partes tapadas por la anatomía mediante profundidad. Produce atlas RGBA con celdas de 192×192 y un manifiesto de anclajes. Cabeza, cuello y cuerpo se exportan desde una sola malla; el rostro conserva las vistas pintadas, con piel armonizada a la misma paleta y una unión de cuello continua. El torso gira sobre la cadera; el cráneo acompaña la traslación y solo un 12% de la inclinación del cuello. La cabeza acompaña la inclinación del torso al correr, sin quedarse atrás ni estirar el cuello, y el descenso al agacharse y deslizarse. Caminar agachado tiene un ciclo propio de 12 fotogramas en ocho direcciones. Una máscara de torso y cabeza oculta herramientas en vistas superiores y laterales; también protege ambos brazos, cuerda y flecha del arco en las vistas superiores. La cuerda del arco queda orientada hacia el arquero tanto a derecha como a izquierda.

El juego reproduce estos fotogramas mediante `scripts/full_frame_avatar.gd`: no deforma ni monta rodillas, brazos o ropa en tiempo real. La sombra usa la misma imagen completa. El dibujo propio de cada herramienta se conserva en su atlas, identificado por ID; la categoría selecciona las poses de autoría.

La cabeza usa ocho vistas pintadas del atlas anterior de estilo original, con tamaño fijo y cuerpo proyectado en 16 orientaciones. No son 16 cabezas redibujadas ni una copia pixel a pixel de la referencia adjunta. La anatomía y el sombreado son estilizados, no una simulación muscular.

Las variantes de parada comienzan exactamente en el fotograma visible de marcha, incluso si se suelta durante el arranque. Hay doce entradas de parada desde caminar y seis desde arrancar. Los ciclos de uso comienzan y terminan en la postura de reposo de la herramienta equipada.

## Regenerar y comprobar

Con una pantalla gráfica disponible:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/bake_complete_sprites.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script tools/bake_complete_sprites.gd -- --armor burdock_armor
godot --headless --editor --path . --quit
godot --headless --path . --script tests/complete_sprite_pipeline.gd
godot --headless --path . --script tests/full_frame_runtime.gd
```

`--probe` genera una hoja interna de revisión; `--item axe` regenera únicamente un objeto. Para incorporar otro diseño, el actor admite `visual_override` con textura, agarre, contacto, segundo agarre y tamaño; debe exportarse una entrada propia del manifiesto. Nunca se sustituye su aspecto por el de otro objeto de la misma categoría.

Las pruebas revisan dimensiones, agarres, alternancia de piernas, continuidad exacta de transiciones y reproducción en el juego. `bow_arrow_exports.gd` comprueba que la flecha cargada conserva píxeles visibles durante la marcha, con y sin armadura, incluidos los atlas que se distribuyen. Son complementarias a jugar y revisar visualmente la sensación del movimiento.

La carrera tiene 12 poses propias por dirección, arranque y paradas de seis fotogramas. Shift mantenido activa velocidad ×1,6; Correr automáticamente se guarda en Juego. Control corriendo desliza, caminando/quieto agacha. Configuración tiene Juego, Gráficos y Audio.

El manifiesto versión 2 conserva solo 16 anclajes de liberación del arco. `--clips jump,crouch,slide,crouch_walk` permite corregir esas poses sin regenerar las secuencias restantes. Los contornos siguen la regla permanente de `AGENTS.md`.

Las poses `equip_walk`, `equip_run` y `equip_crouch_walk` combinan seis etapas de sacar el arma con doce fases del paso. Se almacenan en seis texturas pequeñas por clip, seleccionando ambos relojes en ejecución. La armadura de hojas usa la superficie reutilizable `torso_armor.gd`; `--armor burdock_armor` exporta todas las combinaciones de cuerpo y herramienta con ese torso. La pose `slide_jump` representa la salida del deslizamiento hacia un salto con inercia.
