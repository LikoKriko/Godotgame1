extends Node3D
## Solid exteriors stay loaded; empty rooms stream in the same world near doors.
const UNIT:=1.75/64.0
const Art=preload("res://scripts/camp_art.gd")
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
var building_id:=0
var width:=7.0
var depth:=5.0
var stream:Node3D
var curtain:MeshInstance3D
func paint(kind:StringName,color:Color) -> Material:
 var result:Material=Meshes.material(kind,color).duplicate();result.next_pass=result.next_pass.duplicate();result.next_pass.set_shader_parameter("thickness",0.003);return result
func box(point:Vector3,size:Vector3,material:Material,solid:bool=true) -> MeshInstance3D:
 var visual:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;visual.mesh=mesh;visual.material_override=material;visual.position=point;add_child(visual)
 if solid:
  var body:=StaticBody3D.new();body.position=point;body.set_meta("physical_height",size.y);add_child(body)
  var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)
 return visual
func configure(game,record:Dictionary) -> void:
 building_id=record.id;add_to_group("prototype_buildings")
 var definition:Dictionary=Art.DEFINITIONS[building_id]
 name=definition.name;position=Vector3(record.base.x*UNIT,0,record.base.y*UNIT)
 width=definition.size.x*UNIT;depth=width*0.68
 position.z-=depth*0.5 # Source base is the front edge, not the room center.
 var wood:=paint(&"wood",Color("735334"));var dark_wood:=paint(&"wood",Color("4a3827"));var roof_paint:=paint(&"leather",Color("74634a"))
 var height:=2.5;var door_width:=1.5;var door_height:=2.2
 # Separate wall pieces leave an actual walkable opening, never a full box.
 box(Vector3(-width*0.5,height*0.5,0),Vector3(0.18,height,depth),wood)
 box(Vector3(width*0.5,height*0.5,0),Vector3(0.18,height,depth),wood)
 box(Vector3(0,height*0.5,-depth*0.5),Vector3(width,height,0.18),wood)
 for side in [-1,1]:box(Vector3(side*(width+door_width)*0.25,height*0.5,depth*0.5),Vector3((width-door_width)*0.5,height,0.18),wood)
 box(Vector3(0,(height+door_height)*0.5,depth*0.5),Vector3(door_width,height-door_height,0.18),dark_wood)
 # Timber seams preserve a quiet pixel-art palette and thin contours.
 for y in range(1,10):
  var elevation:float=y*0.25
  box(Vector3(0,elevation,-depth*0.5-0.1),Vector3(width,0.022,0.018),dark_wood,false)
  for side in [-1,1]:box(Vector3(side*(width*0.5+0.1),elevation,0),Vector3(0.018,0.022,depth),dark_wood,false)
 var ridge:float=height+width*(0.20 if building_id not in [1,4,5] else 0.14)
 var pitch:=atan2(ridge-height,width*0.5+0.4)
 var slope_length:=Vector2(width*0.5+0.4,ridge-height).length()
 for side in [-1,1]:
  var roof:=box(Vector3(side*(width*0.5+0.4)*0.5,(height+ridge)*0.5,0),Vector3(slope_length,0.16,depth+0.8),roof_paint,false)
  roof.rotation.z=-side*pitch
  var roof_body:=StaticBody3D.new();roof_body.transform=roof.transform;roof_body.set_meta("physical_height",ridge);add_child(roof_body)
  var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=roof.mesh.size;collision.shape=shape;roof_body.add_child(collision)
 # Close gables: exterior observers cannot see the room through the roof.
 for side in [-1,1]:
  var gable:=Meshes.slab(self,PackedVector2Array([Vector2(-width*0.5,height),Vector2(0,ridge),Vector2(width*0.5,height)]),0.08,wood)
  gable.position.z=side*depth*0.5
 # Awning and exposed poles distinguish the communal shelters/workshop.
 if building_id in [1,4,5]:
  box(Vector3(0,2.25,depth*0.5+0.8),Vector3(width*0.75,0.12,1.6),roof_paint)
  for side in [-1,1]:box(Vector3(side*width*0.35,1.1,depth*0.5+1.45),Vector3(0.14,2.2,0.14),wood)
 var entrance:=StandardMaterial3D.new();entrance.albedo_color=Color(0.02,0.015,0.01,0.7);entrance.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;entrance.cull_mode=BaseMaterial3D.CULL_DISABLED;entrance.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 curtain=box(Vector3(0,door_height*0.5,depth*0.5+0.105),Vector3(door_width,door_height,0.01),entrance,false)
 stream=preload("res://scripts/prototype_3d/building_stream.gd").new();stream.fragments.assign(["res://scenes/prototype_3d/empty_room.tscn"])
 stream.door_offset=Vector3(0,0,depth*0.5);stream.guard_size=Vector3(door_width,door_height,0.12)
 stream.interior_bounds=AABB(Vector3(-width*0.5,0,-depth*0.5),Vector3(width,4,depth))
 stream.content_scale=Vector3((width-0.18)/4,1,(depth-0.18)/4);stream.observer=game.player;add_child(stream)
 # Wildlife cannot enter this first safe interior; the player ignores layer 32.
 var wildlife_guard:=StaticBody3D.new();wildlife_guard.collision_layer=32;wildlife_guard.collision_mask=8;wildlife_guard.position=stream.door_offset+Vector3.UP*door_height*0.5;add_child(wildlife_guard)
 var guard_shape:=CollisionShape3D.new();var guard_volume:=BoxShape3D.new();guard_volume.size=Vector3(door_width,door_height,0.18);guard_shape.shape=guard_volume;wildlife_guard.add_child(guard_shape)
func _process(_delta:float) -> void:
 if stream==null or not is_instance_valid(stream.observer):return
 # The dark entrance is an exterior treatment; it must not veil the room inside.
 curtain.visible=not stream.interior_bounds.has_point(to_local(stream.observer.global_position))
