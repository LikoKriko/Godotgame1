# Materiales del superviviente 3D

`pixel_materials.png` reemplaza el atlas pintado suavizado de la primera prueba.
Cuatro regiones iguales: piel, tela, pelo y cuerda. Generado y adaptado a partir
de la paleta original con acabado pixel art de alta resolución. La malla asigna
UV2 en reposo y conserva las coordenadas al animarse; no se reproyecta la textura.

El shader limita el contraste, conserva los colores de ojos/marca facial y usa
nearest con mipmaps para mantener píxeles definidos y reducir aliasing al alejar
la cámara. Las definiciones de torso son discretas, sin músculos separados.
El contorno fino escala con el cuerpo. La regla de acabado aplica también a los
materiales futuros y se encuentra en AGENTS.md.
