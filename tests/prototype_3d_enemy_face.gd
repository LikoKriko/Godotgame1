extends SceneTree
const Model=preload("res://scripts/prototype_3d/young_model.gd")
const Face=preload("res://scripts/prototype_3d/young_face.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var actor:=Model.new();var second:=Model.new();root.add_child(actor);root.add_child(second)
 var original:Mesh=Model.IMPORTED_SKIN;var mesh:ArrayMesh=actor.mesh_node.mesh
 var source:=original.surface_get_arrays(0);var arrays:=mesh.surface_get_arrays(0)
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
  require(arrays[channel].to_byte_array()==source[channel].to_byte_array(),"Rest geometry, UVs, normals and skin bindings remain byte-identical: "+str(channel))
 require(mesh==second.mesh_node.mesh and mesh!=original,"Facial blend shape is cached without changing the source asset")
 require(mesh.surface_get_material(0)==original.surface_get_material(0),"Original textures and material stay intact")
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var delta:PackedVector3Array=mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
 var neck_checked:=0
 for i in vertices.size():
  var p:=vertices[i]
  if p.z<=12.8 or p.y>=18 or absf(p.x)>=6.5:
   require(delta[i].length()<.000001,"Facial muscle masks leave the neck, head seam and body fixed");neck_checked+=1
  require(delta[i].length()<.5,"Facial displacement remains small")
 require(neck_checked>vertices.size()*.8,"At least eighty percent of the model is untouched by facial muscles")
 for triangle in range(0,ids.size(),3):
  var a:=vertices[ids[triangle]];var b:=vertices[ids[triangle+1]];var c:=vertices[ids[triangle+2]]
  var x:=a+delta[ids[triangle]];var y:=b+delta[ids[triangle+1]];var z:=c+delta[ids[triangle+2]]
  var normal:Vector3=(b-a).cross(c-a);var deformed:Vector3=(y-x).cross(z-x)
  require(normal.dot(deformed)>0,"Jaw opening cannot invert any source triangle")
  var ratio:=deformed.length()/maxf(.000001,normal.length())
  require(ratio>.70 and ratio<1.35,"Texture-area changes stay local and limited")
  for edge in [[a,b,x,y],[b,c,y,z],[c,a,z,x]]:
   var scale:float=(edge[2] as Vector3).distance_to(edge[3])/maxf(.000001,(edge[0] as Vector3).distance_to(edge[1]))
   require(scale>.80 and scale<1.28,"Texture edge stretch stays limited")
 for state in [&"attack",&"hook"]:
  for left in [false,true]:
   for frame in 65:
    var t:=frame/64.0;actor.animate(state,t,left)
    require(absf(actor.mesh_node.get_blend_shape_value(0)-Face.amount(state,t))<.00001,"Both attacks drive the same soft facial gesture")
    require(actor.mouth_interior.visible==(Face.amount(state,t)>.001),"Mouth interior is only shown with an opening")
    var head:Transform3D=actor.posed[1]*actor.rest[1].affine_inverse()
    require(actor.mouth_interior.position.distance_to(head*Face.MOUTH_CENTER)<.001,"Mouth stays attached to the moving head")
   actor.animate(state,.5,left)
   second.animate(&"idle",0,true)
   require(actor.facial_open>.99 and second.facial_open==0,"Facial expression is independent for every creature")
 for state in [&"idle",&"walk",&"sit",&"feed",&"sleep",&"corpse"]:
  actor.animate(state,.5,true);require(actor.facial_open==0 and not actor.mouth_interior.visible,"Other behaviours keep the neutral face")
 actor.animate(&"attack",.5,true)
 actor.animate(&"stun_fall",0,true,1.0/60)
 require(actor.facial_open>0 and actor.facial_open<1,"Interrupting the attack closes the mouth gradually")
 actor.free();second.free();print("%s: %d facial source fidelity, neck continuity, stretch, attack and interior checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
