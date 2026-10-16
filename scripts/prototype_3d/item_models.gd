extends RefCounted
## Immutable, shared metre-scale meshes for physical items. No inventory state
## is cached: a stack, wear and water always belong to its individual item.
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
const Icons=preload("res://scripts/prototype_3d/item_icons.gd")
const Held=preload("res://scripts/prototype_3d/held_prop.gd")
const SUPPORTED:Array[StringName]=[&"axe",&"pickaxe",&"sword",&"bow",&"flecha",&"botella",&"water",&"apple",&"berries",&"ration",&"palo",&"piedra",&"cuerda",&"hilo",&"cuero",&"cuero_curtido",&"cuero_sin_refinar",&"saco_sal",&"hoja_bardana",&"burdock_armor",&"basic_workbench"]
const NATIVE={
 &"axe":preload("res://assets/models/meshy/axe/model.res"),
 &"pickaxe":preload("res://assets/models/meshy/pickaxe/model.res"),
 &"bow":preload("res://assets/models/meshy/bow/model.res"),
 &"burdock_armor":preload("res://assets/models/meshy/leaf_armor/model.res"),
 &"piedra":preload("res://assets/models/meshy/rock1/model.res")}
static var cache:Dictionary={}
static var paints:Dictionary={}
static func supported(id:StringName) -> bool:return id in SUPPORTED
static func state_key(item:Dictionary) -> String:
 var id:StringName=item.get("id",&"")
 var canonical_id:=&"botella" if id==&"water" else id
 # The supplied wooden bottle is opaque: all fill levels share its geometry.
 return String(canonical_id)
static func create(item:Dictionary) -> Node3D:
 var id:StringName=item.get("id",&"")
 if not supported(id):return null
 var key:=state_key(item)
 if not cache.has(key):cache[key]=bake(item)
 var result:=Node3D.new();result.name="PhysicalItem";result.set_meta("item_model",id)
 for part:Dictionary in cache[key]:
  var mesh:=MeshInstance3D.new();mesh.mesh=part.mesh;mesh.material_override=part.paint;mesh.transform=part.get("frame",Transform3D.IDENTITY);result.add_child(mesh)
 return result
