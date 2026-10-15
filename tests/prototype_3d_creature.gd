extends SceneTree
const Poses=preload("res://scripts/prototype_3d/young_pose.gd")
var failures:=0
var checks:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();world.use_test_layout=true;root.add_child(world)
 world.player.set_physics_process(false)
 var enemy=get_nodes_in_group("prototype_enemies")[0];enemy.set_physics_process(false)
 var actor=enemy.model;var mesh:Mesh=actor.mesh_node.mesh
 require(actor.skeleton.get_bone_count()==14,"Creature has its own nonhuman skeleton")
 require(absf(mesh.get_aabb().size.y*actor.scale.y-0.875)<0.001,"Young creature keeps approved height")
 for state in preload("res://scripts/prototype_3d/animation_review.gd").YOUNG_STATES:
  for side in [true,false]:
   for frame in 24:
    var pose:=Poses.sample(state,frame/23.0,side)
    for arm in pose.arms:
     require(absf(arm.root.distance_to(arm.joint)-Poses.ARM_A)<0.01,"Upper arm cannot detach or stretch")
     require(absf(arm.joint.distance_to(arm.end)-Poses.ARM_B)<0.01,"Forearm cannot stretch")
    for leg in pose.legs:
     require(absf(leg.root.distance_to(leg.joint)-Poses.LEG_A)<0.01,"Short thigh keeps its length")
     require(absf(leg.joint.distance_to(leg.end)-Poses.LEG_B)<0.01,"Bent lower leg keeps its length")
    actor.animate(state,frame/23.0,side)
    require(actor.posed[1].origin.is_finite(),"Head remains attached and finite")
 require(actor.mesh_node.mesh==mesh,"Creature animates one skinned mesh")
 var walking:=Poses.sample(&"run",0.3)
 require(walking.head.z.dot(Vector3.BACK)>0.9,"Quadruped head faces forward rather than downward")
 var left:=Poses.sample(&"attack",0.5,true);var right:=Poses.sample(&"attack",0.5,false)
 require(left.arms[1].end.distance_to(right.arms[1].end)>2,"Alternating punches use distinct hands")
 var brain=preload("res://scripts/prototype_3d/creature_brain.gd").new();brain.configure(17)
 brain.advance(0.1,Vector3.ZERO,Vector3(4,0,3),true,[])
 for i in 30:brain.advance(0.1,Vector3.ZERO,Vector3(-20+i,0,12),false,[])
 require(brain.mode==&"investigate" and brain.goal==Vector3(4,0,3),"Lost target retains last seen position without tracking hidden movement")
 brain.advance(0.1,Vector3(4,0,3),Vector3(12,0,12),false,[])
 require(brain.mode==&"search" and not brain.remembers_player,"Memory clears only after reaching last known location")
 world.parry.reset();world.player.parry_elapsed=-1
 require(world.activate_parry(),"Guard starts when ready")
 require(not world.player.model.parry_pulse.visible,"Attempt alone cannot emit successful parry effect")
 world.parry.advance(0.25);world.enemy_contact(enemy,2,world.parry.time)
 require(world.player.model.parry_pulse.visible,"Confirmed parry pulses at the hands")
 require(absf(enemy.effects.remaining(&"stun")-1.5)<0.001,"Parry stuns for 1.5 seconds")
 require(world.parry.advance(0.4).is_empty(),"Parry prevents delayed damage")
 world.parry.reset();world.player.model.parry_pulse.hide()
 world.enemy_contact(enemy,2,0)
 require(world.parry.advance(0.34).is_empty(),"Impact waits 0.35 seconds before damage")
 require(world.parry.advance(0.02).size()==1,"Unblocked impact delivers damage once")
 for id in world.bag.DEFINITIONS:
  var icon=preload("res://scripts/prototype_3d/item_icons.gd").get_icon(id)
  require(icon.get_size()==Vector2(256,256),"All item icons have 256px backing textures")
 for value in range(1,7):
  world.settings.values.hud_size=value;world.settings.changed.emit()
  require(absf(world.hud.quick.scale.x-sqrt(0.4*(1+0.2*(value-1))))<0.001,"HUD levels preserve approved area scaling")
 print("%s: %d creature, memory, parry and HUD checks"%["PASS" if failures==0 else "FAIL",checks])
 world.free();quit(1 if failures else 0)
