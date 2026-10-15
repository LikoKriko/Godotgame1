extends Area3D
const Meshes=preload("res://scripts/prototype_3d/prop_mesh.gd")
const UNIT:=1.75/64.0
var kind:=5
var variant:=1
var health:=1
var rewards:Dictionary={}
func configure(record:Dictionary) -> void:
 kind=record.kind;variant=int(record.variant);health=int(record.hits)
 rewards={&"fibra":3,&"palo":2} if kind==4 else {&"hoja_bardana":int(record.yield)}
 collision_layer=16;collision_mask=0;monitoring=false
 add_to_group("prototype_saplings" if kind==4 else "prototype_burdock")
 var shape:=CollisionShape3D.new();var volume:=CylinderShape3D.new();volume.radius=0.47 if kind==4 else 0.32;volume.height=1.05 if kind==4 else 0.55;shape.shape=volume;shape.position.y=volume.height*0.5;add_child(shape)
 var visual:=Node3D.new();visual.scale=Vector3.ONE*UNIT;add_child(visual)
 var wood:=Meshes.material(&"wood",Color("77623d"));var green:=Meshes.material(&"leaf",Color("637644"))
 if kind==4:
  Meshes.segment(visual,Vector3.ZERO,Vector3(0,36,0),0.75,wood)
  for i in range(3+variant%3):
   var angle:=i*2.4+variant;var start:=Vector3(0,10+i*4,0);var tip:=start+Vector3(cos(angle)*10,8,sin(angle)*10)
   Meshes.segment(visual,start,tip,0.42,wood)
   Meshes.sphere(visual,tip,Vector3(4.2,2.0,3.5),green)
 else:
  for i in 6:
   var leaf:=Meshes.slab(visual,PackedVector2Array([Vector2(0,0),Vector2(-4,4),Vector2(-5,10),Vector2(0,17),Vector2(5,10),Vector2(4,4)]),0.35,green)
   leaf.rotation=Vector3(0.45,i*TAU/6,0);leaf.position=Vector3(sin(i)*2,1,cos(i)*2)
func hit() -> bool:
 if health<=0:return false
 health-=1
 if health==0:hide();collision_layer=0
 return true
