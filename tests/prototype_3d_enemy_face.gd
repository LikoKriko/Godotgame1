extends SceneTree
const Model=preload("res://scripts/prototype_3d/young_model.gd")
const Face=preload("res://scripts/prototype_3d/young_face.gd")
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func area(arrays:Array) -> float:
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var sum:=0.0
 for i in range(0,indices.size(),3):sum+=(points[indices[i+1]]-points[indices[i]]).cross(points[indices[i+2]]-points[indices[i]]).length()*.5
 return sum
func run():
 var actor:=Model.new();var second:=Model.new();root.add_child(actor);root.add_child(second)
 var original:Mesh=Model.IMPORTED_SKIN;var mesh:ArrayMesh=actor.mesh_node.mesh
 var source:=original.surface_get_arrays(0);var arrays:=mesh.surface_get_arrays(0)
 var count:int=source[Mesh.ARRAY_VERTEX].size()
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
  var expected:PackedByteArray=source[channel].to_byte_array();var actual:PackedByteArray=arrays[channel].to_byte_array()
  require(actual.slice(0,expected.size())==expected,"Source vertex, UV and binding prefix remains unchanged: "+str(channel))
 require(mesh==second.mesh_node.mesh and mesh!=original,"Derived face is cached without editing the source asset")
 require(mesh.surface_get_material(0)==original.surface_get_material(0),"Original material and maps remain intact")
 require(mesh.get_surface_count()==2,"Cavity is a surface of the same skinned mesh")
 require(actor.get_child_count()==1 and actor.skeleton.get_child_count()==1,"No separate floating mouth object exists")
 require(mesh.get_aabb().is_equal_approx(original.get_aabb()),"Facial animation preserves model normalization and proportions")
 require(Face.seam_segments.size()>0,"Lip opening subdivides the original continuous skin")
 require(absf(area(arrays)-area(source))<.01,"Closed lip triangulation preserves the complete original surface")
 require(mesh.get_blend_shape_count()==5,"Exactly five facial muscle controls")
 require(mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED,"Absolute facial shapes use a matching base weight and preserve shading")
 for i in 5:require(mesh.get_blend_shape_name(i)==Face.CONTROLS[i],"Bilateral jaw, bilateral cheekbones and nose lift")
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var shapes:=mesh.surface_get_blend_shape_arrays(0)
 for shape in shapes:
  var normal_safe:=true;var tangent_safe:=true
  for i in vertices.size():normal_safe=normal_safe and shape[Mesh.ARRAY_NORMAL][i].distance_to(arrays[Mesh.ARRAY_NORMAL][i])<.0002
  for i in vertices.size()*4:tangent_safe=tangent_safe and absf(shape[Mesh.ARRAY_TANGENT][i]-arrays[Mesh.ARRAY_TANGENT][i])<.0001
  require(normal_safe and tangent_safe,"Encoded facial directions preserve source shading across the whole model")
 var neck_safe:=true;var affected:=PackedInt32Array();affected.resize(5)
 for i in vertices.size():
  for muscle in 5:
   var d:Vector3=shapes[muscle][Mesh.ARRAY_VERTEX][i]-vertices[i]
   if d.length()>.00001:affected[muscle]+=1
   if vertices[i].z<=12 or vertices[i].y>=22:neck_safe=neck_safe and d.length()<.000001
 require(neck_safe,"Neck, head/body junction and entire body remain outside every mask")
 for muscle in 5:require(affected[muscle]>5 and affected[muscle]<count*.15,"Each muscle has a small, nonempty local influence")
 var tusk_counts:=[0,0,0,0]
 for i in count:
  var p:=vertices[i];var side:=0 if p.x<0 else 1
  var upper:=absf(p.x)>5.8 and absf(p.x)<6.8 and p.y>7 and p.y<12.8 and p.z>13.5 and p.z<16.5
  var lower:=absf(p.x)>3.2 and absf(p.x)<8.6 and p.y>14 and p.y<18.3 and p.z>15.2
  if not upper and not lower:continue
  var total:=Vector3.ZERO
  for muscle in 5:total+=(shapes[muscle][Mesh.ARRAY_VERTEX][i]-p)/Face.CONTROL_SCALE
  var expected:=Vector3.ZERO if upper else Basis(Vector3.RIGHT,.035)*(p-Face.PIVOT)+Face.PIVOT-p
  require(total.distance_to(expected)<.00001,"Upper tusks stay fixed; lower tusks rotate rigidly with jaw")
  tusk_counts[side+(0 if upper else 2)]+=1
 for number in tusk_counts:require(number>3,"All four tusks are covered by the anatomical checks")
 var interior:=mesh.surface_get_arrays(1);var inner_shapes:=mesh.surface_get_blend_shape_arrays(1)
 var material:StandardMaterial3D=mesh.surface_get_material(1)
 require(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST,"Simple mouth texture uses crisp pixels")
 var image:=material.albedo_texture.get_image();var colors:Dictionary={}
 for y in image.get_height():
  for x in image.get_width():colors[image.get_pixel(x,y).to_html()]=true
 require(colors.size()==5,"Interior has five controlled dark snout tones")
 var worst_area:=1.0;var worst_edge:=1.0
 for frame in 65:
  var t:=frame/64.0;var expression:=Face.weights(t*Face.SECONDS)
  var deformed:=vertices.duplicate()
  for muscle in 5:
   for i in vertices.size():deformed[i]+=(shapes[muscle][Mesh.ARRAY_VERTEX][i]-vertices[i])*expression[muscle]
  var no_inversion:=true;var area_safe:=true;var edge_safe:=true
  for triangle in range(0,ids.size(),3):
   var a:=vertices[ids[triangle]];var b:=vertices[ids[triangle+1]];var c:=vertices[ids[triangle+2]]
   var x:=deformed[ids[triangle]];var y:=deformed[ids[triangle+1]];var z:=deformed[ids[triangle+2]]
   var normal:Vector3=(b-a).cross(c-a);var actual:Vector3=(y-x).cross(z-x)
   if normal.length()<.00001:continue
   no_inversion=no_inversion and normal.dot(actual)>0
   var ratio:=actual.length()/normal.length();worst_area=maxf(worst_area,ratio)
   area_safe=area_safe and ratio>.70 and ratio<1.35
   for edge in [[a,b,x,y],[b,c,y,z],[c,a,z,x]]:
    var length:float=edge[0].distance_to(edge[1])
    if length<.00001:continue
    var scale:float=edge[2].distance_to(edge[3])/length;worst_edge=maxf(worst_edge,scale)
    edge_safe=edge_safe and scale>.80 and scale<1.28
  require(no_inversion,"No facial triangle inverts during the complete gesture")
  require(area_safe and edge_safe,"Texture distortion remains below previous area/edge limits")
  for segment in Face.seam_segments.size():
   for row in 5:
    var v:=row/4.0
    for end in 2:
     var id:=segment*10+row*2+end
     var low:int=Face.seam_segments[segment][0][end];var high:int=Face.seam_segments[segment][1][end]
     var point:Vector3=interior[Mesh.ARRAY_VERTEX][id]
     for muscle in 5:point+=(inner_shapes[muscle][Mesh.ARRAY_VERTEX][id]-interior[Mesh.ARRAY_VERTEX][id])*expression[muscle]
     var rim:=deformed[high].lerp(deformed[low],v)
     require(point.distance_to(rim+Vector3(0,0,-1.35*sin(v*PI)))<.00001,"Lining is recessed and its two rims meet the lip exactly")
     for slot in 4:
      require(interior[Mesh.ARRAY_BONES][id*4+slot]==arrays[Mesh.ARRAY_BONES][low*4+slot] and absf(interior[Mesh.ARRAY_WEIGHTS][id*4+slot]-arrays[Mesh.ARRAY_WEIGHTS][low*4+slot])<.00001,"Lining and lip use identical skin bindings")
 for state in [&"attack",&"hook"]:
  actor.animate(&"idle",0)
  var dt:=1.0/120
  for step in 240:
   var seconds:=step*dt
   # Returning to idle after the body attack must not truncate the face.
   actor.animate(state if seconds<Motion.seconds(state) else &"idle",minf(1,seconds/Motion.seconds(state)),true,dt)
   require(absf(actor.facial_elapsed-minf(2,(step+1)*dt))<.0001,"Facial clock runs for two seconds independently of body duration")
   var expected:=Face.weights((step+1)*dt)
   for muscle in 5:require(absf(actor.mesh_node.get_blend_shape_value(muscle)-expected[muscle])<.0001,"All five controls follow the independent clock")
  require(actor.facial_open<.00001,"Gesture closes at exactly two seconds")
 require(Motion.seconds(&"attack")==1 and Motion.seconds(&"hook")==1.2,"Body attack durations are unchanged")
 actor.animate(&"attack",.4);second.animate(&"idle",0)
 require(actor.facial_open>.99 and second.facial_open==0,"Every enemy retains an independent expression")
 actor.animate(&"hook",0,true,.01)
 require(actor.facial_elapsed>.8,"A second attack cannot restart an unfinished facial gesture")
 actor.animate(&"stun_fall",0,true,1.0/60)
 require(actor.facial_open>0 and actor.facial_open<1,"Interruption closes the face gradually")
 for step in 12:actor.animate(&"stun_hold",0,true,1.0/60)
 require(actor.facial_open==0,"Stunned/dead creatures return to a closed mouth")
 print("Maximum texture area ratio ",worst_area,"; maximum edge ratio ",worst_edge)
 actor.free();second.free();print("%s: %d face, lip seam, cavity, tusks, texture and independent timing checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
