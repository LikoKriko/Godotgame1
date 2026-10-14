extends RefCounted
## Perception, persistent memory and committed goals, separate from movement.
var mode: StringName = &"idle"
var goal:=Vector3.ZERO
var last_seen:=Vector3.ZERO
var remembers_player:=false
var remaining:=0.0
var elapsed:=0.0
var tree: Node3D
var rng:=RandomNumberGenerator.new()
var profile=preload("res://scripts/creature_profile.gd").new()
func configure(seed_value: int,personality=null) -> void:
 rng.seed=seed_value
 if personality!=null:profile=personality
func set_mode(value:StringName,seconds:float=0.0) -> void:
 mode=value;remaining=seconds;elapsed=0
func advance(delta:float,position:Vector3,player_position:Vector3,visible_player:bool,trees:Array) -> StringName:
 elapsed+=delta;remaining=maxf(0,remaining-delta)
 if visible_player and profile.aggressive_to_player:
  last_seen=player_position;goal=last_seen;remembers_player=true
  if mode!=&"chase":set_mode(&"chase")
  return mode
 if remembers_player:
  goal=last_seen
  if mode!=&"investigate":set_mode(&"investigate")
  if Vector2(position.x-goal.x,position.z-goal.z).length()>0.25:return mode
  remembers_player=false;set_mode(&"search",2.0);return mode
 if mode==&"search" and remaining>0:return mode
 if mode==&"sit_down" and remaining<=0:set_mode(&"sit",rng.randf_range(profile.resting_seconds.x,profile.resting_seconds.y))
 elif mode==&"sit" and remaining<=0:set_mode(&"sit_up",profile.posture_seconds)
 elif mode in [&"sit_up",&"feed",&"search"] and remaining<=0:set_mode(&"idle")
 if mode==&"walk" and (position.distance_to(goal)<0.25 or remaining<=0):
  if is_instance_valid(tree) and position.distance_to(goal)<0.35:set_mode(&"feed",rng.randf_range(profile.feeding_seconds.x,profile.feeding_seconds.y))
  else:set_mode(&"idle")
 if mode==&"idle":choose_activity(position,trees)
 return mode
func choose_activity(position:Vector3,trees:Array) -> void:
 tree=null
 if rng.randf()<0.25:set_mode(&"sit_down",profile.posture_seconds);return
 var best_score:=-INF
 for candidate in trees if profile.tree_habitat else []:
  if not is_instance_valid(candidate) or not candidate.visible:continue
  var density:=0
  for other in trees:
   if is_instance_valid(other) and candidate.global_position.distance_to(other.global_position)<5:density+=1
  var score:float=density*2-position.distance_to(candidate.global_position)*0.25+rng.randf()*0.7
  if score>best_score:best_score=score;tree=candidate
 if is_instance_valid(tree):
  var away:Vector3=(position-tree.global_position).normalized()
  if away.is_zero_approx():away=Vector3.BACK
  goal=tree.global_position+Vector3(away.x,0,away.z).normalized()*0.8
 else:goal=position+Vector3(cos(rng.randf()*TAU),0,sin(rng.randf()*TAU))*rng.randf_range(1.5,3)
 set_mode(&"walk",12)
