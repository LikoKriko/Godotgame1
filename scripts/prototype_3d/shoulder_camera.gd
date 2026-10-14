extends Node3D
## Deadlock-style right shoulder orbit. A sphere cast prevents camera clipping.
const DISTANCE := 3.6
const SHOULDER := 0.60
const SENSITIVITY := 0.0025
var pitch := -0.12
var yaw := 0.0
var camera := Camera3D.new()
var player: CharacterBody3D
var game
var actual_distance := DISTANCE
func configure(owner_game, target: CharacterBody3D) -> void:
 game = owner_game; player = target
 camera.fov = 75; camera.near = 0.08; add_child(camera); camera.current = true
func look(relative: Vector2) -> void:
 yaw -= relative.x*SENSITIVITY
 pitch = clampf(pitch-relative.y*SENSITIVITY,deg_to_rad(-60),deg_to_rad(65))
func movement_direction(input: Vector2) -> Vector3:
 var basis := Basis(Vector3.UP,yaw)
 return (basis*Vector3(input.x,0,input.y)).normalized()
func facing() -> Vector3:
 return -Basis(Vector3.UP,yaw).z
func update(delta: float) -> void:
 if player == null: return
 global_position = player.global_position+Vector3(0,1.45,0)
 basis = Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
 var desired := global_transform*Vector3(SHOULDER,0.12,DISTANCE)
 var cast := PhysicsShapeQueryParameters3D.new(); var sphere := SphereShape3D.new(); sphere.radius = 0.18
 cast.shape = sphere; cast.transform = Transform3D(Basis.IDENTITY,global_position)
 cast.motion = desired-global_position; cast.exclude = [player.get_rid()]; cast.collision_mask = 5
 var fractions := get_world_3d().direct_space_state.cast_motion(cast)
 var safe := DISTANCE*fractions[0]
 if safe < actual_distance: actual_distance = maxf(0.2,safe)
 else: actual_distance = lerpf(actual_distance,DISTANCE,1-exp(-delta*10))
 camera.position = Vector3(SHOULDER,0.12,DISTANCE)*(actual_distance/DISTANCE)
 camera.rotation = Vector3.ZERO
func target(max_distance: float = 30.0) -> Dictionary:
 var center := get_viewport().get_visible_rect().size/2
 var from := camera.project_ray_origin(center)
 var direction := camera.project_ray_normal(center)
 var query := PhysicsRayQueryParameters3D.create(from,from+direction*max_distance,1,[player.get_rid()])
 return get_world_3d().direct_space_state.intersect_ray(query)
