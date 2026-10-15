extends SceneTree
## Project the woven vest and its leaves around the actual imported torso.
const Armor=preload("res://scripts/prototype_3d/leaf_armor.gd")
const Profile=preload("res://scripts/prototype_3d/meshy_body_profile.gd")
const DEST="res://assets/characters/prototype_3d/meshy/leaf_armor.res"
func _initialize():call_deferred("run")
func run():
 var source:Mesh=load("res://assets/characters/prototype_3d/meshy/survivor_skin.res")
 var original:=source.surface_get_arrays(0)
 var points:PackedVector3Array=original[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=original[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=original[Mesh.ARRAY_WEIGHTS]
 var radii:Dictionary={}
 for i in points.size():
  var p:=points[i]
  if p.y<28 or p.y>52.5:continue
  var body_weight:=0.0
  for slot in 4:
   if bones[i*4+slot] in [0,1,2]:body_weight+=weights[i*4+slot]
  if body_weight<0.5:continue
  var planar:=Vector2(p.x,p.z-Profile.center_z(p.y))
  var angle:=fposmod(atan2(planar.x,planar.y),TAU)
  var cell:=Vector2i(roundi(p.y*4),roundi(angle/TAU*180)%180)
  radii[cell]=maxf(float(radii.get(cell,0.0)),planar.length())
 Armor.build_procedural()
 var arrays:=Armor.shared_mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 for i in vertices.size():
  var p:=vertices[i];var planar:=Vector2(p.x,p.z-Profile.center_z(p.y))
  if planar.length()<0.001:continue
  var unit:=planar.normalized();var angle:=fposmod(atan2(planar.x,planar.y),TAU)
  var cell:=Vector2i(roundi(p.y*4),roundi(angle/TAU*180)%180)
  var radius:=0.0
  for dy in range(-2,3):
   for da in range(-3,4):radius=maxf(radius,float(radii.get(Vector2i(cell.x+dy,posmod(cell.y+da,180)),0.0)))
  if radius==0:continue
  var size:=Profile.radius(p.y)
  var ellipse_radius:=1.0/sqrt(pow(unit.x/size.x,2)+pow(unit.y/size.y,2))
  var distance:=radius+clampf(planar.length()-ellipse_radius,0.24,1.1)
  vertices[i]=Vector3(unit.x*distance,p.y,Profile.center_z(p.y)+unit.y*distance)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var surface:=SurfaceTool.new();surface.create_from(mesh,0);surface.generate_normals()
 mesh=surface.commit();mesh.surface_set_material(0,Armor.shared_material)
 assert(ResourceSaver.save(mesh,DEST,ResourceSaver.FLAG_COMPRESS)==OK)
 print("PASS: leaf armor fitted to the imported torso: ",vertices.size()," vertices")
 quit()