static func box(parent:Node3D,point:Vector3,size:Vector3,paint:Material) -> void:
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=point;node.material_override=paint;parent.add_child(node)
static func source(item:Dictionary) -> Dictionary:
 var id:StringName=item.id;var root:=Node3D.new();var span:=0.25
 var wood:=Meshes.material(&"wood",Color("98683d"));var rope:=Meshes.material(&"rope",Color("bbb07b"))
 if id==&"axe":
  var axe:=preload("res://scripts/prototype_3d/stone_axe.gd").new();axe.build();root.add_child(axe);root.rotation.x=PI/2;span=0.90
 elif id in [&"pickaxe",&"sword",&"bow",&"botella",&"water",&"apple",&"berries",&"ration"]:
  var family:StringName=&"bottle" if id in [&"botella",&"water"] else (&"food" if id in [&"apple",&"berries",&"ration"] else id)
  var prop:=Held.new();root.add_child(prop);prop.configure(family);prop.show_item(id,500 if id==&"water" else item.get("water_ml",0));prop.update_pose(&"idle",0,Vector3.ZERO,false)
  if family in [&"pickaxe",&"sword",&"bow"]:root.rotation.x=PI/2;span=0.90
  elif family==&"bottle":root.rotation.x=PI/2;span=0.31
  else:span=0.11 if id==&"apple" else (0.10 if id==&"berries" else 0.16)
 elif id==&"flecha":root.add_child(Held.make_arrow());span=0.70
 elif id==&"palo":
  for side in [-1.0,1.0]:
   var points:=PackedVector3Array([Vector3(side*1.0,0,-10),Vector3(side*1.6,0.3,-3),Vector3(side*2.4,0.2,5),Vector3(side*3,0,11)])
   Meshes.polyline(root,points,PackedFloat32Array([0.8,1,1,0.7]),wood,9)
   Meshes.segment(root,points[2],points[2]+Vector3(side*2.5,0,2),0.45,wood)
  span=0.65
 elif id in [&"cuerda",&"hilo"]:
  if id==&"cuerda":
   # Three twisted strands loop in a flat coil with a loose end.
   for strand in 3:
    var path:=PackedVector3Array();var radii:=PackedFloat32Array()
    for i in 241:
     var t:=i/240.0;var a:=t*TAU*3.1;var radius:=lerpf(2.4,5.6,t);var twist:=a*9+strand*TAU/3
     path.append(Vector3(cos(a)*radius,0.48+sin(twist)*0.25,sin(a)*radius)+Vector3(cos(a)*cos(twist)*0.25,0,sin(a)*cos(twist)*0.25));radii.append(0.25)
    Meshes.polyline(root,path,radii,rope,5)
   Meshes.polyline(root,PackedVector3Array([Vector3(5,0.5,1),Vector3(6.5,0.4,-1),Vector3(7.5,0.3,-3)]),PackedFloat32Array([0.48,0.45,0.4]),rope,6);span=0.28
  else:
   for y in [-2.1,2.1]:Meshes.segment(root,Vector3(0,y-0.24,0),Vector3(0,y+0.24,0),2.1,wood)
   Meshes.segment(root,Vector3(0,-2,0),Vector3(0,2,0),0.8,wood)
   var path:=PackedVector3Array();var radii:=PackedFloat32Array()
   for i in 361:
    var t:=i/360.0;var a:=t*TAU*12;path.append(Vector3(cos(a)*1.65,lerpf(-1.7,1.7,t),sin(a)*1.65));radii.append(0.16)
   Meshes.polyline(root,path,radii,rope,4)
   Meshes.polyline(root,PackedVector3Array([Vector3(1.5,-1.2,0),Vector3(2.8,-1.6,0.1),Vector3(4,-1.9,0.6),Vector3(4.5,-2,1.8)]),PackedFloat32Array([0.13,0.13,0.13,0.13]),rope,4)
   root.rotation.x=PI/2;span=0.13
 elif id==&"piedra":stone(root);span=0.20
 elif id in [&"hoja_bardana",&"cuero",&"cuero_curtido",&"cuero_sin_refinar"]:
  sheet(root,id);span=0.24 if id==&"hoja_bardana" else 0.42
 elif id==&"saco_sal":
  var sack:=Meshes.sphere(root,Vector3(0,2.5,0),Vector3(2.2,2.8,1.5),Meshes.material(&"leather",Color("d6c29e")))
  sack_mouth(root)
  for y in [4.7,5.0]:
   var path:=PackedVector3Array();var radii:=PackedFloat32Array()
   for i in 33:path.append(Vector3(cos(i*TAU/32)*1.25,y,sin(i*TAU/32)*0.7));radii.append(0.12)
   Meshes.polyline(root,path,radii,rope,5)
  # The front label is a curved part of the sack skin, not a floating icon.
  label_patch(root);span=0.26
 elif id==&"burdock_armor":
  var mesh:=MeshInstance3D.new();mesh.mesh=NATIVE[id];root.add_child(mesh);root.rotation.x=PI/2;span=29*1.75/64.0
 elif id==&"basic_workbench":
  for part in preload("res://scripts/prototype_3d/workbench.gd").PARTS:box(root,part[0],part[1],wood)
  span=1.2
 return {"root":root,"span":span}
static func collect(node:Node3D,frame:Transform3D=Transform3D.IDENTITY) -> Array[Dictionary]:
 var records:Array[Dictionary]=[]
 if not node.visible:return records
 frame=frame*node.transform
 if node is MeshInstance3D and node.mesh!=null:records.append({"mesh":node.mesh,"frame":frame,"paint":node.material_override})
 for child in node.get_children():
  if child is Node3D:records.append_array(collect(child,frame))
 return records
