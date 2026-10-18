extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():
 var source:Mesh=load("res://assets/characters/prototype_3d/meshy/survivor_skin.res")
 var derived:Mesh=load("res://assets/characters/prototype_3d/meshy/survivor_axilla.res")
 var a:=source.surface_get_arrays(0);var b:=derived.surface_get_arrays(0)
 var count:int=a[Mesh.ARRAY_VERTEX].size()
 for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV]:
  require(a[channel].to_byte_array()==b[channel].slice(0,count).to_byte_array(),"Support loops preserve every original position and UV")
 require(b[Mesh.ARRAY_VERTEX].size()>count and b[Mesh.ARRAY_VERTEX].size()<count*1.04,"Axillary refinement is local")
 for i in range(count,b[Mesh.ARRAY_VERTEX].size()):
  var p:Vector3=b[Mesh.ARRAY_VERTEX][i]
  require(p.y>39 and p.y<49 and absf(p.x)<8.8,"New vertices remain near the two axillary folds")
  var total:=0.0
  for slot in 4:
   total+=b[Mesh.ARRAY_WEIGHTS][i*4+slot]
   require(b[Mesh.ARRAY_BONES][i*4+slot]<24,"Support surface uses the existing rig")
  require(absf(total-1)<.0001,"New skin weights are normalized")
 require(absf(area(a)-area(b))<.02,"Rest surface area is preserved by subdivision; no overlay sheet is added")
 require(derived.get_meta("source_skin_sha256")==FileAccess.get_sha256(source.resource_path),"Derived surface records its exact source")
 print("%s: %d axillary locality, rest geometry, UV and skin checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
func area(arrays:Array) -> float:
 var v:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var total:=0.0
 for i in range(0,ids.size(),3):total+=(v[ids[i+1]]-v[ids[i]]).cross(v[ids[i+2]]-v[ids[i]]).length()*.5
 return total
