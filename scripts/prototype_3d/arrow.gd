extends Node3D
## Continuous segment collision prevents fast arrows tunnelling through targets.
var game
var direction:=Vector3.FORWARD
var speed:=650.0*1.75/64.0
const MAX_DISTANCE:=100.0
var distance_left:=MAX_DISTANCE
var damage:=3.0
func configure(owner_game,from:Vector3,toward:Vector3) -> void:
 game=owner_game;global_position=from;direction=from.direction_to(toward)
 if direction.is_zero_approx():direction=game.camera_rig.facing()
 var visual:=preload("res://scripts/prototype_3d/held_prop.gd").make_arrow();add_child(visual)
 visual.scale=Vector3.ONE*(1.75/64.0)
 # The global origin is the arrowhead; its body trails behind it.
 visual.position.z=-24*1.75/64.0
 var up:=Vector3.UP if absf(direction.dot(Vector3.UP))<0.98 else Vector3.RIGHT
 basis=Basis.looking_at(-direction,up);add_to_group("player_arrows_3d")
func _physics_process(delta:float) -> void:
 if game==null or game.paused:return
 travel(minf(distance_left,speed*delta))
func travel(span:float) -> void:
 span=clampf(span,0,distance_left)
 var end:=global_position+direction*span
 var query:=PhysicsRayQueryParameters3D.create(global_position,end,25,[game.player.get_rid()]);query.collide_with_areas=true
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():
  var collider=hit.collider.get_meta("creature",hit.collider)
  if collider.is_in_group("prototype_enemies") and collider.health>0:collider.take_damage(game.progression.combat_damage(damage))
  game.combat_effects.flash(hit.position);queue_free();return
 global_position=end;distance_left-=span
 if distance_left<=0:queue_free()
