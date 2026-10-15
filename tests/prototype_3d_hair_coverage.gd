extends SceneTree
## Ray-test the visible head surface: hair must cover the rear scalp, including
## between locks. This catches caps that intersect the skull and reveal bald bands.
const Anatomy=preload("res://scripts/prototype_3d/survivor_anatomy.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 for angle in [-PI/2-0.45,-PI/2,-PI/2+0.45,PI/2]:
  for height in [50.8,51.5,52.1,52.6,53.2,54.5,56.0,58.8,60.0,61.0]:
   if angle>0 and height<58.8:continue # The forehead and face remain bare.
   var direction:=Vector3(cos(angle),0,sin(angle))
   var origin:=Anatomy.head(Vector3(0,height,0))+direction*20
   var nearest:=INF;var hair:=false
   for face in range(0,vertices.size(),3):
    if int(tags[face].x)!=3:continue
    var hit=Geometry3D.ray_intersects_triangle(origin,-direction,vertices[face],vertices[face+1],vertices[face+2])
    if hit==null:continue
    var distance:float=origin.distance_to(hit)
    if distance<nearest:
     nearest=distance;hair=colors[face].r<0.38 and colors[face].g<0.27
   checks+=1
   if not hair:
    failures+=1;push_error("Exposed scalp at angle %.2f, author height %.2f"%[angle,height])
 actor.free()
 print("%s: %d exterior scalp coverage rays"%["PASS" if failures==0 else "FAIL",checks])
 quit(1 if failures else 0)
