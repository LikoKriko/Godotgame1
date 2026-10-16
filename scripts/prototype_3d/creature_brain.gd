extends RefCounted
## Perception, persistent memory and committed goals, separate from movement.
const SLEEP_STATES:Array[StringName]=[&"sleep_down",&"sleep",&"wake_up"]
var mode: StringName = &"idle"
var goal:=Vector3.ZERO
var last_seen:=Vector3.ZERO
var remembers_player:=false
var remaining:=0.0
var elapsed:=0.0
var tree: Node3D
var feeding_cooldown:=0.0
var body_radius:=.6
var rng:=RandomNumberGenerator.new()
var profile=preload("res://scripts/creature_profile.gd").new()
func configure(seed_value: int,personality=null) -> void:
 rng.seed=seed_value
 if personality!=null:profile=personality
static func night(hour:float) -> bool:return hour>=23 or hour<6
static func flat_distance(a:Vector3,b:Vector3) -> float:return Vector2(a.x-b.x,a.z-b.z).length()
func sleeping() -> bool:return mode in SLEEP_STATES
func set_mode(value:StringName,seconds:float=0.0) -> void:
 mode=value;remaining=seconds;elapsed=0
func alert_to(player_position:Vector3) -> void:
 last_seen=player_position;goal=last_seen;remembers_player=true
 if mode in [&"sleep_down",&"sleep"]:set_mode(&"wake_up",.65)
 elif mode!=&"wake_up":set_mode(&"chase")
func advance(delta:float,position:Vector3,player_position:Vector3,visible_player:bool,trees:Array,hour:float=12.0) -> StringName:
 elapsed+=delta;remaining=maxf(0,remaining-delta);feeding_cooldown=maxf(0,feeding_cooldown-delta)
 if visible_player and profile.aggressive_to_player:
  if mode in [&"sleep_down",&"sleep"]:alert_to(player_position)
  last_seen=player_position;goal=last_seen;remembers_player=true
  if mode==&"wake_up" and remaining>0:return mode
  if mode!=&"chase":set_mode(&"chase")
  return mode
 if mode==&"wake_up" and remaining>0:return mode
 if remembers_player:
  goal=last_seen
  if mode!=&"investigate":set_mode(&"investigate")
  if flat_distance(position,goal)>0.25:return mode
  remembers_player=false;set_mode(&"search",2.0);return mode
 if mode==&"search" and remaining>0:return mode
 if night(hour):
  if mode not in SLEEP_STATES:set_mode(&"sleep_down",.7);tree=null
  elif mode==&"sleep_down" and remaining<=0:set_mode(&"sleep")
  elif mode==&"wake_up":set_mode(&"sleep_down",.7)
  return mode
 if mode in [&"sleep_down",&"sleep"]:set_mode(&"wake_up",.65);return mode
 if mode==&"wake_up":set_mode(&"idle")
 if mode==&"sit_down" and remaining<=0:set_mode(&"sit",rng.randf_range(profile.resting_seconds.x,profile.resting_seconds.y))
 elif mode==&"sit" and remaining<=0:set_mode(&"sit_up",profile.posture_seconds)
 elif mode in [&"sit_up",&"feed",&"search"] and remaining<=0:set_mode(&"idle")
 if mode==&"feed" and not usable_tree(tree):set_mode(&"idle")
 if mode==&"walk" and is_instance_valid(tree) and not usable_tree(tree):set_mode(&"idle")
 if mode==&"walk" and (flat_distance(position,goal)<.08 or remaining<=0):
  if usable_tree(tree) and flat_distance(position,goal)<.1 and feeding_cooldown<=0:
   set_mode(&"feed",rng.randf_range(profile.feeding_seconds.x,profile.feeding_seconds.y));feeding_cooldown=remaining+rng.randf_range(8,16)
  else:set_mode(&"sit_down",profile.posture_seconds) if usable_tree(tree) else set_mode(&"idle")
 if mode==&"idle":choose_activity(position,trees)
 return mode
static func usable_tree(candidate) -> bool:
 return is_instance_valid(candidate) and candidate is Node3D and candidate.is_visible_in_tree() and (candidate.get("health")==null or candidate.get("health")>0)
func trunk_standoff(candidate:Node3D) -> float:
 var radius:=.18
 for child in candidate.get_children():
  if child is CollisionShape3D and child.shape is CapsuleShape3D and child.position.y-child.shape.height*.5<.5:radius=maxf(radius,child.shape.radius)
 return body_radius+radius+.06
func choose_activity(position:Vector3,trees:Array) -> void:
 tree=null
 if rng.randf()<0.25:set_mode(&"sit_down",profile.posture_seconds);return
 var best_score:=-INF
 for candidate in trees if profile.tree_habitat else []:
  if not usable_tree(candidate):continue
  var density:=0
  for other in trees:
   if usable_tree(other) and flat_distance(candidate.global_position,other.global_position)<5:density+=1
  var score:float=density*2-flat_distance(position,candidate.global_position)*0.25+rng.randf()*0.7
  if score>best_score:best_score=score;tree=candidate
 if usable_tree(tree):
  var away:=position-tree.global_position;away.y=0
  if away.is_zero_approx():away=Vector3.BACK
  goal=tree.global_position+away.normalized()*trunk_standoff(tree)
 else:goal=position+Vector3(cos(rng.randf()*TAU),0,sin(rng.randf()*TAU))*rng.randf_range(1.5,3)
 set_mode(&"walk",clampf(flat_distance(position,goal)/.85+3,3,12))
