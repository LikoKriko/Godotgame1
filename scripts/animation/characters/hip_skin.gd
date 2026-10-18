extends RefCounted
## One shared GPU skin, built once. Keep source vertices, UVs, binds and rig.
const DEFORMATION_RETAINED:=.40
static var meshes:Dictionary={}
static func smooth5(a:float,b:float,value:float) -> float:
 var t:=clampf((value-a)/(b-a),0,1)
 return t*t*t*(t*(t*6-15)+10)
static func support_mask(point:Vector3) -> float:
 # The front thigh must follow its own bone below the hip joint. A uniform
 # height mask bends the quadriceps a second time halfway down the muscle.
 var waist:=smooth5(32.7,34.5,point.y)
 var glute:=smooth5(27.5,31.5,point.y)*(1-smooth5(1.2,3.4,point.z))
 return (1-(1-waist)*(1-glute))*(1-smooth5(36,40,point.y))
static func stable_mesh(source:Mesh,skin:Skin,frame:Transform3D,hips_bone:int) -> ArrayMesh:
 var key:=str(source.get_instance_id())+":"+str(skin.get_instance_id())
 if meshes.has(key):return meshes[key]
 var hip_bind:=-1
 for bind in skin.get_bind_count():
  if skin.get_bind_bone(bind)==hips_bone:hip_bind=bind;break
 assert(hip_bind>=0)
 var result:=ArrayMesh.new();result.blend_shape_mode=source.blend_shape_mode
 for shape in source.get_blend_shape_count():result.add_blend_shape(source.get_blend_shape_name(shape))
 for surface in source.get_surface_count():
  var arrays:Array=source.surface_get_arrays(surface)
  if surface==0:
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var slots:int=bones.size()/vertices.size()
   for vertex in vertices.size():
    var mask:=support_mask(frame*vertices[vertex])
    if mask<=0:continue
    var amount:float=mask*(1-DEFORMATION_RETAINED)
    var influences:Dictionary={}
    for slot in slots:
     var index:int=vertex*slots+slot
     if weights[index]>0:influences[bones[index]]=influences.get(bones[index],0.0)+weights[index]*(1-amount)
    influences[hip_bind]=influences.get(hip_bind,0.0)+amount
    assert(influences.size()<=slots,"Preserve all native influences within the available GPU slots")
    var labels:=influences.keys()
    for slot in slots:
     var index:int=vertex*slots+slot
     bones[index]=labels[slot] if slot<labels.size() else 0
     weights[index]=influences[labels[slot]] if slot<labels.size() else 0
   arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,source.surface_get_blend_shape_arrays(surface),{},source.surface_get_format(surface))
  result.surface_set_material(surface,source.surface_get_material(surface))
 meshes[key]=result
 return result
