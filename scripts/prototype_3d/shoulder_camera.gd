extends Node3D
## Deadlock-style right shoulder orbit. A sphere cast prevents camera clipping.
const Gait=preload("res://scripts/animation/characters/gait_parameters.gd")
const DISTANCE := 3.6
const SHOULDER := 0.30
const FOLLOW_HEIGHT := 1.45
const SENSITIVITY := 0.0025
const PITCH_LIMIT := PI*0.5
const FREE_LOOK_LIMIT := PI*0.5
const FREE_LOOK_RETURN_SPEED := PI*0.25
const BOOM_OFFSET := Vector3(SHOULDER,0.12,DISTANCE)
var boom_shape:=SphereShape3D.new()
var boom_query:=PhysicsShapeQueryParameters3D.new()
var pitch := -0.12
var yaw := 0.0
var camera := Camera3D.new()
# A projection-only camera preserves steering and action rays while looking aside.
# It never becomes current and does not add a rendered viewport.
var aim_camera := Camera3D.new()
var free_look_held := false
var free_look_offset := 0.0
var player: CharacterBody3D
var game
var actual_distance := DISTANCE
func configure(owner_game, target: CharacterBody3D) -> void:
 game = owner_game; player = target
 boom_shape.radius=0.18;boom_query.shape=boom_shape;boom_query.exclude=[player.get_rid()];boom_query.collision_mask=5
 camera.fov = 75; camera.near = 0.08; add_child(camera); camera.current = true
 aim_camera.fov=camera.fov;aim_camera.near=camera.near;add_child(aim_camera);aim_camera.current=false
 get_window().focus_exited.connect(func():free_look_held=false)
func set_world_radius(radius:float) -> void:
 # A single frustum bounds every world visual, including grass, particles and
 # later-created objects. Portrait viewports keep their own camera settings.
 var distance:=preload("res://scripts/prototype_3d/stream_layout.gd").render_distance(radius,BOOM_OFFSET.length()+FOLLOW_HEIGHT)
 camera.far=distance;aim_camera.far=distance
func head_yaw() -> float:
 # Native bind axes differ from the character frame; remove the head's rest
 # orientation before reading its actual animated forward direction.
 var native=player.model.native
 var forward:Vector3=player.model.global_basis*(native.posed[native.head].basis*native.inverse_rest[native.head].basis*Vector3.BACK)
 if Vector2(forward.x,forward.z).length_squared()<0.000001:return yaw
 return atan2(-forward.x,-forward.z)
func sync_free_look_input() -> void:
 free_look_held=not game.paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and Input.is_physical_key_pressed(KEY_ALT)
func constrain_free_look() -> void:
 var centre:=wrapf(head_yaw()-yaw,-PI,PI)
 free_look_offset=clampf(free_look_offset,centre-FREE_LOOK_LIMIT,centre+FREE_LOOK_LIMIT)
func reset_free_look() -> void:
 free_look_held=false;free_look_offset=0
func is_free_looking() -> bool:
 return free_look_held or not is_zero_approx(free_look_offset)
func look(relative: Vector2) -> void:
 sync_free_look_input()
 if free_look_held:
  free_look_offset-=relative.x*SENSITIVITY;constrain_free_look();return
 yaw=wrapf(yaw-relative.x*SENSITIVITY,-PI,PI)
 pitch=clampf(pitch-relative.y*SENSITIVITY,-PITCH_LIMIT,PITCH_LIMIT)
func movement_direction(input: Vector2,diagonal_angle:float=Gait.DIAGONAL_ANGLE) -> Vector3:
 var basis := Basis(Vector3.UP,yaw)
 var travel:=Vector3(input.x,0,input.y)
 if absf(input.x)>.00001 and absf(input.y)>.00001:travel.x*=tan(diagonal_angle)
 return (basis*travel).normalized()
func facing() -> Vector3:
 return -Basis(Vector3.UP,yaw).z