static func bake(item:Dictionary) -> Array[Dictionary]:
 if NATIVE.has(item.id):
  var mesh:Mesh=NATIVE[item.id]
  var rotation:=Basis(Vector3.RIGHT,PI/2) if item.id!=&"piedra" else Basis.IDENTITY
  var bounds:AABB=Transform3D(rotation,Vector3.ZERO)*mesh.get_aabb()
  var factor:=preload("res://scripts/prototype_3d/survivor_anatomy.gd").HEIGHT_METRES/64.0
  if item.id==&"piedra":factor=0.20/bounds.size[bounds.size.max_axis_index()]
  var center:=bounds.get_center()
  return [{"mesh":mesh,"paint":mesh.surface_get_material(0),"frame":Transform3D(rotation.scaled(Vector3.ONE*factor),Vector3(-center.x,-bounds.position.y,-center.z)*factor+Vector3.UP*0.003)}]
 if item.id in [&"botella",&"water"]:
  var mesh:Mesh=preload("res://assets/items/prototype_3d/bottle_meshy/bottle.res")
  var rotation:=Basis(Vector3.RIGHT,PI/2)
  var bounds:AABB=Transform3D(rotation,Vector3.ZERO)*mesh.get_aabb()
  var factor:=preload("res://scripts/prototype_3d/survivor_anatomy.gd").HEIGHT_METRES/64.0
  var center:=bounds.get_center()
  return [{"mesh":mesh,"paint":mesh.surface_get_material(0),"frame":Transform3D(rotation.scaled(Vector3.ONE*factor),Vector3(-center.x,-bounds.position.y,-center.z)*factor+Vector3.UP*0.003)}]
 var data:=source(item);var root:Node3D=data.root;var pieces:=collect(root)
 var bounds:=AABB();var started:=false
 for piece in pieces:
  # Rotated primitive AABBs overestimate the support point; use real vertices
  # once while baking so small objects cannot hover over the terrain.
  for part in piece.mesh.get_surface_count():
   var arrays:Array=piece.mesh.surface_get_arrays(part)
   for vertex:Vector3 in arrays[Mesh.ARRAY_VERTEX]:
    var point:Vector3=piece.frame*vertex
    bounds=bounds.expand(point) if started else AABB(point,Vector3.ZERO);started=true
 var factor:float=data.span/maxf(0.001,bounds.size[bounds.size.max_axis_index()])
 var center:=bounds.get_center();var offset:=Vector3(-center.x,-bounds.position.y,-center.z)*factor+Vector3.UP*0.003
 var normalization:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),offset)
 var groups:Dictionary={}
 for piece in pieces:
  for part in piece.mesh.get_surface_count():
   var paint:Material=piece.paint if piece.paint!=null else piece.mesh.surface_get_material(part)
   if paint==null:paint=Meshes.material(&"plain")
   var key:=paint.get_instance_id()
   if not groups.has(key):
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);groups[key]={"surface":surface,"paint":paint}
   groups[key].surface.append_from(piece.mesh,part,normalization*piece.frame)
 var result:Array[Dictionary]=[]
 for key in groups:
  if not paints.has(key):
   var paint:Material=groups[key].paint.duplicate()
   if paint.next_pass!=null:paint.next_pass=paint.next_pass.duplicate();paint.next_pass.set_shader_parameter("thickness",0.0018)
   paints[key]=paint
  result.append({"mesh":groups[key].surface.commit(),"paint":paints[key]})
 root.free();return result
static func bounds(node:Node3D) -> AABB:
 var result:=AABB();var first:=true
 for piece in collect(node):
  var box_bounds:AABB=piece.frame*piece.mesh.get_aabb();result=box_bounds if first else result.merge(box_bounds);first=false
 return result
