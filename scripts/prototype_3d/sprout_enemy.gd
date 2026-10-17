extends CharacterBody3D
## Temporary enemy3 behaviour: a grounded ten-metre shuttle, using its own rig.
const Visual=preload("res://scripts/prototype_3d/sprout_model.gd")
const HEIGHT:=.9
const SOURCE_HEIGHT:=1.9013426
const MODEL_SCALE:=HEIGHT/SOURCE_HEIGHT
const SPEED:=Visual.SPEED*MODEL_SCALE
var game
var model:Node3D
var animation:AnimationPlayer
var patrol=preload("res://scripts/prototype_3d/sprout_patrol.gd").new()
var phase:=0.0
func configure(owner_game,direction:Vector3=Vector3(0,0,1)) -> void:
 game=owner_game;add_to_group("prototype_sprouts")
 collision_layer=8;collision_mask=43;floor_snap_length=.15
 model=preload("res://scenes/prototype_3d/enemy3.tscn").instantiate();add_child(model);model.scale=Vector3.ONE*MODEL_SCALE
 animation=model.get_node("AnimationPlayer");animation.play("walk");animation.pause()
 var collision:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.19;capsule.height=HEIGHT
 collision.shape=capsule;collision.position.y=HEIGHT*.5;add_child(collision)
 patrol.configure(global_position,direction);model.rotation.y=patrol.heading
 show_pose(false)
func show_pose(still:bool) -> void:
 var clip:StringName=&"RESET" if still else &"walk"
 if animation.current_animation!=clip:animation.play(clip);animation.pause()
 animation.seek(0.0 if still else phase*Visual.CYCLE_SECONDS,true)
func _physics_process(delta:float) -> void:
 if game==null or game.paused:return
 var turning:bool=patrol.turning
 var direction:=Vector3.ZERO
 if turning:patrol.turn(delta)
 elif patrol.remaining(global_position)<.0001:patrol.begin_turn();turning=true
 else:direction=patrol.direction(global_position)
 model.rotation.y=patrol.heading
 var speed:=minf(SPEED,patrol.remaining(global_position)/maxf(delta,.00001)) if not turning else 0.0
 velocity.x=direction.x*speed;velocity.z=direction.z*speed
 velocity.y=-.1 if is_on_floor() else maxf(-20,velocity.y-20*delta)
 var previous:=global_position;move_and_slide()
 var travelled:=Vector2(global_position.x-previous.x,global_position.z-previous.z).length()
 phase=fposmod(phase+travelled/(SPEED*Visual.CYCLE_SECONDS),1)
 show_pose(turning or travelled<.000001)
func snapshot() -> Dictionary:
 return {"position":[position.x,position.y,position.z],"phase":phase,"patrol":patrol.snapshot()}
func restore(data:Dictionary) -> void:
 position=Vector3(data.position[0],data.position[1],data.position[2]);phase=data.phase;patrol.restore(data.patrol)
 model.rotation.y=patrol.heading;show_pose(patrol.turning)
