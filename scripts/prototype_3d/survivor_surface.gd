extends RefCounted
## Anatomical landmarks measured on the supplied front/back references.
## Each vector is (author height, image row, left silhouette, right silhouette).
## Upper chest landmarks exclude the arms, which have their own geometry/UVs.
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
const PIXELS_PER_UNIT:=21.1
const FRONT=[Vector4(29.4,600,413,600),Vector4(31,580,416,591),Vector4(33,540,425,582),Vector4(35,510,421,585),Vector4(37,470,404,599),Vector4(39,440,397,606),Vector4(41,405,390,613),Vector4(42,385,380,624),Vector4(43,365,367,637),Vector4(44.5,345,350,653),Vector4(45.7,332,357,646),Vector4(46.25,315,380,626),Vector4(47,300,423,582),Vector4(47.65,285,451,553),Vector4(49.5,278,453,552)]
const BACK=[Vector4(29.4,575,440,625),Vector4(31,555,448,615),Vector4(33,520,453,610),Vector4(35,490,446,616),Vector4(37,455,435,625),Vector4(39,425,425,637),Vector4(41,395,416,649),Vector4(42,380,404,660),Vector4(43,365,399,663),Vector4(44.5,345,373,690),Vector4(45.7,330,376,684),Vector4(46.25,310,400,660),Vector4(47,290,450,611),Vector4(47.65,275,476,592),Vector4(49.5,260,490,577)]
# Actual body depth is independent of the paintings. Elliptical rib cage,
# narrow obliques and a rounded pelvis, with no flat rectangular side panels.
const DEPTHS=[Vector2(29.4,2.75),Vector2(31,2.58),Vector2(33,2.55),Vector2(35,2.86),Vector2(37,3.20),Vector2(39,3.55),Vector2(41,3.72),Vector2(43,3.25),Vector2(44.5,2.95),Vector2(45.7,2.50),Vector2(47,1.85),Vector2(49.5,1.80)]
const PELVIS=[Vector3(24.0,5.0,2.95),Vector3(25.3,5.22,3.05),Vector3(26.5,5.26,3.12),Vector3(27.7,5.08,3.10),Vector3(28.7,4.88,3.02),Vector3(29.4,4.68,2.90)]

static func landmark(y:float,front:bool) -> Vector4:
 var values:Array=FRONT if front else BACK
 for i in values.size()-1:
  if y<=values[i+1].x:
   var t:=clampf((y-values[i].x)/(values[i+1].x-values[i].x),0,1)
   return (values[i] as Vector4).lerp(values[i+1],t)
 return values[-1]
static func radius(y:float) -> Vector2:
 var a:=landmark(y,true);var b:=landmark(y,false)
 var width:=((a.w-a.z)+(b.w-b.z))*0.25/PIXELS_PER_UNIT
 var depth:float=DEPTHS[-1].y
 for i in DEPTHS.size()-1:
  if y<=DEPTHS[i+1].x:
   depth=lerpf(DEPTHS[i].y,DEPTHS[i+1].y,clampf((y-DEPTHS[i].x)/(DEPTHS[i+1].x-DEPTHS[i].x),0,1));break
 return Vector2(width,depth)
static func pelvis_radius(y:float) -> Vector2:
 for i in PELVIS.size()-1:
  if y<=PELVIS[i+1].x:
   var p:Vector3=(PELVIS[i] as Vector3).lerp(PELVIS[i+1],clampf((y-PELVIS[i].x)/(PELVIS[i+1].x-PELVIS[i].x),0,1))
   return Vector2(p.y,p.z)
 return Vector2(PELVIS[-1].y,PELVIS[-1].z)
static func torso_uv(point:Vector3,front:bool) -> Vector2:
 var mark:=landmark(point.y,front);var size:=radius(point.y)
 var unit_x:=clampf(point.x/size.x,-1,1)
 if not front:unit_x=-unit_x
 # Eight-pixel inset avoids projecting the painted dark contour/studio onto sides.
 var x:=lerpf(mark.z+8,mark.w-8,unit_x*.5+.5)
 return Vector2(x/1086.0,mark.y/1448.0)
static func pelvis_uv(point:Vector3,front:bool) -> Vector2:
 var r:=pelvis_radius(point.y);var x:=point.x/r.x
 if not front:x=-x
 var image_y:float=(610 if front else 585)+(29.4-point.y)*(21.5 if front else 23.3)
 var half:=lerpf(101,121,(1-smoothstep(23.0,29.4,point.y)))
 return Vector2(((506 if front else 535)+clampf(x,-1,1)*(half-3))/1086.0,image_y/1448.0)
static func limb_uv(point:Vector3,front:bool,cloth:bool=false) -> Vector2:
 var x:float=point.x if front else -point.x
 var y:float=(610 if front else 585)+(29.4-point.y)*(21.5 if front else 23.3) if cloth else (610 if front else 585)-(point.y-29.4)*17.4
 return Vector2(((506 if front else 535)+x*PIXELS_PER_UNIT)/1086.0,y/1448.0)

# Pixel bounds exclude the studio and the neighbouring bare arms. Each leg
# unwraps around its own silhouette; the inner gap is not painted onto cloth.
const PANTS_FRONT_LEFT=[Vector3(610,399,505),Vector3(650,397,505),Vector3(690,389,505),Vector3(730,385,485),Vector3(770,381,484),Vector3(810,376,484),Vector3(840,376,482)]
const PANTS_FRONT_RIGHT=[Vector3(610,506,609),Vector3(650,506,613),Vector3(690,506,621),Vector3(730,528,627),Vector3(770,523,632),Vector3(810,528,635),Vector3(840,527,636)]
const PANTS_BACK_LEFT=[Vector3(610,424,534),Vector3(650,420,534),Vector3(690,413,534),Vector3(730,407,510),Vector3(770,402,508),Vector3(810,395,505),Vector3(840,394,508)]
const PANTS_BACK_RIGHT=[Vector3(610,535,637),Vector3(650,535,643),Vector3(690,535,650),Vector3(730,546,655),Vector3(770,544,661),Vector3(810,548,667),Vector3(840,550,667)]
static func leg_cloth_uv(coordinate:Vector2,side:int,front:bool) -> Vector2:
 var row:float=(610 if front else 585)+(29.4-coordinate.y)*(21.5 if front else 23.3)
 row=clampf(row,620,820)
 var photo_side:=side if front else 1-side
 var values:Array=(PANTS_FRONT_LEFT if photo_side==0 else PANTS_FRONT_RIGHT) if front else (PANTS_BACK_LEFT if photo_side==0 else PANTS_BACK_RIGHT)
 var mark:Vector3=values[-1]
 for i in values.size()-1:
  if row<=values[i+1].x:
   mark=(values[i] as Vector3).lerp(values[i+1],clampf((row-values[i].x)/(values[i+1].x-values[i].x),0,1));break
 var across:float=coordinate.x if front else -coordinate.x
 return Vector2(lerpf(mark.y+8,mark.z-8,across*.5+.5)/1086.0,row/1448.0)