static func sheet(parent:Node3D,id:StringName) -> void:
 var texture:=Icons.get_icon(id);var image:=texture.get_image();var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var count:=40;var thickness:=0.025 if id==&"hoja_bardana" else 0.045
 for y in count:
  for x in count:
   var uv_center:=Vector2(x+0.5,y+0.5)/count
   if image.get_pixel(clampi(int(uv_center.x*image.get_width()),0,image.get_width()-1),clampi(int(uv_center.y*image.get_height()),0,image.get_height()-1)).a<0.4:continue
   var corners:Array[Vector3]=[];var uvs:Array[Vector2]=[]
   for cell:Vector2 in [Vector2(x,y),Vector2(x,y+1),Vector2(x+1,y+1),Vector2(x+1,y)]:
    var uv:=cell/count;var elevation:=0.07*sin(uv.x*PI)*sin(uv.y*PI)+0.025*sin(uv.x*PI*4+uv.y*3)
    corners.append(Vector3(uv.x-0.5,elevation,uv.y-0.5));uvs.append(uv)
   for side in [-1.0,1.0]:
    var order:=[0,1,2,0,2,3] if side>0 else [2,1,0,3,2,0]
    for index in order:surface.set_uv(uvs[index]);surface.add_vertex(corners[index]+Vector3.UP*thickness*side)
 var paint:=StandardMaterial3D.new();paint.albedo_texture=texture;paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS;paint.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;paint.alpha_scissor_threshold=0.4;paint.roughness=1
 surface.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.material_override=paint;parent.add_child(mesh)
static func stone(parent:Node3D) -> void:
 var mesh:=MeshInstance3D.new();mesh.mesh=NATIVE[&"piedra"];parent.add_child(mesh)
static func label_patch(parent:Node3D) -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 # Follow the actual sack surface, so the painted SAL label cannot sit inside it.
 for row in 12:
  for col in 12:
   var points:Array[Vector3]=[];var coords:Array[Vector2]=[]
   for offset:Vector2 in [Vector2(col,row),Vector2(col+1,row),Vector2(col+1,row+1),Vector2(col,row+1)]:
    var t:=offset/12;var x:=lerpf(-1.4,1.4,t.x);var y:=lerpf(1.0,3.8,t.y)
    var z:=1.5*sqrt(maxf(0.01,1-pow(x/2.2,2)-pow((y-2.5)/2.8,2)))+0.035
    points.append(Vector3(x,y,z));coords.append(Vector2(lerpf(0.23,0.77,t.x),lerpf(0.86,0.40,t.y)))
   for i in [0,2,1,0,3,2]:
    surface.set_normal(Vector3(points[i].x/4.84,(points[i].y-2.5)/7.84,points[i].z/2.25).normalized());surface.set_uv(coords[i]);surface.add_vertex(points[i])
 var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();var paint:=StandardMaterial3D.new();paint.cull_mode=BaseMaterial3D.CULL_DISABLED;paint.albedo_texture=Icons.get_icon(&"saco_sal");paint.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;paint.roughness=1;mesh.material_override=paint;parent.add_child(mesh)
static func sack_mouth(parent:Node3D) -> void:
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rings:Array[PackedVector3Array]=[]
 for row in [Vector3(4.7,0.85,0.6),Vector3(5.5,1.2,0.75),Vector3(6.5,1.9,1.1)]:
  var ring:=PackedVector3Array()
  for i in 16:
   var a:=i*TAU/16;var fold:=1+0.17*sin(i*2.6)
   ring.append(Vector3(cos(a)*row.y*fold,row.x+0.13*sin(i*2.4),sin(a)*row.z*fold))
  rings.append(ring)
 for row in 2:
  for i in 16:
   var n:=(i+1)%16
   for point:Vector3 in [rings[row][i],rings[row+1][i],rings[row+1][n],rings[row][i],rings[row+1][n],rings[row][n]]:surface.set_uv(Vector2(point.x,point.y)*0.2);surface.add_vertex(point)
 surface.generate_normals();var node:=MeshInstance3D.new();node.mesh=surface.commit();var paint:StandardMaterial3D=Meshes.material(&"leather",Color("d6c29e")).duplicate();paint.cull_mode=BaseMaterial3D.CULL_DISABLED;node.material_override=paint;parent.add_child(node)