func update(delta: float) -> void:
 if player == null: return
 sync_free_look_input()
 if free_look_held:constrain_free_look()
 else:free_look_offset=move_toward(free_look_offset,0,FREE_LOOK_RETURN_SPEED*maxf(delta,0))
 global_position = player.global_position+Vector3.UP*FOLLOW_HEIGHT
 var aim_basis:=Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
 basis = Basis(Vector3.UP,yaw+free_look_offset)*Basis(Vector3.RIGHT,pitch)
 boom_query.transform=Transform3D(Basis.IDENTITY,global_position)
 boom_query.motion=global_basis*BOOM_OFFSET
 var fractions:=get_world_3d().direct_space_state.cast_motion(boom_query)
 var safe:=clampf(DISTANCE*fractions[0],0,DISTANCE)
 # Recover toward the current safe distance, never toward full extension while
 # a floor/wall is still blocking the boom. Equal distances must remain equal.
 if safe<actual_distance:actual_distance=safe
 else:actual_distance=lerpf(actual_distance,safe,1-exp(-maxf(0,delta)*10))
 camera.position=BOOM_OFFSET*(actual_distance/DISTANCE)
 camera.rotation = Vector3.ZERO
 if is_zero_approx(free_look_offset):aim_camera.global_transform=camera.global_transform
 else:
  # The original aim boom also respects walls when it differs from the view.
  # Only free look needs this extra sphere cast.
  boom_query.motion=aim_basis*BOOM_OFFSET
  var aim_fractions:=get_world_3d().direct_space_state.cast_motion(boom_query)
  aim_camera.global_transform=Transform3D(aim_basis,global_position+aim_basis*BOOM_OFFSET*aim_fractions[0])
func projection_camera() -> Camera3D:
 # Outside free look, use the live render camera, including external camera
 # adjustments and shoulder offsets. Only a diverted view needs a separate ray.
 return aim_camera if not is_zero_approx(free_look_offset) else camera
func target(max_distance: float = 100.0) -> Dictionary:
 var view:=projection_camera()
 var center := get_viewport().get_visible_rect().size/2
 var from := view.project_ray_origin(center)
 var direction := view.project_ray_normal(center)
 var query := PhysicsRayQueryParameters3D.create(from,from+direction*max_distance,25,[player.get_rid()])
 query.collide_with_areas=true
 return get_world_3d().direct_space_state.intersect_ray(query)
# Radius is in viewport-height units, so assistance has the same apparent size
# at every resolution/aspect ratio. The bow retains the exact center ray.
const ACTION_RADIUS := 0.018
func action_sample(interaction:bool=false) -> Dictionary:
 var view:=projection_camera()
 var exact:=aim_sample()
 var best:Dictionary={}
 var best_score:=INF
 var center:=get_viewport().get_visible_rect().size*0.5
 var radius:=get_viewport().get_visible_rect().size.y*ACTION_RADIUS
 for ring in 3:
  var count:=1 if ring==0 else 12
  for sector in count:
   var offset:=Vector2.ZERO if ring==0 else Vector2.from_angle(sector*TAU/count)*radius*ring/2.0
   var pixel:=center+offset
   var from:=view.project_ray_origin(pixel)
   var ray:=PhysicsRayQueryParameters3D.create(from,from+view.project_ray_normal(pixel)*100.0,25,[player.get_rid()])
   ray.collide_with_areas=true
   var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
   if hit.is_empty():continue
   var owner_node=game.target_owner(hit.collider)
   if not action_candidate(owner_node,interaction):continue
   if player.global_position.distance_to(hit.position)>1.75:continue
   # Each candidate is a first visible surface, never a shape overlap through
   # a wall. Prefer the center, then the smallest screen-space correction.
   var score:=offset.length_squared()+from.distance_to(hit.position)*0.0001
   if score<best_score:best_score=score;best=hit
  if ring==0 and not best.is_empty():break
 if best.is_empty():return exact
 return {"hit":best,"point":best.position}
func action_candidate(node,interaction:bool) -> bool:
 if not is_instance_valid(node):return false
 if interaction:
  return node.is_in_group("prototype_drops") or node.is_in_group("prototype_workbenches") or node.is_in_group("prototype_water") or (node.is_in_group("prototype_enemies") and node.health<=0) or (node.is_in_group("prototype_burdock") and node.health>0) or (node.is_in_group("prototype_rocks") and node.hand_collectable and node.health>0)
 return (node.is_in_group("prototype_enemies") or node.is_in_group("prototype_trees") or node.is_in_group("prototype_rocks") or node.is_in_group("prototype_saplings")) and node.health>0
func aim_sample() -> Dictionary:
 var view:=projection_camera()
 # One camera ray supplies both the visible contact and the object to hit.
 # Do not raycast twice at click time or use a parallel ray from the player.
 var result:=target()
 var center:=get_viewport().get_visible_rect().size/2
 var point:Vector3=result.position if not result.is_empty() else view.project_ray_origin(center)+view.project_ray_normal(center)*100.0
 return {"hit":result,"point":point}
func aim_point() -> Vector3:return aim_sample().point
