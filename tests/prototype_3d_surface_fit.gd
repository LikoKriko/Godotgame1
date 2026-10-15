extends SceneTree
## Inspect the actual mesh and both source paintings, including interpolated UVs.
const Profile=preload("res://scripts/prototype_3d/survivor_surface.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize() -> void:call_deferred("run")
func sample(photo:Image,uv:Vector2) -> Color:
 return photo.get_pixel(clampi(int(uv.x*photo.get_width()),0,photo.get_width()-1),clampi(int(uv.y*photo.get_height()),0,photo.get_height()-1))
func run() -> void:
 var actor=load("res://scripts/prototype_3d/survivor_model.gd").new();root.add_child(actor)
 var arrays:Array=actor.mesh_node.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var tags:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var front:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 var custom:PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
 require(custom.size()==vertices.size()*4,"Every vertex retains independent rear UVs, side blend and material identity")
 var photos:Array[Image]=[actor.FRONT_REFERENCE.get_image(),actor.BACK_REFERENCE.get_image()]
 var torso_samples:=0;var cloth_samples:=0;var studio_on_torso:=0;var studio_on_cloth:=0
 var valid_coordinates:=true;var valid_blends:=true;var symmetric_blends:=true
 for face in range(0,vertices.size(),3):
  if tags[face].y<.5:continue
  var rear:=[Vector2(custom[face*4],custom[face*4+1]),Vector2(custom[(face+1)*4],custom[(face+1)*4+1]),Vector2(custom[(face+2)*4],custom[(face+2)*4+1])]
  var cloth:=custom[face*4+3]>.5
  var torso:=int(tags[face].x)==0 and not cloth
  for i in 3:
   var index:=face+i;var blend:=custom[index*4+2]
   valid_blends=valid_blends and blend>=0 and blend<=1
   if torso and vertices[index].z>2.5:symmetric_blends=symmetric_blends and blend>=.5
   elif torso and vertices[index].z< -2.5:symmetric_blends=symmetric_blends and blend<=.5
  # Test interiors as well as corners: mirrored-coordinate interpolation once
  # painted the studio background through the middle of a valid triangle.
  for bary:Vector3 in [Vector3.ONE/3,Vector3(.7,.2,.1),Vector3(.1,.7,.2),Vector3(.2,.1,.7)]:
   var coordinates:=[front[face]*bary.x+front[face+1]*bary.y+front[face+2]*bary.z,rear[0]*bary.x+rear[1]*bary.y+rear[2]*bary.z]
   for side in 2:
    var uv:Vector2=coordinates[side]
    valid_coordinates=valid_coordinates and uv.x>0 and uv.x<1 and uv.y>0 and uv.y<1
    var color:=sample(photos[side],uv)
    var chroma:=maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))
    # The supplied studio is almost neutral; skin and olive cloth are chromatic.
    if torso:
     torso_samples+=1
     if chroma<.06:studio_on_torso+=1
    elif cloth:
     cloth_samples+=1
     if chroma<.06:studio_on_cloth+=1
 require(valid_coordinates,"Both paintings stay within their image bounds")
 require(valid_blends and symmetric_blends,"Surface blends agree with front/back geometry and stay normalized")
 print("Reference samples: torso studio=",studio_on_torso,"/",torso_samples,"; cloth studio=",studio_on_cloth,"/",cloth_samples)
 require(torso_samples>1000 and studio_on_torso<float(torso_samples)*.01,"Torso mapping covers the mesh without unpainted studio strips")
 require(cloth_samples>1000 and studio_on_cloth<float(cloth_samples)*.02,"Cloth unwrap avoids the studio between the legs and beside the arms")
 # Independent measurements from the reference waist/chest, in author units.
 var waist:=0.0;var chest:=0.0;var hip:=0.0
 for i in vertices.size():
  var p:=vertices[i]
  if int(tags[i].x)==0 and custom[i*4+3]<.5:
   if absf(p.y-33)<.05:waist=maxf(waist,absf(p.x))
   if absf(p.y-43)<.05:chest=maxf(chest,absf(p.x))
  if int(tags[i].x)==13:hip=maxf(hip,absf(p.x))
 require(absf(waist-3.72)<.12,"Physical waist follows the painted silhouette rather than the old broad mesh")
 require(chest>waist*1.65 and chest<waist*1.8,"Rib cage and waist retain the supplied slim proportions")
 require(hip>waist and hip<waist*1.45,"Hip shell joins the narrow waist without a spherical crotch")
 var no_ledge:=true;var pelvis_weights:=true
 var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 for i in vertices.size():
  var p:=vertices[i]
  if int(tags[i].x)==13:
   for slot in 4:
    if weights[i*4+slot]>.001:pelvis_weights=pelvis_weights and ids[i*4+slot]==0
  elif int(tags[i].x)==0 and custom[i*4+3]>.5 and p.y>=25.3:
   var r:=Profile.pelvis_radius(p.y)
   no_ledge=no_ledge and absf(p.x)<=r.x+.01 and absf(p.z)<=r.y+.01
 require(no_ledge,"Upper trouser legs cannot protrude past the shared hip silhouette")
 require(pelvis_weights,"Shared waistband stays on the pelvis while each leg moves")
 actor.free()
 print("%s: %d reference coverage, mesh silhouette and cloth attachment checks"%["PASS" if failures==0 else "FAIL",checks])
 quit(1 if failures else 0)
