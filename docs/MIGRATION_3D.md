# Migración 2D → 3D: alcance y revisión

El usuario autoriza continuar sin comprobaciones suyas entre cambios. Las pruebas
necesarias se realizan durante la integración. Después de migrar **todo** lo que
ya existía, se hará una fase dedicada a localizar errores, corregirlos y pulir
la experiencia, antes de incorporar sistemas nuevos. No adelantar el sistema de
vínculo/confianza: [PDF original](design/Day_Zero_Sistema_de_Confianza_y_Marcas_de_Afinidad.pdf).

## Integrado

- Anatomía, skinning, ropa y catálogo de gestos del superviviente.
- Cámara sobre el hombro, física de caminar/correr/agacharse/deslizar/saltar.
- Hacha, pico y espada sólidos, con agarres, contacto por mira y desgaste según
  impacto. Arco con cuerda/flecha unidas a las manos, tensado de 0,5 s, munición
  separada, desgaste al tensar y proyectiles con colisión continua.
- Botella y alimentos visibles en mano. Beber/comer aplican consumo al terminar.
  Recogida con E y manos libres; botella rellenable con E sobre agua cercana.
- Armadura de hojas en cuerpo y retrato, unida al torso completo, sin protección.
- Distribución original por semilla: grupos de árboles, rocas con sus golpes y
  rendimientos, 24 bardanas, arbolitos, charcos, césped y cuatro elevaciones.
  Extracción correcta, rechazo de herramienta errónea y recogida con manos libres.
- Enemigo joven: modelo/rig, acciones, memoria y rutinas; parry y stun.
- HUD, tamaños, correr automático y ventanas integradas sin cursor personalizado.
- Inventario/arrastre/acceso rápido físico, reparación, creación con reserva,
  habilidades/perks, catálogo de pruebas y fuentes de experiencia registradas.
- Nutrición y ciclo de 16 minutos; reaparición y reinicio de progreso definido.
- Iconos 256×256; diseños ausentes señalados con un símbolo provisional.
- Terreno 3D por chunks con las cuatro texturas, seed, transiciones y caché;
  consultas de tipo/densidad, caminos y suelo desnudo junto a recursos.
  El mapa usa la misma semilla y los límites originales de 84×56 m.
- Campamento con seis exteriores 3D provisionales y habitaciones vacías que se
  cargan por proximidad sin cambiar de pantalla. Puertas de 1,5×2,2 m,
  oscurecimiento exterior al 70% y barrera que mantiene al enemigo fuera.
- Pantalla negra de generación con barra blanca ligada al avance de creación.
- Cadáver del joven accesible tras 2 s, ocho huecos en dos filas; Recoger y Tirar,
  contador real de mochila, recogida E con manos libres y conservación de usos
  y agua por objeto. Desaparición tras 180 s más la caída. El cuero sin refinar
  de prueba conserva el comportamiento del 2D.
- Mesa básica colocable con clic durante 3 s, personaje quieto, previsualización
  y barra verde; Esc cancela conservando el objeto. E abre las recetas de mesa,
  con iconos 256² y los mismos costes de sal/cuchillo y reservas que en el 2D.

- Menú principal 3D, confirmación integrada de nueva partida, guardado manual y
  Continuar desde disco. Una sola partida 3D separada del archivo 2D, validación
  versionada, escritura temporal verificada y copia de recuperación.
- Persistencia de recursos, mesas, criaturas/cadáveres, botín y objetos tirados,
  además de estado del personaje, progreso, reloj y nutrición. Carga del interior
  ocupado antes de reanudar. No se guardan golpes/consumos/proyectiles a medias.
- Configuración Juego/Gráficos/Audio aplicable al 3D; resolución y modo de pantalla
  permanecen bloqueados por el problema anterior del cursor.

## Pendiente de trasladar del juego 2D

1. Modelos de los objetos restantes: materiales y equipo aún provisional.
   Ampliar variantes y revisar el acabado de los modelos con el usuario al final.
2. Refinar los modelos provisionales del entorno y edificios para acercarlos a
   todas las siluetas originales. La distribución ya está conectada; los nueve
   diseños originales de árbol aún no tienen nueve modelos 3D específicos.
3. Sustituir la representación provisional de objetos arrojados (iconos en el
   mundo) por modelos pequeños donde corresponda.
4. Revisar que cada interacción del 2D tenga equivalente, además de animaciones,
   sombras, colisiones, costes, cancelación, pausas y reaparición.

## Decisiones temporales para aclarar en la próxima sesión

- Los puños conservan por ahora el daño base cero del inventario original; no
  inventar una cifra de combate. El daño del hacha al joven sigue siendo 1.
- Tras perder de vista al jugador, el joven busca 2 s en la última posición;
  sus cambios de postura duran 0,28 s. La memoria se descarta al llegar, no al
  perder visión. Estos parámetros son ajustables sin cambiar la estructura.
- Las familias de armas y los consumibles ya tienen modelos. Los materiales y
  objetos adicionales aún no están modelados; no confundir su presencia en el
  inventario con su migración al mundo. Solo la armadura de hojas cambia el cuerpo.
- Los modelos ambientales son una primera adaptación volumétrica: no dar por
  terminados los diseños de árboles, edificios y plantas solo por estar colocados.
  Los charcos aún no sustituyen lagos y las superficies de agua son simples.
- El usuario ha confirmado de nuevo que el PDF empieza después de **toda** la
  migración, aunque esta tanda de herramientas y armadura ya esté terminada.
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
modelos finales del campamento; ya se colocan los seis exteriores provisionales.
Separar el contenido en escenas pequeñas, porque instanciar un fragmento muy
grande no se puede interrumpir. Los exteriores opacos ocultarán el interior;
no convertirlo en un viewport ni teletransportar al cruzar una puerta.
