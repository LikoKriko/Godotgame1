extends RefCounted
## Conservative torso envelope measured on the imported mesh at 64 units.
## Vector4(height, half width, rear Z, front Z); includes the waist cord.
const SECTIONS=[Vector4(29,5.1,-0.91,5.11),Vector4(31,5.6,-1.95,6.67),Vector4(33,5.3,-1.97,6.67),Vector4(35,5.14,-1.49,6.61),Vector4(37,5.2,-0.5,5.49),Vector4(39,5.5,-0.9,5.49),Vector4(41,6.0,-1.0,5.71),Vector4(43,6.3,-1.28,5.79),Vector4(45,6.2,-2.2,5.84),Vector4(47,5.6,-2.38,5.66),Vector4(49,4.2,-2.03,4.76),Vector4(50,3.0,-1.53,3.94),Vector4(51,2.1,-0.93,3.43),Vector4(52,1.95,-0.31,3.52)]
static func section(y:float) -> Vector4:
 for i in SECTIONS.size()-1:
  if y<=SECTIONS[i+1].x:return (SECTIONS[i] as Vector4).lerp(SECTIONS[i+1],clampf((y-SECTIONS[i].x)/(SECTIONS[i+1].x-SECTIONS[i].x),0,1))
 return SECTIONS[-1]
static func radius(y:float) -> Vector2:
 var s:=section(y);return Vector2(s.y,(s.w-s.z)*0.5)
static func center_z(y:float) -> float:
 var s:=section(y);return (s.w+s.z)*0.5
