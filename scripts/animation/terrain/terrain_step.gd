extends RefCounted
## Capsule assistance for static ledges; never cross a wall or low ceiling.
static func rise(body:CharacterBody3D,motion:Vector3,maximum:float=.26) -> float:
 if not body.is_on_floor() or motion.length_squared()<.000001:return 0.0
 var wall:=KinematicCollision3D.new()
 if not body.test_move(body.global_transform,motion,wall):return 0.0
 if wall.get_normal().y>=cos(body.floor_max_angle):return 0.0
 var ahead:Vector3=body.global_position+motion.normalized()*.3
 var query:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*(maximum+.02),ahead+Vector3.DOWN*.02,1,[body.get_rid()])
 var hit:=body.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty() or hit.normal.y<cos(body.floor_max_angle):return 0.0
 var lift:float=hit.position.y-body.global_position.y+.002
 if lift<=.005 or lift>maximum:return 0.0
 if body.test_move(body.global_transform,Vector3.UP*lift):return 0.0
 var raised:=body.global_transform;raised.origin.y+=lift
 if body.test_move(raised,motion):return 0.0
 return lift
