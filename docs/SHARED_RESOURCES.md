# Recursos compartidos del juego 3D

| Recurso | Uso actual |
| --- | --- |
| `assets/items/` | Sprites y recortes de objetos; iconos del inventario y materiales de autoría |
| `assets/ui/` | Menú, HUD, inventario, marcos, botones y tipografía |
| Imágenes de bardana, césped y rocas | Texturas, perfiles y recortes usados por modelos, generación e iconos |
| `terreno1_claro_1.png`, `terreno1_claro_2.png`, `terreno1_oscuro_1.png` | Suelo general: claro principal, claro alternativo y zonas oscuras |
| `terreno1_claro_1_Path.png` | Caminos de tierra, incluido el camino inicial |
| `platform_*.png` | Máscaras de contorno para plataformas físicas 3D |
| `tree_sizes.json` | Dimensiones de árboles del generador |
| Inventario, recetas, nutrición, reloj, progresión y parry | Reglas compartidas del juego |
| `continuous_body_pose.gd` | Matemática de animación e IK |
| `terrain_sampler.gd` y generador por semilla | Distribución de terreno y recursos |
| `entregables/` | Originales y referencias artísticas de los departamentos |

El juego utiliza escenas y modelos 3D. Las imágenes planas de esta tabla siguen
siendo necesarias para su interfaz, texturas, iconos o generación. Conservarlas
hasta que sus usos tengan una sustitución integrada.

## Texturas del suelo

`terrain_profile.gd.texture_paths` asigna, por orden, claro principal,
oscuro, claro alternativo y camino. Los PNG de `assets/environment/imported/`
conservan los originales de `entregables/entorno/terreno/`, de 1254×1254 píxeles.
Las transiciones mezclan las tres texturas generales por las regiones de la
semilla. El cuarto tipo lógico del generador conserva sus reglas de recursos
y densidad; visualmente usa el suelo claro principal fuera de los caminos.

La imagen `_Path` se aplica mediante las máscaras de caminos existentes y del
camino inicial, en ambos materiales del terreno: inicial y con caché de biomas.
No se usa como una región aleatoria de suelo ni se recolorea con una paleta
artificial de tierra. La escala y mezcla compartidas entre chunks conservan
la continuidad del dibujo. El muestreo nearest mantiene los píxeles definidos;
los cuatro mapas de color se interpretan como sRGB para la iluminación.
