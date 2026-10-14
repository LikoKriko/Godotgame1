extends SceneTree
const Clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(world)
 world.player.set_physics_process(false)
 for enemy in get_nodes_in_group("prototype_enemies"):enemy.set_physics_process(false)
 var actor=world.player.model
 var mesh:Mesh=actor.mesh_node.mesh
 for family in Clips.FAMILIES:
  actor.family_override=family
  for clip in Clips.STATES:
   for frame in 16:
    actor.aim_contact=Vector3(0,42,31)
    actor.animate(clip,frame/15.0,family==&"axe",0,frame/15.0)
    require(actor.grip_error<0.045,"Grip: %s / %s / %d"%[family,clip,frame])
    require(actor.rig.posed[3].origin.is_finite(),"Head transform remains finite")
 require(actor.mesh_node.mesh==mesh,"Every family and action shares the same bind mesh")
 actor.family_override=&""
 for state in [&"walk",&"run",&"crouch_walk"]:
  for direction in 16:
   for frame in 24:
    var travel:=Vector3(sin(direction*TAU/16),0,cos(direction*TAU/16))
    actor.animate(state,frame/24.0,false,0.016,frame/24.0,travel)
    var feet:float=actor.rig.posed[15].origin.x-actor.rig.posed[12].origin.x
    require(feet>=3.02,"Feet cannot intersect during lateral or diagonal locomotion")
 for point in [Vector3(0,42,31),Vector3(4,35,30),Vector3(-4,48,31)]:
  actor.family_override=&"axe";actor.aim_contact=point
  actor.animate(&"action",0.5,true)
  require(actor.tip_socket.position.distance_to(point)<0.02,"Cutting edge reaches the aimed point at contact")
  require((actor.axe.transform*preload("res://scripts/prototype_3d/stone_axe.gd").CONTACT).distance_to(point)<0.02,"Visible blade vertex and hit point coincide")
  require(actor.grip_error<0.04,"Both arms follow the aimed tool")
 var neutral_head:Vector3=actor.rig.posed[3].origin
 actor.family_override=&"";actor.animate(&"run",0.3,false)
 require(actor.rig.posed[3].origin.distance_to(neutral_head)<12,"Head remains attached during running")
 var cloth_moved:=false
 for i in 25:
  actor.animate(&"run",fposmod(i/12.0,1),false,0.016,i/12.0)
  cloth_moved=cloth_moved or absf(actor.rig.cloth_angle[0])>0.0001
 require(cloth_moved and absf(actor.rig.cloth_angle[0])<=0.09,"Loose cloth has bounded inertial follow-through")
 print("%s: %d animation catalogue checks, %d failures"%["PASS" if failures==0 else "FAIL",checks,failures]);world.free();quit(1 if failures else 0)
