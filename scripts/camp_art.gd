extends RefCounted
## Data-only building dimensions and seeded layout used by the 3D world.
static var DEFINITIONS := [
 {"name":"Choza","file":"hut_01.png","size":Vector2(280,233),"door":Vector2(0.643,0.854),"opening":PackedVector2Array([Vector2(0.535,0.62),Vector2(0.699,0.57),Vector2(0.70,0.89),Vector2(0.54,0.92)])},
 {"name":"Refugio comunal","file":"camp_01.png","size":Vector2(325,260),"door":Vector2(0.66,0.9),"opening":PackedVector2Array([Vector2(0.49,0.59),Vector2(0.57,0.47),Vector2(0.88,0.54),Vector2(0.86,0.80),Vector2(0.54,0.91),Vector2(0.44,0.81)])},
 {"name":"Cabaña primitiva","file":"camp_02.png","size":Vector2(278,240),"door":Vector2(0.40,0.83),"opening":PackedVector2Array([Vector2(0.30,0.47),Vector2(0.50,0.53),Vector2(0.51,0.89),Vector2(0.28,0.85)])},
 {"name":"Cabaña con cama","file":"camp_03.png","size":Vector2(266,250),"door":Vector2(0.42,0.88),"opening":PackedVector2Array([Vector2(0.29,0.53),Vector2(0.46,0.59),Vector2(0.52,0.87),Vector2(0.28,0.86)])},
 {"name":"Taller primitivo","file":"camp_04.png","size":Vector2(313,260),"door":Vector2(0.70,0.91),"opening":PackedVector2Array([Vector2(0.54,0.57),Vector2(0.73,0.59),Vector2(0.82,0.78),Vector2(0.74,0.90),Vector2(0.53,0.89)])},
 {"name":"Zona comunal","file":"camp_05.png","size":Vector2(332,260),"door":Vector2(0.53,0.96),"opening":PackedVector2Array([Vector2(0.41,0.50),Vector2(0.61,0.53),Vector2(0.75,0.77),Vector2(0.53,0.94),Vector2(0.27,0.74)])},
]
static func layout() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 var points := [Vector2(-250,-120),Vector2(-962,-120),Vector2(462,-120),Vector2(-250,520),Vector2(-962,520),Vector2(462,520)]
 for i in DEFINITIONS.size():
  var record: Dictionary = DEFINITIONS[i]
  var rect := Rect2(points[i]+Vector2(-record.size.x/2,17-record.size.y),record.size)
  var door: Vector2 = points[i]+Vector2(40,-17) if i == 0 else rect.position+record.door*rect.size-Vector2(0,17)
  var footprint := Rect2(rect.position+Vector2(rect.size.x*0.10,rect.size.y*0.88),Vector2(rect.size.x*0.80,rect.size.y*0.10))
  var walls: Array[Rect2] = []
  var left := clampf(door.x-26,footprint.position.x,footprint.end.x)
  var right := clampf(door.x+26,left,footprint.end.x)
  walls.append(Rect2(footprint.position,Vector2(left-footprint.position.x,footprint.size.y)))
  walls.append(Rect2(Vector2(right,footprint.position.y),Vector2(footprint.end.x-right,footprint.size.y)))
  
  result.append({"id":i,"base":points[i],"rect":rect,"door":door,"footprint":footprint,"walls":walls})
 return result
