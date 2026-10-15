extends Node3D
## Deadlock-style right shoulder orbit. A sphere cast prevents camera clipping.
const DISTANCE := 3.6
const SHOULDER := 0.30
const SENSITIVITY := 0.0025
const PITCH_LIMIT := PI*0.5
const BOOM_OFFSET := Vector3(SHOULDER,0.12,DISTANCE)
var boom_shape:=SphereShape3D.new()
var boom_query:=PhysicsShapeQueryParameters3D.new()
var pitch := -0.12
var yaw := 0.0
var camera := Camera3D.new()
var player: CharacterBody3D
var game
var actual_distance := DISTANCE
func configure(owner_game, target: CharacterBody3D) -> void:
 game = owner_game; player = target
 boom_shape.radius=0.18;boom_query.shape=boom_shape;boom_query.exclude=[player.get_rid()];boom_query.collision_mask=5
 camera.fov = 75; camera.near = 0.08; add_child(camera); camera.current = true
func look(relative: Vector2) -> void:
 yaw=wrapf(yaw-relative.x*SENSITIVITY,-PI,PI)
 pitch=clampf(pitch-relative.y*SENSITIVITY,-PITCH_LIMIT,PITCH_LIMIT)
func movement_direction(input: Vector2) -> Vector3:
 var basis := Basis(Vector3.UP,yaw)
 return (basis*Vector3(input.x,0,input.y)).normalized()
func facing() -> Vector3:
 return -Basis(Vector3.UP,yaw).z
func update(delta: float) -> void:
 if player == null: return
 global_position = player.global_position+Vector3(0,1.45,0)
 basis = Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
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
func target(max_distance: float = 100.0) -> Dictionary:
 var center := get_viewport().get_visible_rect().size/2
 var from := camera.project_ray_origin(center)
 var direction := camera.project_ray_normal(center)
 var query := PhysicsRayQueryParameters3D.create(from,from+direction*max_distance,25,[player.get_rid()])
 query.collide_with_areas=true
 return get_world_3d().direct_space_state.intersect_ray(query)
func aim_sample() -> Dictionary:
 # One camera ray supplies both the visible contact and the object to hit.
 # Do not raycast twice at click time or use a parallel ray from the player.
 var result:=target()
 var center:=get_viewport().get_visible_rect().size/2
 var point:Vector3=result.position if not result.is_empty() else camera.project_ray_origin(center)+camera.project_ray_normal(center)*100.0
 return {"hit":result,"point":point}
func aim_point() -> Vector3:return aim_sample().point
