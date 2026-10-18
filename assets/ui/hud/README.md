# Marcos del HUD

Imágenes originales del release [Nuevos_Marcos](https://github.com/LikoKriko/Godotgame1/releases/tag/Nuevos_Marcos), archivo `DayZero_Marcos.zip`. Los PNG conservan sus nombres, transparencia y contenido originales.

| Archivo | Uso en partida |
| --- | --- |
| Vida.png | Salud |
| Kcal.png | Calorías |
| Agua.png | Hidratación |
| Peso.png | Peso |
| DiayHora.png | Día y hora |
| Nivel.png | Nivel y contador opcional de FPS |
| Configuración.png | Botón de ajustes |
| Pausa.png | Botón de pausa |
| Mapa.png | Minimapa y acceso al mapa completo |
| Habilidades.png | Barra de habilidades |
| Inventario.png | Seis accesos rápidos del inventario |
| Pendiente1.png | Reservado, sin asignación ni carga en el HUD |
| Pendiente 2.png | Reservado, sin asignación ni carga en el HUD |

`scripts/prototype_3d/hud_frames.gd` centraliza estas texturas. Los seis accesos rápidos comparten regiones de la imagen original; cada región permite destacar el objeto equipado. Los marcos completos conservan su proporción y utilizan filtrado lineal. Los cinco tamaños del HUD escalan conjuntamente marcos, textos y zonas de clic. Los iconos de objetos mantienen su propio filtrado.

Los marcos de los menús y ventanas se gestionan mediante el estilo compartido de la interfaz; estas imágenes corresponden al HUD durante la partida.
