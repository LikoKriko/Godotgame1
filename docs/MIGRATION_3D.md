# Migración 2D → 3D: alcance y revisión

El usuario autoriza continuar sin comprobaciones suyas entre cambios. Las pruebas
necesarias se realizan durante la integración. Después de migrar **todo** lo que
ya existía, se hará una fase dedicada a localizar errores, corregirlos y pulir
la experiencia, antes de incorporar sistemas nuevos. No adelantar el sistema de
vínculo/confianza: [PDF original](design/Day_Zero_Sistema_de_Confianza_y_Marcas_de_Afinidad.pdf).

## Integrado

- Anatomía, skinning, ropa y catálogo de gestos del superviviente.
- Cámara sobre el hombro, física de caminar/correr/agacharse/deslizar/saltar.
- Hacha y árboles de prueba, contactos cercanos y desgaste correcto.
- Enemigo joven: modelo/rig, acciones, memoria y rutinas; parry y stun.
- HUD, tamaños, correr automático y ventanas integradas sin cursor personalizado.
- Inventario/arrastre/acceso rápido físico, reparación, creación con reserva,
  habilidades/perks, catálogo de pruebas y fuentes de experiencia registradas.
- Nutrición y ciclo de 16 minutos; reaparición y reinicio de progreso definido.
- Iconos 256×256; diseños ausentes señalados con un símbolo provisional.
- Terreno 3D por chunks con las cuatro texturas, seed, transiciones y caché;
  consultas de tipo/densidad y zonas de suelo desnudo junto a árboles de prueba.
  El mapa muestra las regiones de terreno de esa misma semilla.

## Pendiente de trasladar del juego 2D

1. Modelos de los otros objetos, agarres visibles y acciones completas de espada,
   pico, arco/flechas, botella y comida. Sus poses y anclajes ya están preparados.
   Vestimenta de hojas sobre el modelo y retrato, respetando torso y hombros.
2. Conectar caminos, agua, césped, árboles originales agrupados, rocas, bardana,
   arbolitos y elevaciones al terreno por chunks ya trasladado. Reutilizar la
   semilla, consultas y reglas de distribución, adaptando sus colisiones al 3D.
3. Recolección E, objetos en suelo, rellenado de botellas, colocación de mesa,
   creación por estación, campamento y edificios. Los interiores comparten el
   espacio exterior: carga progresiva por proximidad y descarga con histéresis;
   no se cambian pantallas. El componente `building_stream.gd` ya prepara esto.
4. Cuerpos saqueables y su inventario, objetos arrojados y persistencia del mundo.
5. Menú principal completo, nueva partida, guardado manual/continuar en un formato
   3D separado y pantalla de carga con progreso real. Ajustes restantes adecuados
   al renderizador 3D; no reintroducir el cambio de resolución que rompía el cursor.
6. Revisar que cada interacción del 2D tenga equivalente, además de animaciones,
   sombras, colisiones, costes, cancelación, pausas y reaparición.

## Decisiones temporales para aclarar en la próxima sesión

- Los puños conservan por ahora el daño base cero del inventario original; no
  inventar una cifra de combate. El daño del hacha al joven sigue siendo 1.
- Tras perder de vista al jugador, el joven busca 2 s en la última posición;
  sus cambios de postura duran 0,28 s. La memoria se descarta al llegar, no al
  perder visión. Estos parámetros son ajustables sin cambiar la estructura.
- Las poses virtuales del catálogo no implican que un objeto ya tenga modelo o
  mecánica en la partida 3D. Los espacios de armadura todavía no alteran el cuerpo.
- No inventar recetas, misiones, logros ni recompensas de experiencia. El botón de
  nivel del catálogo es únicamente una herramienta de pruebas.

## Barrido final, cuando esté todo migrado

Recorrer una partida completa: generar/cargar, explorar sin cortes, recolectar,
crear/cancelar/reparar, equipar y usar cada categoría, combatir/parry/morir,
saquear, entrar/salir de edificios y guardar/continuar. Revisar ratón y botones
con diferentes tamaños de ventana, estados superpuestos y cancelaciones. Medir
coste de chunks, memoria de recursos y personajes activos; optimizar manteniendo
el resultado visual. Dedicar esta fase a correcciones, sin añadir contenido nuevo.

## Edificios: cambio de alcance aprobado

El interior y el exterior pertenecen al mismo mundo 3D. La instrucción anterior
de habitaciones en pantallas separadas queda sustituida. `building_stream.gd`
solicita escenas de fragmentos mediante carga en segundo plano, instancia con
presupuesto por frame y solo habilita la entrada cuando termina. El interior
ocupado permanece cargado; al alejarse se liberan nodos y recursos propios.

Distancias temporales configurables, medidas desde la puerta: empezar a 18 m,
prioridad de finalización a 3 m y descargar a 26 m. Presupuesto normal 2 ms por
frame y cercano 6 ms. Estos son valores de arranque para aclarar/medir con los
modelos reales del campamento; todavía no hay edificios colocados en este mapa.
Separar el contenido en escenas pequeñas, porque instanciar un fragmento muy
grande no se puede interrumpir. Los exteriores opacos ocultarán el interior;
no convertirlo en un viewport ni teletransportar al cruzar una puerta.
